import PhotosUI
import SwiftUI
import UIKit
import ImageIO

@MainActor
final class LockerCustomizationCoordinator: ObservableObject {
    enum Tool: String, CaseIterable, Identifiable { case draw, background; var id: String { rawValue } }
    @Published var isEditing = false
    @Published var selectedTool: Tool = .draw
    @Published var erasing = false
    @Published var penColor = LockerDailyAccent.skyBlue.uiColor
    @Published var penWidth: CGFloat = 3

    func begin(tool: Tool) {
        selectedTool = tool; isEditing = true
        #if DEBUG
        print("[LockerEdit][OPEN] tool=\(tool.rawValue)")
        #endif
    }
    func finish() {
        isEditing = false; erasing = false
        #if DEBUG
        print("[LockerEdit][SAVE]")
        #endif
    }
    func undo() { NotificationCenter.default.post(name: Notification.Name("LockU.LockerBodyDrawing.Undo"), object: nil) }
    func redo() { NotificationCenter.default.post(name: Notification.Name("LockU.LockerBodyDrawing.Redo"), object: nil) }
}

struct LockerHomeView: View {
    @EnvironmentObject private var settingsRepository: LockerSettingsRepository
    @EnvironmentObject private var appModel: LockUAppModel
    @EnvironmentObject private var memoryRepository: MemoryRepository
    @EnvironmentObject private var revisitCoordinator: RevisitCoordinator
    @EnvironmentObject private var demoClock: LockUDemoClock
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onShare: () -> Void
    let onCode: () -> Void
    let onSettings: () -> Void
    @State private var appeared = false
    @StateObject private var lockerResurfacingCoordinator = LockerResurfacingCoordinator()
    @StateObject private var canvasEditingCoordinator = LockerCanvasEditingCoordinator()
    @StateObject private var customizationCoordinator = LockerCustomizationCoordinator()

    var body: some View {
        GeometryReader { proxy in
            let isOpen = appModel.lockerDoorState.isOpenOrOpening
            let maxHeight: CGFloat = isOpen ? 680 : 664
            let previousLockerHeight = min(maxHeight, proxy.size.height - 60)
            let lockerWidth = min(
                proxy.size.width * 0.93,
                previousLockerHeight / LockUSceneTokens.Home.lockerAspectRatio
            )
            let heightReduction = min(64, max(52, proxy.size.height * 0.07))
            let lockerHeight = max(360, previousLockerHeight - heightReduction)
            let editZoneHeight = min(60, max(54, heightReduction))

            VStack(spacing: LockUSceneTokens.Home.headerToLocker) {
                LockerUtilityBar(
                    date: demoClock.now,
                    onShare: onShare,
                    onCode: onCode,
                    onSettings: onSettings
                )
                .padding(.horizontal, LockUSceneTokens.Home.headerHorizontalMargin)
                .zIndex(LockUSceneTokens.Layer.interface)

                VStack(spacing: 0) {
                    ZStack {
                        LockerFrameView(
                            lockerColor: Color(lockUHex: settingsRepository.settings.lockerColorHex),
                            customizationCoordinator: customizationCoordinator
                        )
                        .environmentObject(lockerResurfacingCoordinator)
                        .environmentObject(canvasEditingCoordinator)
                        .opacity(appModel.lockerDoorState.isOpenOrOpening || customizationCoordinator.isEditing ? 1 : 0.12)
                        .blur(radius: appModel.lockerDoorState == .closed && !customizationCoordinator.isEditing ? 1.5 : 0)
                        .animation(
                            reduceMotion
                                ? LockUDesign.Motion.soft
                                : LockUDesign.Motion.soft.delay(
                                    appModel.lockerDoorState == .opening ? 0.2 : 0
                                ),
                            value: appModel.lockerDoorState
                        )

                        LockerDoorView(customizationCoordinator: customizationCoordinator)
                            .environmentObject(canvasEditingCoordinator)
                            .allowsHitTesting(
                                customizationCoordinator.isEditing
                                    ? false
                                    : !canvasEditingCoordinator.isEditing
                            )
                            .zIndex(10)
                    }
                    .frame(width: lockerWidth, height: lockerHeight)
                    .animation(.easeOut(duration: 0.22), value: isOpen)
                    .zIndex(LockUSceneTokens.Layer.physical)

                    if !customizationCoordinator.isEditing {
                        Button {
                            appModel.lockerDoorState = .open
                            customizationCoordinator.begin(tool: .draw)
                        } label: {
                            Label("編集", systemImage: "pencil")
                                .font(.system(size: 15, weight: .medium))
                                .frame(minWidth: 96, minHeight: 48)
                                .background(.thinMaterial, in: Capsule())
                                .background(.white.opacity(0.78), in: Capsule())
                        }
                        .foregroundStyle(LockUDesign.Color.schoolNavy)
                        .padding(.top, 10)
                        .frame(width: lockerWidth, height: editZoneHeight, alignment: .topTrailing)
                        .zIndex(LockUSceneTokens.Layer.interface)
                        .accessibilityLabel("ロッカーそのものを編集")
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .opacity(appeared ? 1 : 0.65)
            .offset(y: appeared ? 0 : 8)
            .onAppear {
                if !appeared { appModel.markLockerFirstRender() }
                guard !appeared else { return }
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(.easeOut(duration: 0.45)) { appeared = true }
                }
                Task { @MainActor in
                    await Task.yield()
                    appModel.refreshTimeDependentState()
                    refreshLockerResurfacing()
                }
            }
            .onChange(of: memoryRepository.memories.count) { _, _ in refreshLockerResurfacing() }
            .onChange(of: demoClock.preset) { _, _ in refreshLockerResurfacing() }
            .animation(.easeOut(duration: 0.23), value: lockerResurfacingCoordinator.candidateMemoryID)
            .sheet(isPresented: Binding(
                get: { customizationCoordinator.isEditing },
                set: { if !$0 { customizationCoordinator.finish() } }
            )) {
                LockerCustomizationPanel(coordinator: customizationCoordinator)
                    .presentationDetents([.height(246)])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
                    .presentationBackgroundInteraction(.enabled(upThrough: .height(246)))
            }
        }
    }

    private func refreshLockerResurfacing() {
        let growth = LockerGrowthGenerator().state(memories: memoryRepository.memories)
        lockerResurfacingCoordinator.refresh(
            date: demoClock.now,
            memories: memoryRepository.memories,
            growthStage: growth.stage
        )
    }
}

private struct LockerCustomizationPanel: View {
    @EnvironmentObject private var settingsRepository: LockerSettingsRepository
    @EnvironmentObject private var backgroundRepository: BackgroundRepository
    @EnvironmentObject private var appModel: LockUAppModel
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var coordinator: LockerCustomizationCoordinator
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isImportingBackground = false
    @State private var message: String?
    @State private var penPalette = LockerDailyPenPaletteProvider.palette(for: .now)
    @State private var backgroundTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("EDIT LOCKER")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.7)
                Spacer()
                Button("完了") { coordinator.finish() }
                    .font(.system(size: 14, weight: .semibold))
            }

            Picker("編集ツール", selection: Binding(
                get: { coordinator.selectedTool },
                set: { selectTool($0) }
            )) {
                Label("Draw", systemImage: "pencil.tip").tag(LockerCustomizationCoordinator.Tool.draw)
                Label("Background", systemImage: "rectangle.fill").tag(LockerCustomizationCoordinator.Tool.background)
            }
            .pickerStyle(.segmented)

            switch coordinator.selectedTool {
            case .draw: drawingControls
            case .background: backgroundControls
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .foregroundStyle(LockUDesign.Color.schoolNavy)
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            backgroundTask?.cancel()
            backgroundTask = Task { await importBackground(from: item) }
        }
        .onAppear {
            refreshPenPalette()
            if settingsRepository.settings.backgroundMode == .photo, backgroundRepository.image == nil {
                saveBackgroundMode(.today)
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refreshPenPalette() } }
        .onDisappear {
            backgroundTask?.cancel()
            backgroundTask = nil
        }
    }

    private var drawingControls: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                toolButton("pencil.tip", selected: !coordinator.erasing) { coordinator.erasing = false }
                toolButton("eraser", selected: coordinator.erasing) { coordinator.erasing = true }
                toolButton("arrow.uturn.backward", selected: false) { coordinator.undo() }
                toolButton("arrow.uturn.forward", selected: false) { coordinator.redo() }
                ForEach(penPalette) { pen in
                    let selected = coordinator.penColor.isEqual(pen.uiColor)
                    Button {
                        coordinator.penColor = pen.uiColor
                        coordinator.erasing = false
                    } label: {
                        Circle().fill(pen.color).frame(width: 27, height: 27).padding(4)
                            .overlay(Circle().stroke(selected ? pen.color : .clear, lineWidth: 2.5))
                    }
                    .frame(width: 44, height: 44)
                    .accessibilityLabel(pen.name)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
                ForEach([(1.5, 4.0), (3.0, 7.0), (6.0, 11.0)], id: \.0) { width, dot in
                    let selected = coordinator.penWidth == width
                    Button { coordinator.penWidth = width; coordinator.erasing = false } label: {
                        Circle().fill(LockUDesign.Color.schoolNavy)
                            .frame(width: dot, height: dot)
                            .frame(width: 30, height: 30)
                            .overlay(Circle().stroke(selected ? LockUDesign.Color.ramuneBlue : .clear, lineWidth: 2))
                    }
                    .frame(width: 44, height: 44)
                }
            }
        }
    }

    private var backgroundControls: some View {
        let photoSelected = settingsRepository.settings.backgroundMode == .photo
        return HStack(spacing: 12) {
            modeButton("今日の色", icon: "sparkles", mode: .today) { saveBackgroundMode(.today) }
            if backgroundRepository.image == nil {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    modeLabel("写真", icon: "photo", selected: photoSelected)
                }
                .disabled(isImportingBackground)
            } else {
                modeButton("写真", icon: "photo", mode: .photo) { saveBackgroundMode(.photo) }
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Text("写真を変更").font(.system(size: 12, weight: .medium)).frame(minHeight: 44)
                }
                .disabled(isImportingBackground)
            }
            if isImportingBackground { ProgressView() }
        }
    }

    private func modeButton(_ title: String, icon: String, mode: LockerSettings.BackgroundMode, action: @escaping () -> Void) -> some View {
        Button(action: action) { modeLabel(title, icon: icon, selected: settingsRepository.settings.backgroundMode == mode) }
    }

    private func modeLabel(_ title: String, icon: String, selected: Bool) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 13, weight: .semibold))
            .frame(minWidth: 92, minHeight: 44)
            .background(selected ? LockUDesign.Color.ramuneBlue.opacity(0.20) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? LockUDesign.Color.ramuneBlue.opacity(0.65) : .secondary.opacity(0.18), lineWidth: 1))
            .scaleEffect(selected ? 1.02 : 1)
    }

    private func toolButton(_ icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .frame(width: 42, height: 42)
                .background(LockUDesign.Color.ramuneBlue.opacity(selected ? 0.2 : 0), in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(LockUDesign.Color.ramuneBlue.opacity(selected ? 0.5 : 0), lineWidth: 1))
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func saveBackgroundMode(_ mode: LockerSettings.BackgroundMode) {
        var next = settingsRepository.settings
        next.backgroundMode = mode
        do { try settingsRepository.update(next) }
        catch { appModel.report(error) }
    }

    private func importBackground(from item: PhotosPickerItem) async {
        guard !isImportingBackground else { return }
        isImportingBackground = true; message = nil
        defer { isImportingBackground = false; selectedPhoto = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw LockUStorageError.invalidImage }
            let preparedData = await Task.detached(priority: .userInitiated) {
                LockerBackgroundImagePreparation.downsample(data, maximumPixelSize: 2_048)
            }.value
            try Task.checkCancellation()
            guard let preparedData, let image = UIImage(data: preparedData) else { throw LockUStorageError.invalidImage }
            try backgroundRepository.save(image)
            saveBackgroundMode(.photo)
        } catch is CancellationError {
        } catch {
            message = "写真を読み込めませんでした"
            appModel.report(error)
        }
    }

    private func refreshPenPalette(date: Date = .now) {
        let next = LockerDailyPenPaletteProvider.palette(for: date)
        let changed = next.map(\.id) != penPalette.map(\.id)
        if changed { penPalette = next }
        if changed || !next.contains(where: { coordinator.penColor.isEqual($0.uiColor) }) {
            coordinator.penColor = next.first?.uiColor ?? coordinator.penColor
            coordinator.erasing = false
        }
    }

    private func selectTool(_ tool: LockerCustomizationCoordinator.Tool) {
        coordinator.selectedTool = tool
        coordinator.erasing = false
        appModel.lockerDoorState = .open
        #if DEBUG
        print("[LockerEdit][TOOL] \(tool.rawValue)")
        #endif
    }
}

nonisolated enum LockerBackgroundImagePreparation {
    static func downsample(_ data: Data, maximumPixelSize: Int) -> Data? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return nil }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else { return nil }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.94)
    }
}

private struct LockerCanvasExternalControls: View {
    @EnvironmentObject private var appModel: LockUAppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var coordinator: LockerCanvasEditingCoordinator
    @State private var dailyAccent = LockerDailyAccentProvider.accent(for: Date())

    var body: some View {
        ViewThatFits(in: .horizontal) {
            controls(compact: false)
            controls(compact: true)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityElement(children: .contain)
        .animation(.easeOut(duration: 0.2), value: coordinator.isEditing)
        .animation(.easeOut(duration: 0.18), value: coordinator.isDrawing)
        .disabled(coordinator.isEditing && appModel.lockerDoorState != .open)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, !coordinator.isDrawing else { return }
            dailyAccent = LockerDailyAccentProvider.accent(for: Date())
        }
    }

    private func controls(compact: Bool) -> some View {
        HStack(spacing: compact ? 7 : 10) {
            if coordinator.isEditing {
                if !compact { dailyAccentLabel(compact: false) }
                if coordinator.isDrawing {
                    drawingTools
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    HStack(spacing: compact ? 4 : 14) {
                        switch coordinator.selection {
                        case .none:
                            toolButton("pencil.tip", compact ? nil : "描く", isSelected: coordinator.activeTool == .drawing) { coordinator.toggleDrawing() }
                                .accessibilityLabel("ロッカーに描く")
                            toolButton("textformat", compact ? nil : "文字", isSelected: coordinator.activeTool == .text) { coordinator.requestText() }
                                .accessibilityLabel("文字を追加")
                            toolButton("plus.circle", compact ? nil : "思い出", isSelected: coordinator.activeTool == .memory) { coordinator.requestMemory() }
                                .accessibilityLabel("過去の思い出を追加")
                        case .text:
                            toolButton("character.cursor.ibeam", compact ? nil : "内容") { coordinator.requestTextContentEdit() }
                                .accessibilityLabel("文字の内容を編集")
                            fontMenu
                            colorMenu
                            toolButton("plus.square.on.square", nil) { coordinator.duplicateSelection() }
                                .accessibilityLabel("文字を複製")
                            toolButton("trash", nil) { coordinator.removeSelection() }
                                .accessibilityLabel(removalAccessibilityLabel)
                        case .drawing:
                            toolButton("plus.square.on.square", compact ? nil : "複製") { coordinator.duplicateSelection() }
                                .accessibilityLabel("落書きを複製")
                            toolButton("trash", compact ? nil : "削除") { coordinator.removeSelection() }
                                .accessibilityLabel(removalAccessibilityLabel)
                        case .memory:
                            toolButton("square.3.layers.3d.top.filled", nil) { coordinator.bringSelectionToFront() }
                                .accessibilityLabel("前面へ移動")
                            toolButton("xmark", nil) { coordinator.removeSelection() }
                                .accessibilityLabel(removalAccessibilityLabel)
                        }
                        toolButton("arrow.uturn.backward", nil) { coordinator.undoEdit() }
                            .accessibilityLabel("直前の編集を元に戻す")
                    }
                    .padding(.horizontal, compact ? 4 : 14)
                    .frame(height: 48)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Button { coordinator.finish() } label: {
                    Label("完了", systemImage: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(minWidth: 96, minHeight: 48)
                }
                    .foregroundStyle(LockUDesign.Color.schoolNavy)
                    .background(dailyAccent.color.opacity(0.26), in: Capsule())
                    .overlay(
                        Capsule().stroke(
                            dailyAccent.color.opacity(colorSchemeContrast == .increased ? 0.82 : 0.5),
                            lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
                        )
                    )
                    .accessibilityLabel("編集を完了")
                    .buttonStyle(LockerEditorPressButtonStyle(reduceMotion: reduceMotion))
            } else {
                Button { beginEditing() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil").font(.system(size: 17, weight: .medium))
                        if !compact { Text("編集") }
                    }
                    .font(.system(size: 15, weight: .medium))
                    .padding(.horizontal, 20)
                    .frame(minWidth: 96, minHeight: 48)
                    .background(.thinMaterial, in: Capsule())
                    .background(.white.opacity(0.78), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.5), lineWidth: 1))
                    .shadow(color: .black.opacity(0.09), radius: 8, y: 3)
                }
                .accessibilityLabel("ロッカーを編集")
                .buttonStyle(LockerEditorPressButtonStyle(reduceMotion: reduceMotion))
            }
        }
        .foregroundStyle(LockUDesign.Color.schoolNavy.opacity(0.76))
    }

    private func beginEditing() {
        let date = Date()
        dailyAccent = LockerDailyAccentProvider.accent(for: date)
        coordinator.begin(dailyAccent: dailyAccent, date: date)
        guard appModel.lockerDoorState != .open else { return }
        appModel.lockerDoorState = .opening
        Task { @MainActor in
            let delay: UInt64 = reduceMotion ? 180_000_000 : 520_000_000
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled, coordinator.isEditing else { return }
            appModel.lockerDoorState = .open
        }
    }

    private var fontMenu: some View {
        Menu {
            ForEach(LockerTextFontStyle.allCases) { style in
                Button { coordinator.changeFont(to: style) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(style.title)
                        Text(coordinator.selectedTextPreview)
                            .font(LockerTextFontResolver.font(for: style, size: 16))
                        if coordinator.selectedFontStyle == style { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            Image(systemName: "textformat")
                .font(.system(size: 19, weight: .medium))
                .frame(minWidth: 44, minHeight: 48)
                .foregroundStyle(LockUDesign.Color.schoolNavy)
                .background(dailyAccent.color.opacity(0.22), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(dailyAccent.color.opacity(0.45), lineWidth: 1))
        }
        .accessibilityLabel("フォントを変更")
        .accessibilityAddTraits(.isSelected)
    }

    private var colorMenu: some View {
        Menu {
            ForEach(LockerTextColorStyle.allCases) { style in
                Button { coordinator.changeColor(to: style) } label: {
                    HStack {
                        Circle().fill(style.previewColor).frame(width: 13, height: 13)
                        Text(style.title)
                        if coordinator.selectedColorStyle == style { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            Image(systemName: "paintpalette")
                .font(.system(size: 19, weight: .medium))
                .frame(minWidth: 44, minHeight: 48)
        }
        .accessibilityLabel("色を変更")
    }

    private var drawingTools: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                drawingModeButton(icon: "checkmark", title: "落書きを確定", isSelected: false) {
                    coordinator.toggleDrawing()
                }
                drawingModeButton(icon: "pencil.tip", title: "ペン", isSelected: !coordinator.erasing) {
                    coordinator.erasing = false
                }
                drawingModeButton(icon: "eraser", title: "消しゴム", isSelected: coordinator.erasing) {
                    coordinator.erasing = true
                }
                drawingModeButton(icon: "arrow.uturn.backward", title: "元に戻す", isSelected: false) {
                    coordinator.undoDrawing()
                }
                ForEach(LockerDailyAccent.allCases) { accent in
                    let selected = coordinator.penColor.isEqual(accent.uiColor)
                    LockerEditorColorSwatch(
                        accent: accent,
                        isSelected: selected,
                        increasedContrast: colorSchemeContrast == .increased,
                        reduceMotion: reduceMotion
                    ) {
                        coordinator.penColor = accent.uiColor
                        coordinator.erasing = false
                    }
                }
                ForEach(penWidths.indices, id: \.self) { index in
                    let option = penWidths[index]
                    let selected = coordinator.penWidth == option.width
                    Button {
                        coordinator.penWidth = option.width
                        coordinator.erasing = false
                    } label: {
                        Circle()
                            .fill(LockUDesign.Color.schoolNavy)
                            .frame(width: option.dotSize, height: option.dotSize)
                            .frame(width: 30, height: 30)
                            .background(dailyAccent.color.opacity(selected ? 0.16 : 0), in: Circle())
                            .overlay(
                                Circle().stroke(
                                    selected ? dailyAccent.color : .clear,
                                    lineWidth: colorSchemeContrast == .increased ? 2.5 : 2
                                )
                            )
                    }
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("ペンの太さ、\(option.name)")
                    .accessibilityValue(selected ? "選択中" : "")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .buttonStyle(LockerEditorPressButtonStyle(reduceMotion: reduceMotion))
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 48)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func dailyAccentLabel(compact: Bool) -> some View {
        HStack(spacing: 5) {
            Circle().fill(dailyAccent.color).frame(width: 9, height: 9)
            if !compact {
                Text("今日のカラー")
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, compact ? 7 : 9)
        .frame(height: 28)
        .background(dailyAccent.color.opacity(0.14), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今日のカラー、\(dailyAccent.displayName)")
    }

    private func drawingModeButton(
        icon: String,
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        LockerEditorToolButton(
            icon: icon,
            title: nil,
            accessibilityTitle: title,
            isSelected: isSelected,
            accentColor: dailyAccent.color,
            increasedContrast: colorSchemeContrast == .increased,
            reduceMotion: reduceMotion,
            action: action
        )
    }

    private var removalAccessibilityLabel: String {
        switch coordinator.selection {
        case .memory: "ロッカーから外す"
        case .drawing: "落書きを削除"
        case .text: "文字を削除"
        case .none: "選択項目を削除"
        }
    }

    private var penWidths: [(name: String, width: CGFloat, dotSize: CGFloat)] {
        [("細い", 1.5, 4), ("普通", 3, 7), ("太い", 6, 11)]
    }

    private func toolButton(
        _ icon: String,
        _ title: String?,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        LockerEditorToolButton(
            icon: icon,
            title: title,
            accessibilityTitle: title,
            isSelected: isSelected,
            accentColor: dailyAccent.color,
            increasedContrast: colorSchemeContrast == .increased,
            reduceMotion: reduceMotion,
            action: action
        )
    }
}

private struct LockerEditorToolButton: View {
    let icon: String
    let title: String?
    let accessibilityTitle: String?
    let isSelected: Bool
    let accentColor: Color
    let increasedContrast: Bool
    let reduceMotion: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .medium))
                if let title {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, title == nil ? 8 : 14)
            .frame(minWidth: 44, minHeight: 48)
        }
        .buttonStyle(
            LockerEditorToolButtonStyle(
                isSelected: isSelected,
                accentColor: accentColor,
                isHovering: isHovering,
                increasedContrast: increasedContrast,
                reduceMotion: reduceMotion
            )
        )
        .onHover { isHovering = $0 }
        .accessibilityLabel(accessibilityTitle ?? title ?? "編集ツール")
        .accessibilityValue(isSelected ? "選択中" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct LockerEditorToolButtonStyle: ButtonStyle {
    let isSelected: Bool
    let accentColor: Color
    let isHovering: Bool
    let increasedContrast: Bool
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        let highlighted = configuration.isPressed || isHovering
        configuration.label
            .foregroundStyle(isSelected ? LockUDesign.Color.schoolNavy : LockUDesign.Color.schoolNavy.opacity(0.76))
            .background(
                isSelected
                    ? accentColor.opacity(0.22)
                    : accentColor.opacity(highlighted ? (configuration.isPressed ? 0.16 : 0.12) : 0),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? accentColor.opacity(increasedContrast ? 0.75 : 0.44) : .clear,
                        lineWidth: increasedContrast ? 1.5 : 1
                    )
            )
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.975 : (isHovering ? 1.02 : 1)))
            .animation(.easeOut(duration: reduceMotion ? 0 : 0.14), value: configuration.isPressed)
            .animation(.easeOut(duration: reduceMotion ? 0 : 0.16), value: isHovering)
            .animation(.easeOut(duration: 0.18), value: isSelected)
    }
}

private struct LockerEditorColorSwatch: View {
    let accent: LockerDailyAccent
    let isSelected: Bool
    let increasedContrast: Bool
    let reduceMotion: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(accent.color)
                .frame(width: 30, height: 30)
                .padding(4)
                .overlay(
                    Circle().stroke(
                        isSelected ? accent.color : .clear,
                        lineWidth: increasedContrast ? 3 : 2.5
                    )
                )
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(LockerEditorPressButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(accent.displayName)
        .accessibilityValue(isSelected ? "選択中" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct LockerEditorPressButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.975 : 1))
            .animation(.easeOut(duration: reduceMotion ? 0 : 0.14), value: configuration.isPressed)
    }
}

private extension LockerTextFontStyle {
    var title: String {
        switch self {
        case .handwritten: "手書き"
        case .casual: "やわらか"
        case .clean: "シンプル"
        case .mono: "デジカメ"
        }
    }
}

private extension LockerTextColorStyle {
    var title: String {
        switch self {
        case .charcoal: "チャコール"
        case .navy: "ネイビー"
        case .blue: "ブルー"
        case .pink: "ピンク"
        case .white: "ホワイト"
        case .yellow: "イエロー"
        }
    }

    var previewColor: Color {
        switch self {
        case .charcoal: Color(lockUHex: "#34383C")
        case .navy: Color(lockUHex: "#162636")
        case .blue: Color(lockUHex: "#3987C9")
        case .pink: Color(lockUHex: "#E985A5")
        case .white: .white
        case .yellow: Color(lockUHex: "#F2C94C")
        }
    }
}

private struct LockerResurfacedMemoryCard: View {
    @EnvironmentObject private var memoryRepository: MemoryRepository
    @State private var image: UIImage?
    let memory: MemoryRecord
    let referenceDate: Date
    let onClose: () -> Void
    let onEngaged: () -> Void
    let onViewMemory: () -> Void

    private var daysAgo: Int {
        max(1, Calendar.autoupdatingCurrent.dateComponents(
            [.day],
            from: Calendar.autoupdatingCurrent.startOfDay(for: memory.memoryDate),
            to: Calendar.autoupdatingCurrent.startOfDay(for: referenceDate)
        ).day ?? 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if memory.isDualCameraMemory {
                        DualMemoryImageSurface(
                            memory: memory,
                            purpose: .detail,
                            targetPointSize: CGSize(width: 340, height: 390)
                        )
                    } else if let image {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        Color(red: 205/255, green: 216/255, blue: 220/255)
                            .overlay(ProgressView().tint(.white.opacity(0.72)))
                    }
                }
                .aspectRatio(0.88, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipped()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.14), in: Circle())
                }
                .accessibilityLabel("閉じる")
            }

            VStack(alignment: .leading, spacing: 5) {
                if let emoji = memory.moodEmoji {
                    Text(emoji)
                        .font(.system(size: 17))
                        .opacity(0.92)
                        .shadow(color: .black.opacity(0.07), radius: 1, y: 0.5)
                        .accessibilityLabel(MemoryMoodEmoji(rawValue: emoji)?.accessibilityLabel ?? emoji)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(memory.memoryDate.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                    Spacer()
                    Text("\(daysAgo)日前")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color.black.opacity(0.42))
                }
                Button("思い出を見る", action: onViewMemory)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.54))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 3)
            }
            .foregroundStyle(Color.black.opacity(0.72))
            .padding(.horizontal, 14)
            .padding(.top, 11)
            .padding(.bottom, 14)
        }
        .background(Color(red: 246/255, green: 244/255, blue: 238/255))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .shadow(color: .black.opacity(0.13), radius: 10, y: 6)
        .task(id: memory.id) {
            image = await memoryRepository.imageAsync(
                for: memory,
                purpose: .detail,
                targetPointSize: CGSize(width: 340, height: 390)
            )
        }
        .task(id: "reflection-\(memory.id.uuidString)") {
            do {
                try await Task.sleep(for: .seconds(2.5))
                guard !Task.isCancelled else { return }
                onEngaged()
            } catch {
                // Closing the card cancels the one-shot dwell task; cancellation is expected.
            }
        }
        .onDisappear { image = nil }
        .accessibilityElement(children: .contain)
    }
}

private struct LockerUtilityBar: View {
    let date: Date
    let onShare: () -> Void
    let onCode: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("LockU")
                .font(.system(size: 21, weight: .semibold))
                .tracking(-0.2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(date.formatted(.dateTime.month(.abbreviated).day()))
                .font(.system(size: 18, weight: .medium))
                .frame(maxWidth: .infinity)
            Menu {
                Button("シェア", systemImage: "square.and.arrow.up", action: onShare)
                Button("ロッカーコード", systemImage: "number", action: onCode)
                Button("設定", systemImage: "gearshape", action: onSettings)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .foregroundStyle(LockUSceneTokens.Material.lockerInk.opacity(0.84))
            .accessibilityLabel("ロッカーメニュー")
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .foregroundStyle(LockUSceneTokens.Material.lockerInk.opacity(0.92))
        .frame(height: LockUSceneTokens.Home.headerHeight)
    }
}

struct LockerFrameView: View {
    @EnvironmentObject private var settingsRepository: LockerSettingsRepository
    let lockerColor: Color
    @ObservedObject var customizationCoordinator: LockerCustomizationCoordinator

    var body: some View {
        GeometryReader { proxy in
            let frameWidth = max(LockUSceneTokens.Home.frameThickness.lowerBound, min(LockUSceneTokens.Home.frameThickness.upperBound, proxy.size.width * 0.038))
            let topHeight: CGFloat = 16

            ZStack {
                LockerInteriorSurface(
                    lockerColor: lockerColor,
                    customizationCoordinator: customizationCoordinator
                )
                    .padding(.horizontal, frameWidth)
                    .padding(.top, topHeight)
                    .padding(.bottom, frameWidth)
                    .shadow(color: LockUSceneTokens.Shadow.structural, radius: 4, x: 1, y: 2)

                VStack(spacing: 0) {
                    topFrame(height: topHeight)
                    Spacer(minLength: 0)
                    layeredFrameBar(axis: .horizontal).frame(height: frameWidth)
                }

                HStack(spacing: 0) {
                    layeredFrameBar(axis: .vertical).frame(width: frameWidth)
                    Spacer(minLength: 0)
                    layeredFrameBar(axis: .vertical, reversed: true).frame(width: frameWidth)
                }
                .padding(.top, topHeight - 1)
                .overlay {
                    HStack {
                        LinearGradient(colors: [.white.opacity(0.20), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(width: frameWidth)
                        .shadow(color: LockUSceneTokens.Shadow.structural, radius: 3, x: 2)
                        Spacer()
                        LinearGradient(colors: [.clear, LockUSceneTokens.Material.lockerMetalShadow.opacity(0.20)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(width: frameWidth)
                        .shadow(color: LockUSceneTokens.Shadow.structural, radius: 3, x: -2)
                    }
                    .padding(.top, topHeight - 1)
                }

                LockerNamePlateView(
                    number: settingsRepository.settings.lockerNumber,
                    ownerName: settingsRepository.settings.ownerName
                )
                .frame(width: min(92, proxy.size.width * 0.27), height: 44)
                .position(x: proxy.size.width / 2, y: 22)
            }
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(
                        LinearGradient(
                            colors: [
                                LockUDesign.Color.lockerEdgeHighlight.opacity(0.72),
                                .white.opacity(0.12),
                            LockUDesign.Color.deepMetal.opacity(0.82)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
            .shadow(color: LockUSceneTokens.Shadow.structural, radius: 10, x: 1, y: 6)
        }
    }

    private func layeredFrameBar(axis: Axis, reversed: Bool = false) -> some View {
        let start: UnitPoint = axis == .horizontal ? (reversed ? .bottom : .top) : (reversed ? .trailing : .leading)
        let end: UnitPoint = axis == .horizontal ? (reversed ? .top : .bottom) : (reversed ? .leading : .trailing)
        return LinearGradient(
            colors: [lockerColor, lockerColor.opacity(0.96), lockerColor.opacity(0.90)],
            startPoint: start,
            endPoint: end
        )
        .overlay(LinearGradient(colors: [.white.opacity(0.18), .clear, LockUSceneTokens.Material.lockerMetalShadow.opacity(0.16)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .overlay(alignment: axis == .horizontal ? .bottom : (reversed ? .leading : .trailing)) {
            Rectangle().fill(LockUSceneTokens.Material.lockerMetalShadow.opacity(0.34)).frame(width: axis == .vertical ? 1 : nil, height: axis == .horizontal ? 1 : nil)
        }
    }

    private func topFrame(height: CGFloat) -> some View {
        layeredFrameBar(axis: .horizontal)
            .frame(height: height)
            .overlay(alignment: .bottom) {
                Rectangle().fill(LockUDesign.Color.lockerEdge.opacity(0.25)).frame(height: 1)
            }
    }
}

private struct LockerInteriorSurface: View {
    let lockerColor: Color
    @ObservedObject var customizationCoordinator: LockerCustomizationCoordinator

    var body: some View {
        GeometryReader { proxy in
            let side = proxy.size.width * LockUSceneTokens.Home.sideWallFraction
            let ceiling = max(16, min(22, proxy.size.height * 0.032))
            let floor = max(14, proxy.size.height * 0.045)
            let shelfLip = min(8, floor * 0.36)
            let aging = LockUDesign.LockerSurfaceAge.threeMonths.agingProfile
            ZStack {
                LockUSceneTokens.Material.backWall
                    .overlay(lockerColor.opacity(0.055))
                    .clipShape(BackWallShape(side: side, ceiling: ceiling, floor: floor))
                    .allowsHitTesting(false)
                LockUSceneTokens.Material.leftWall
                    .clipShape(LeftInteriorWall(side: side, ceiling: ceiling, floor: floor))
                LockUSceneTokens.Material.rightWall
                    .clipShape(RightInteriorWall(side: side, ceiling: ceiling, floor: floor))
                LinearGradient(colors: [LockUSceneTokens.Material.lockerMetalLight, LockUSceneTokens.Material.lockerMetalBase], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(CeilingPlane(side: side, depth: ceiling))
                LinearGradient(colors: [LockUSceneTokens.Material.shelfTop, LockUSceneTokens.Material.lockerMetalBase], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(BottomPlane(side: side, depth: floor))
                LinearGradient(colors: [LockUSceneTokens.Material.shelfFront, LockUSceneTokens.Material.lockerMetalShadow], startPoint: .top, endPoint: .bottom)
                    .frame(height: shelfLip)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .shadow(color: LockUSceneTokens.Shadow.structural, radius: 3, x: 1, y: 2)

                LockerSurfaceTexture(profile: aging)
                    .padding(.horizontal, 1)

                InteriorLightFalloff(side: side, ceiling: ceiling, floor: floor)
                    .allowsHitTesting(false)
                InteriorHardwareOverlay(side: side, ceiling: ceiling, floor: floor)
                    .allowsHitTesting(false)

                LockerInteriorContent(isCustomizingTopShelf: false)
                    .padding(.horizontal, side + 1)
                    .padding(.top, ceiling)
                    .padding(.bottom, floor)
                    .allowsHitTesting(!customizationCoordinator.isEditing)

                LockerBodyDrawingLayer(
                    coordinator: customizationCoordinator,
                    isDrawingEnabled: customizationCoordinator.isEditing && customizationCoordinator.selectedTool == .draw
                )
                .padding(.horizontal, side + 1)
                .padding(.top, ceiling)
                .padding(.bottom, floor)

                InteriorAmbientOcclusion(side: side, ceiling: ceiling, floor: floor)
                LinearGradient(colors: [.black.opacity(0.12), .clear, .white.opacity(0.08), .clear, .black.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .allowsHitTesting(false)
            }
            .background(LockUSceneTokens.Material.lockerMetalShadow)
            .overlay(
                Rectangle()
                    .strokeBorder(LockUSceneTokens.Material.lockerInk.opacity(0.12), lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .shadow(color: LockUSceneTokens.Shadow.structural, radius: 5, x: 1, y: 2)
        }
    }
}

struct LockerInteriorBackground: View {
    let style: LockerBackgroundStyle

    var body: some View {
        LinearGradient(colors: style.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(LinearGradient(colors: [Color(red: 214/255, green: 239/255, blue: 246/255).opacity(0.16), .clear, Color(red: 250/255, green: 241/255, blue: 218/255).opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Canvas { context, size in
                    for index in 0..<18 {
                        let x = CGFloat((index * 47) % 101) / 101 * size.width
                        let y = CGFloat((index * 71) % 103) / 103 * size.height
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 0.7, height: 0.7)), with: .color(.white.opacity(0.035)))
                    }
                    for index in 0..<7 {
                        let x = CGFloat((index * 37 + 11) % 97) / 97 * size.width
                        let y = CGFloat((index * 61 + 19) % 101) / 101 * size.height
                        var scratch = Path()
                        scratch.move(to: CGPoint(x: x, y: y))
                        scratch.addLine(to: CGPoint(x: x + 5 + CGFloat(index % 3) * 2, y: y + 0.6))
                        context.stroke(scratch, with: .color(.white.opacity(0.045)), lineWidth: 0.55)
                    }
                }
            }
            .overlay(LinearGradient(colors: [.white.opacity(style.topLightOpacity), .clear, .black.opacity(0.025)], startPoint: .top, endPoint: .bottom))
            .accessibilityHidden(true)
    }
}

private extension LockerBackgroundStyle {
    var colors: [Color] {
        switch self {
        case .clearBlue: [Color(red: 205/255, green: 217/255, blue: 221/255), Color(red: 199/255, green: 211/255, blue: 215/255)]
        case .softSky: [Color(red: 211/255, green: 223/255, blue: 227/255), Color(red: 204/255, green: 217/255, blue: 221/255)]
        case .warmSunset: [Color(red: 188/255, green: 174/255, blue: 159/255), Color(red: 181/255, green: 167/255, blue: 153/255)]
        case .paleCream: [Color(red: 201/255, green: 198/255, blue: 188/255), Color(red: 195/255, green: 192/255, blue: 182/255)]
        case .coolGray: [Color(red: 207/255, green: 216/255, blue: 219/255), Color(red: 200/255, green: 210/255, blue: 213/255)]
        case .fadedSchoolBlue: [Color(red: 192/255, green: 208/255, blue: 214/255), Color(red: 185/255, green: 201/255, blue: 207/255)]
        }
    }
    var topLightOpacity: Double { self == .warmSunset ? 0.025 : 0.035 }
}

private struct LockerSurfaceTexture: View {
    let profile: LockUSurfaceAgingProfile

    var body: some View {
        ZStack {
            Canvas { context, size in
                for index in 0..<52 {
                    let x = CGFloat((index * 37 + index * index * 3) % 103) / 103 * size.width
                    let y = CGFloat((index * 61 + index * index) % 101) / 101 * size.height
                    let diameter = CGFloat(5 + (index * 7) % 11) / 10
                    let grainColor = index.isMultiple(of: 3)
                        ? Color.white.opacity(0.022)
                        : Color(red: 102/255, green: 112/255, blue: 115/255).opacity(0.018)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)),
                        with: .color(grainColor)
                    )
                }

                for index in 0..<12 {
                    let x = CGFloat((index * 43 + 11) % 97) / 97 * size.width
                    let y = CGFloat((index * 67 + 7) % 89) / 89 * size.height
                    var scratch = Path()
                    scratch.move(to: CGPoint(x: x, y: y))
                    scratch.addLine(to: CGPoint(x: x + CGFloat(index % 3), y: y + CGFloat(4 + index % 9)))
                    context.stroke(scratch, with: .color(.white.opacity(profile.scratchIntensity)), lineWidth: 0.35)
                }
            }

            LinearGradient(
                colors: [.white.opacity(0.018), .clear, .black.opacity(0.015), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .opacity(0.9)

            Rectangle()
                .strokeBorder(Color(red: 103/255, green: 113/255, blue: 116/255).opacity(profile.edgeWearIntensity), lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct BackWallShape: Shape {
    let side: CGFloat; let ceiling: CGFloat; let floor: CGFloat
    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: side, y: ceiling, width: rect.width - side * 2, height: rect.height - ceiling - floor))
    }
}

private struct LeftInteriorWall: Shape { let side, ceiling, floor: CGFloat; func path(in r: CGRect) -> Path { Path { p in p.move(to: .zero); p.addLine(to: CGPoint(x: side, y: ceiling)); p.addLine(to: CGPoint(x: side, y: r.height-floor)); p.addLine(to: CGPoint(x: 0, y: r.height)); p.closeSubpath() } } }
private struct RightInteriorWall: Shape { let side, ceiling, floor: CGFloat; func path(in r: CGRect) -> Path { Path { p in p.move(to: CGPoint(x:r.width,y:0)); p.addLine(to: CGPoint(x:r.width-side,y:ceiling)); p.addLine(to: CGPoint(x:r.width-side,y:r.height-floor)); p.addLine(to: CGPoint(x:r.width,y:r.height)); p.closeSubpath() } } }
private struct CeilingPlane: Shape { let side, depth: CGFloat; func path(in r: CGRect) -> Path { Path { p in p.move(to:.zero); p.addLine(to:CGPoint(x:r.width,y:0)); p.addLine(to:CGPoint(x:r.width-side,y:depth)); p.addLine(to:CGPoint(x:side,y:depth)); p.closeSubpath() } } }
private struct BottomPlane: Shape { let side, depth: CGFloat; func path(in r: CGRect) -> Path { Path { p in p.move(to:CGPoint(x:0,y:r.height)); p.addLine(to:CGPoint(x:side,y:r.height-depth)); p.addLine(to:CGPoint(x:r.width-side,y:r.height-depth)); p.addLine(to:CGPoint(x:r.width,y:r.height)); p.closeSubpath() } } }

private struct InteriorAmbientOcclusion: View {
    let side, ceiling, floor: CGFloat
    var body: some View { GeometryReader { p in
        ZStack {
            Rectangle().fill(.black.opacity(0.20)).frame(width: 2).blur(radius: 2).position(x: side, y: p.size.height/2)
            Rectangle().fill(.black.opacity(0.18)).frame(width: 2).blur(radius: 2).position(x: p.size.width-side, y: p.size.height/2)
            Rectangle().fill(.black.opacity(0.20)).frame(height: 2).blur(radius: 3).position(x: p.size.width/2, y: ceiling)
            Rectangle().fill(.black.opacity(0.22)).frame(height: 3).blur(radius: 3).position(x: p.size.width/2, y: p.size.height-floor)
        }
    }.allowsHitTesting(false) }
}

private struct InteriorLightFalloff: View {
    let side, ceiling, floor: CGFloat
    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.16), location: 0),
                    .init(color: .clear, location: 0.14),
                    .init(color: .white.opacity(0.07), location: 0.46),
                    .init(color: .clear, location: 0.70),
                    .init(color: .black.opacity(0.13), location: 1)
                ], startPoint: .top, endPoint: .bottom
            )
            LinearGradient(colors: [.white.opacity(0.035), .clear, .black.opacity(0.07)], startPoint: .leading, endPoint: .trailing)
        }
        .padding(.horizontal, side).padding(.top, ceiling).padding(.bottom, floor)
        .allowsHitTesting(false)
    }
}

private struct InteriorHardwareOverlay: View {
    let side, ceiling, floor: CGFloat
    var body: some View { GeometryReader { p in
        ZStack {
            interiorScrew.position(x: side * 0.48, y: ceiling + 35)
            interiorScrew.position(x: p.size.width - side * 0.48, y: ceiling + 35)
            interiorScrew.position(x: side * 0.48, y: p.size.height - floor - 24)
            interiorScrew.position(x: p.size.width - side * 0.48, y: p.size.height - floor - 24)
            Ellipse().fill(Color(red: 115/255, green: 89/255, blue: 74/255).opacity(0.004)).frame(width: 8, height: 2)
                .position(x: side + 4, y: p.size.height - floor - 1)
            Ellipse().fill(Color(red: 139/255, green: 105/255, blue: 86/255).opacity(0.003)).frame(width: 7, height: 2)
                .position(x: p.size.width - side - 4, y: p.size.height - floor - 1)
        }
    }.allowsHitTesting(false).accessibilityHidden(true) }

    private var interiorScrew: some View {
        Circle().fill(Color(red: 48/255, green: 56/255, blue: 59/255))
            .frame(width: 4, height: 4)
            .overlay(Circle().fill(Color(red: 135/255, green: 146/255, blue: 150/255)).frame(width: 2.8, height: 2.8))
            .overlay(Circle().fill(.white.opacity(0.42)).frame(width: 1, height: 1).offset(x: -0.7, y: -0.7))
            .shadow(color: .black.opacity(0.22), radius: 1, y: 1)
    }
}

struct LockerNamePlateView: View {
    let number: String
    let ownerName: String

    var body: some View {
        VStack(spacing: 1) {
            Text(number.isEmpty ? "24" : number)
                .font(.system(size: 22, weight: .semibold))
                .minimumScaleFactor(0.7)
            Text(ownerName.isEmpty ? "MY LOCKER" : "\(ownerName.uppercased()) LOCKER")
                .font(.system(size: 7, weight: .medium))
                .tracking(0.8)
                .lineLimit(1)
        }
        .foregroundStyle(LockUDesign.Color.ink)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(Color(red: 236/255, green: 237/255, blue: 232/255), in: RoundedRectangle(cornerRadius: 1.5))
        .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(Color(red: 195/255, green: 198/255, blue: 196/255), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("ロッカー \(number)、\(ownerName.isEmpty ? "ロッカー" : ownerName)")
    }
}

#Preview("Locker Home") {
    LockURootView()
}
