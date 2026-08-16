import SwiftUI
import UIKit

struct LockerMemoryBoardView: View {
    @EnvironmentObject private var memoryRepository: MemoryRepository
    @EnvironmentObject private var appModel: LockUAppModel
    @EnvironmentObject private var settingsRepository: LockerSettingsRepository
    @EnvironmentObject private var demoClock: LockUDemoClock
    @EnvironmentObject private var resurfacingCoordinator: LockerResurfacingCoordinator
    @EnvironmentObject private var revisitCoordinator: RevisitCoordinator
    @EnvironmentObject private var editingCoordinator: LockerCanvasEditingCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var selectedMemoryID: UUID?
    @State private var presentedThenNowPair: ThenNowMemoryPair?
    @State private var presentedSelfDiscovery: SelfDiscoveryMoment?
    let appearanceOverride: LockerAppearanceSettings?

    init(appearanceOverride: LockerAppearanceSettings? = nil) {
        self.appearanceOverride = appearanceOverride
    }

    private var appearance: LockerAppearanceSettings {
        appearanceOverride ?? settingsRepository.settings.appearance
    }

    private var recentMemories: [MemoryRecord] {
        let sorted = memoryRepository.memories.sorted { $0.createdAt > $1.createdAt }
        let base: [MemoryRecord]
        guard let featuredID = appearance.featuredVideoMemoryID,
              let featured = sorted.first(where: { $0.id == featuredID }) else {
            base = Array(sorted.prefix(LockerMemoryLayout.totalVisibleSlotCount))
            return memoriesReplacingOneStillSlot(in: base)
        }
        base = [featured] + Array(sorted.filter { $0.id != featured.id }.prefix(LockerMemoryLayout.photoSlotCount))
        return memoriesReplacingOneStillSlot(in: base)
    }

    private var thenNowPair: ThenNowMemoryPair? {
        ThenNowPairingService().pair(for: demoClock.now, memories: memoryRepository.memories)
    }

    private var selfDiscoveryMoment: SelfDiscoveryMoment? {
        SelfDiscoveryService().moment(for: demoClock.now, memories: memoryRepository.memories)
    }

    private func memoriesReplacingOneStillSlot(in base: [MemoryRecord]) -> [MemoryRecord] {
        guard base.count >= LockerMemoryLayout.totalVisibleSlotCount,
              let candidateID = resurfacingCoordinator.candidateMemoryID,
              let candidate = memoryRepository.memories.first(where: { $0.id == candidateID }),
              !base.contains(where: { $0.id == candidateID }) else { return base }
        var result = base
        let replacementIndex = min(3, result.count - 1)
        guard replacementIndex > 0 else { return base }
        result[replacementIndex] = candidate
        return result
    }

    var body: some View {
        GeometryReader { proxy in
            let placements = DeterministicMemoryWallPlacementEngine().layout(
                memories: recentMemories,
                containerSize: proxy.size,
                appearance: appearance,
                date: demoClock.now
            )
            ZStack {
                boardSurface

                if recentMemories.isEmpty {
                    Text("ここから、少しずつ。")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(LockUDesign.Color.schoolNavy.opacity(0.48))
                } else {
                    ForEach(placements) { placement in
                        memoryView(for: placement)
                            .frame(width: placement.width)
                            .rotationEffect(.degrees(placement.rotation))
                            .position(placement.position)
                            .zIndex(selectedMemoryID == placement.id ? LockUSceneTokens.Layer.memory + 40 : LockUSceneTokens.Layer.memory + placement.zIndex)
                            .opacity(appModel.isPlacementRitualActive(for: placement.memory.id) ? 0 : (appeared ? 1 : 0))
                            .offset(y: appeared ? 0 : 5)
                            .animation(
                                reduceMotion ? nil : .easeOut(duration: 0.35).delay(Double(min(placement.index, 8)) * 0.035),
                                value: appeared
                            )
                            .transition(.scale(scale: 0.98).combined(with: .opacity))
                            .onAppear {
                                registerRitualDestination(placement, boardProxy: proxy)
                            }
                            .allowsHitTesting(!editingCoordinator.isEditing)
                    }
                }

                LockerCanvasLayer()
                    .zIndex(editingCoordinator.isEditing ? 100 : 15)

                if selfDiscoveryMoment == nil, let pair = thenNowPair {
                    VStack {
                        HStack {
                            Button {
                                presentedThenNowPair = pair
                            } label: {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("あの時と、いま").font(.system(size: 9, weight: .semibold))
                                    Text("この頃と、今").font(.system(size: 8, weight: .regular))
                                }
                                .foregroundStyle(LockUDesign.Color.schoolNavy.opacity(0.72))
                                .padding(.horizontal, 9).padding(.vertical, 6)
                                .background(LockUDesign.Color.notebookPaper.opacity(0.86), in: RoundedRectangle(cornerRadius: 4))
                                .rotationEffect(.degrees(-1.2))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("あの時と今を見る")
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(8)
                    .zIndex(90)
                    .allowsHitTesting(!editingCoordinator.isEditing)
                }

                if let moment = selfDiscoveryMoment {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                presentedSelfDiscovery = moment
                            } label: {
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text("こんな日もあった").font(.system(size: 9, weight: .semibold))
                                    Text("思い出 × 3").font(.system(size: 7.5, weight: .medium))
                                }
                                .foregroundStyle(LockUDesign.Color.schoolNavy.opacity(0.70))
                                .padding(.horizontal, 9).padding(.vertical, 6)
                                .background(LockUDesign.Color.notebookPaper.opacity(0.84), in: RoundedRectangle(cornerRadius: 4))
                                .rotationEffect(.degrees(1.1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("こんな日もあった、3枚のMemoryを見る")
                        }
                    }
                    .padding(8)
                    .zIndex(90)
                    .allowsHitTesting(!editingCoordinator.isEditing)
                }
            }
            .padding(.horizontal, max(4, proxy.size.width * 0.025))
            .padding(.vertical, 5)
            .onAppear { appeared = true }
            .sheet(item: $presentedThenNowPair) { pair in
                ThenNowView(pair: pair)
            }
            .sheet(item: $presentedSelfDiscovery) { moment in
                SelfDiscoveryView(moment: moment)
            }
        }
    }

    private var boardSurface: some View {
        LinearGradient(
            colors: [.white.opacity(0.045), .clear, .black.opacity(0.03)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .allowsHitTesting(false)
    }

    private func registerRitualDestination(_ placement: MemoryWallPlacement, boardProxy: GeometryProxy) {
        guard appModel.placementRitual?.memoryID == placement.memory.id else { return }
        let boardFrame = boardProxy.frame(in: .global)
        let horizontalInset = max(4, boardProxy.size.width * 0.025)
        let height = placement.width / max(placement.printAspectRatio, 0.1)
        let frame = CGRect(
            x: boardFrame.minX + horizontalInset + placement.position.x - placement.width / 2,
            y: boardFrame.minY + 5 + placement.position.y - height / 2,
            width: placement.width,
            height: height
        )
        appModel.registerPlacementRitualDestination(
            memoryID: placement.memory.id,
            destination: MemoryPlacementRitualDestination(
                frame: frame,
                rotationDegrees: placement.rotation,
                frameStyle: placement.frameStyle
            )
        )
    }

    @ViewBuilder
    private func memoryView(for placement: MemoryWallPlacement) -> some View {
        if placement.isLiving {
            LivingMemoryView(
                memory: placement.memory,
                frameStyle: placement.frameStyle,
                filterStyle: placement.filterStyle,
                filterAdjustment: placement.filterAdjustment,
                printAspectRatio: placement.printAspectRatio
            )
        } else {
            MemoryPhysicalView(
                memory: placement.memory,
                role: memoryRole(for: placement.memory, index: placement.index),
                attachment: placement.tapeStyle,
                frameStyle: placement.frameStyle,
                filterStyle: placement.filterStyle,
                filterAdjustment: placement.filterAdjustment,
                printAspectRatio: placement.printAspectRatio,
                tapePaletteIndex: placement.index == 7 ? 2 : (placement.index == 4 ? 0 : 1),
                isSelected: selectedMemoryID == placement.id,
                isResurfaced: resurfacingCoordinator.candidateMemoryID == placement.memory.id,
                onSelect: { select(placement.memory) }
            )
        }
    }

    private func toggleSelection(for id: UUID) {
        selectedMemoryID = selectedMemoryID == id ? nil : id
    }

    private func select(_ memory: MemoryRecord) {
        if resurfacingCoordinator.candidateMemoryID == memory.id {
            revisitCoordinator.present(memory: memory, now: demoClock.now)
            appModel.selectedTab = .peek
            return
        }
        guard memory.isDualCameraMemory else {
            toggleSelection(for: memory.id)
            return
        }
        appModel.peekMemory = memory
        appModel.selectedTab = .peek
    }

    private func memoryRole(for memory: MemoryRecord, index: Int) -> MemoryVisualRole {
        if memory.isSubjectCutout ?? false { return .cutout }
        if index == 0 { return .hero }
        switch MemoryPresentationResolver().resolve(memory) {
        case .cheki: return .cheki
        case .photobooth: return .mini
        case .digicam: return .digicam
        case .cutout: return .cutout
        }
    }

}

enum MemoryVisualRole { case hero, cheki, digicam, cutout, mini }
enum MemoryAttachment { case none, clearTape, maskingTape, magnet }

private enum MemoryDensity: Equatable {
    case empty, early, growing, full, dense

    init(count: Int) {
        switch count {
        case 0: self = .empty
        case 1...4: self = .early
        case 5...9: self = .growing
        case 10...15: self = .full
        default: self = .dense
        }
    }
}

private struct MemoryWallPlacement: Identifiable {
    let memory: MemoryRecord
    let index: Int
    let position: CGPoint
    let width: CGFloat
    let rotation: Double
    let zIndex: Double
    let tapeStyle: MemoryAttachment
    let frameStyle: LockerFrameStyle
    let filterStyle: LockerFilterStyle
    let filterAdjustment: DailyLockerFilterAdjustment
    let printAspectRatio: CGFloat
    let isLiving: Bool

    var id: UUID { memory.id }
}

private struct DeterministicMemoryWallPlacementEngine {
    private let anchors: [CGPoint] = [
        CGPoint(x: 0.50, y: 0.43),
        CGPoint(x: 0.20, y: 0.145), CGPoint(x: 0.78, y: 0.17),
        CGPoint(x: 0.135, y: 0.42), CGPoint(x: 0.855, y: 0.43),
        CGPoint(x: 0.20, y: 0.73), CGPoint(x: 0.49, y: 0.79), CGPoint(x: 0.82, y: 0.72)
    ]
    private let widthFractions: [CGFloat] = [0.43, 0.28, 0.23, 0.215, 0.28, 0.27, 0.215, 0.24]
    private let rotationPresets: [Double] = [-0.4, -3.1, 2.7, -1.8, 3.2, -2.8, 1.9, -2.2]
    private let aspectRatios: [CGFloat] = [0.82, 0.82, 0.74, 0.67, 1.0, 0.86, 0.74, 0.90]

    func layout(memories: [MemoryRecord], containerSize: CGSize, appearance: LockerAppearanceSettings, date: Date) -> [MemoryWallPlacement] {
        let density = MemoryDensity(count: memories.count)
        guard density != .empty, containerSize.width > 0, containerSize.height > 0 else { return [] }
        let variation = DailyLockerVariationEngine().variation(
            for: date,
            memories: memories,
            isEnabled: appearance.dailyVariationEnabled
        )

        return memories.enumerated().map { index, memory in
            let presetIndex = index % anchors.count
            let anchor = anchors[presetIndex]
            let daily = variation.memoryAdjustments[memory.id] ?? .none
            let width = containerSize.width * widthFractions[presetIndex]
            let halfX = width / containerSize.width / 2 + 0.012
            let printAspectRatio = daily.printAspectRatioOverride ?? aspectRatios[presetIndex]
            let estimatedHeight = width / printAspectRatio
            let halfY = estimatedHeight / containerSize.height / 2 + 0.012
            let attachment: MemoryAttachment
            switch index {
            case 1, 4, 7: attachment = .maskingTape
            default: attachment = .none
            }

            return MemoryWallPlacement(
                memory: memory,
                index: index,
                position: CGPoint(
                    x: min(max(anchor.x * containerSize.width + daily.positionOffset.width, halfX * containerSize.width), (1 - halfX) * containerSize.width),
                    y: min(max(anchor.y * containerSize.height + daily.positionOffset.height, halfY * containerSize.height), (1 - halfY) * containerSize.height)
                ),
                width: width,
                rotation: index == 0
                    ? min(max(rotationPresets[presetIndex] + daily.rotationOffset * 0.3, -1.5), 1.5)
                    : min(max(rotationPresets[presetIndex] + daily.rotationOffset, -4), 4),
                zIndex: index == 0 ? 30 : Double(20 + (index % 7)),
                tapeStyle: index == 0 ? .none : attachment,
                frameStyle: daily.frameOverride ?? resolvedFrame(appearance.frameStyle, collage: appearance.collageStyle, index: index),
                filterStyle: appearance.filterStyle,
                filterAdjustment: index == 0 ? variation.filterAdjustment.featuredVideoAdjustment : variation.filterAdjustment,
                printAspectRatio: printAspectRatio,
                isLiving: index == 0
            )
        }
    }

    private func resolvedFrame(_ selected: LockerFrameStyle, collage: LockerCollageStyle, index: Int) -> LockerFrameStyle {
        guard selected == .mixed else { return selected }
        let sequence: [LockerFrameStyle]
        switch collage {
        case .polaroid: sequence = [.polaroid, .polaroid, .thinWhite, .polaroid]
        case .digicam: sequence = [.thinWhite, .borderless, .thinWhite, .polaroid]
        case .balanced, .casual: sequence = [.polaroid, .polaroid, .thinWhite, .borderless, .thinWhite, .polaroid, .borderless, .thinWhite]
        }
        return sequence[index % sequence.count]
    }
}

private struct DailyLockerFilterAdjustment: Equatable {
    let brightness: Double
    let contrast: Double
    let saturation: Double
    let warmth: Double

    static let none = DailyLockerFilterAdjustment(brightness: 0, contrast: 0, saturation: 0, warmth: 0)

    var featuredVideoAdjustment: Self {
        Self(brightness: brightness * 0.25, contrast: 0, saturation: 0, warmth: warmth * 0.15)
    }
}

private struct DailyLockerMemoryAdjustment: Equatable {
    let positionOffset: CGSize
    let rotationOffset: Double
    let frameOverride: LockerFrameStyle?
    let printAspectRatioOverride: CGFloat?

    static let none = DailyLockerMemoryAdjustment(positionOffset: .zero, rotationOffset: 0, frameOverride: nil, printAspectRatioOverride: nil)
}

private struct DailyLockerVariation: Equatable {
    let seed: Int
    let memoryAdjustments: [UUID: DailyLockerMemoryAdjustment]
    let filterAdjustment: DailyLockerFilterAdjustment

    static let none = DailyLockerVariation(seed: 0, memoryAdjustments: [:], filterAdjustment: .none)
}

private struct DailyLockerVariationEngine {
    func variation(for date: Date, memories: [MemoryRecord], isEnabled: Bool, calendar: Calendar = .autoupdatingCurrent) -> DailyLockerVariation {
        guard isEnabled, memories.count > 1 else { return .none }
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let seed = (components.year ?? 0) * 10_000 + (components.month ?? 0) * 100 + (components.day ?? 0)
        var generator = DailySeedGenerator(state: UInt64(max(seed, 1)))
        let photoIDs = Array(memories.dropFirst().prefix(LockerMemoryLayout.photoSlotCount).map(\.id))
        let affectedCount = min(photoIDs.count, generator.nextInt(in: 1...2))
        var available = photoIDs
        var selected: [UUID] = []
        for _ in 0..<affectedCount where !available.isEmpty {
            selected.append(available.remove(at: generator.nextInt(in: 0...(available.count - 1))))
        }

        let frameOptions: [LockerFrameStyle] = [.polaroid, .thinWhite, .borderless]
        var adjustments: [UUID: DailyLockerMemoryAdjustment] = [:]
        for (offset, id) in selected.enumerated() {
            let x = generator.nextDouble(in: -7...7)
            let y = generator.nextDouble(in: -7...7)
            let rotationMagnitude = generator.nextDouble(in: 0.5...1.2)
            let rotation = generator.nextBool() ? rotationMagnitude : -rotationMagnitude
            let changesFrame = offset == 0 && generator.nextBool()
            let usesSquarePrint = changesFrame && generator.nextInt(in: 0...3) == 3
            adjustments[id] = DailyLockerMemoryAdjustment(
                positionOffset: CGSize(width: x, height: y),
                rotationOffset: rotation,
                frameOverride: changesFrame && !usesSquarePrint ? frameOptions[generator.nextInt(in: 0...(frameOptions.count - 1))] : nil,
                printAspectRatioOverride: usesSquarePrint ? 1 : nil
            )
        }

        return DailyLockerVariation(
            seed: seed,
            memoryAdjustments: adjustments,
            filterAdjustment: DailyLockerFilterAdjustment(
                brightness: generator.nextDouble(in: -0.02...0.02),
                contrast: generator.nextDouble(in: -0.03...0.03),
                saturation: generator.nextDouble(in: -0.03...0.03),
                warmth: generator.nextDouble(in: -0.025...0.025)
            )
        )
    }
}

private struct DailySeedGenerator {
    private var state: UInt64
    init(state: UInt64) { self.state = state }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
    mutating func nextBool() -> Bool { next().isMultiple(of: 2) }
    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(next() % UInt64(range.upperBound - range.lowerBound + 1))
    }
    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        let unit = Double(next() >> 11) / Double(1 << 53)
        return range.lowerBound + (range.upperBound - range.lowerBound) * unit
    }
}

private struct LivingMemoryView: View {
    @EnvironmentObject private var appModel: LockUAppModel
    let memory: MemoryRecord
    let frameStyle: LockerFrameStyle
    let filterStyle: LockerFilterStyle
    let filterAdjustment: DailyLockerFilterAdjustment
    let printAspectRatio: CGFloat

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            appModel.selectedTab = .book
        } label: {
            PolaroidPrint(memory: memory, frameStyle: frameStyle, filterStyle: filterStyle, filterAdjustment: filterAdjustment, isFeatured: true, printAspectRatio: printAspectRatio)
                .overlay(alignment: .topTrailing) {
                    HStack(spacing: 3) {
                        Circle().fill(Color.red.opacity(0.72)).frame(width: 4, height: 4)
                        Text("REC").font(.system(size: 6.5, weight: .semibold, design: .monospaced)).tracking(0.5)
                        Image(systemName: "play.fill").font(.system(size: 6, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.84))
                    .padding(.horizontal, 5).padding(.vertical, 4)
                    .background(.black.opacity(0.13), in: RoundedRectangle(cornerRadius: 3))
                    .padding(7)
                }
                .shadow(color: .black.opacity(0.085), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("最新の思い出、\(memory.createdAt.formatted(date: .abbreviated, time: .shortened))")
    }
}

private struct PolaroidPrint: View {
    let memory: MemoryRecord
    let frameStyle: LockerFrameStyle
    let filterStyle: LockerFilterStyle
    let filterAdjustment: DailyLockerFilterAdjustment
    let isFeatured: Bool
    let printAspectRatio: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let variant = PolaroidVisualVariant(memoryID: memory.id)
            let sideMargin = proxy.size.width * sideMarginFraction
            let topMargin = proxy.size.height * topMarginFraction
            let bottomMargin = proxy.size.height * bottomMarginFraction
            let photoHeight = max(0, proxy.size.height - topMargin - bottomMargin)

            ZStack(alignment: .topLeading) {
                PolaroidPaperView(
                    variant: variant,
                    isVisible: frameStyle != .borderless
                )

                MemoryPhotoSurface(memoryID: memory.id, variant: variant) {
                    Group {
                        if memory.isDualCameraMemory {
                            DualMemoryImageSurface(
                                memory: memory,
                                purpose: .locker,
                                targetPointSize: CGSize(width: proxy.size.width, height: photoHeight)
                            )
                        } else {
                            DownsampledMemoryImage(
                                memory: memory,
                                purpose: .locker,
                                targetPointSize: CGSize(width: proxy.size.width, height: photoHeight)
                            )
                        }
                    }
                    .modifier(LockerMemoryFilterModifier(style: filterStyle, adjustment: filterAdjustment))
                }
                .frame(width: proxy.size.width - sideMargin * 2, height: photoHeight)
                .offset(x: sideMargin, y: topMargin)

                if frameStyle == .polaroid || frameStyle == .mixed {
                    MemoryDateStampView(date: memory.createdAt, memoryID: memory.id, printWidth: proxy.size.width)
                        .frame(width: proxy.size.width - sideMargin * 2, alignment: .trailing)
                        .offset(
                            x: sideMargin + variant.dateOffset.width,
                            y: proxy.size.height - bottomMargin * 0.60 + variant.dateOffset.height
                        )
                }

                if memory.moodEmoji != nil {
                    MemoryExpressionMark(memory: memory, frameStyle: frameStyle)
                        .frame(maxWidth: proxy.size.width * 0.86, alignment: expressionAlignment)
                        .offset(x: expressionX(sideMargin: sideMargin), y: expressionY(height: proxy.size.height, bottomMargin: bottomMargin))
                }
            }
            .clipShape(ImperfectPhotoShape())
        }
        .aspectRatio(printAspectRatio, contentMode: .fit)
    }

    private var sideMarginFraction: CGFloat {
        switch frameStyle { case .polaroid, .mixed: 0.055; case .thinWhite: 0.025; case .borderless: 0 }
    }
    private var topMarginFraction: CGFloat {
        switch frameStyle { case .polaroid, .mixed: 0.055; case .thinWhite: 0.022; case .borderless: 0 }
    }
    private var bottomMarginFraction: CGFloat {
        switch frameStyle {
        case .polaroid, .mixed: isFeatured ? 0.19 : 0.17
        case .thinWhite: 0.025
        case .borderless: 0
        }
    }

    private var expressionAlignment: Alignment { frameStyle == .borderless ? .trailing : .leading }
    private func expressionX(sideMargin: CGFloat) -> CGFloat { frameStyle == .borderless ? sideMargin * 0.25 : sideMargin }
    private func expressionY(height: CGFloat, bottomMargin: CGFloat) -> CGFloat {
        switch frameStyle {
        case .polaroid, .mixed: height - max(32, bottomMargin)
        case .thinWhite, .borderless: 5
        }
    }
}

private struct MemoryExpressionMark: View {
    let memory: MemoryRecord
    let frameStyle: LockerFrameStyle

    var body: some View {
        Group {
            if let emoji = memory.moodEmoji {
                Text(emoji)
                    .font(.system(size: 17))
                    .opacity(0.92)
                    .shadow(color: .black.opacity(0.07), radius: 1, y: 0.5)
                    .accessibilityLabel(MemoryMoodEmoji(rawValue: emoji)?.accessibilityLabel ?? emoji)
            }
        }
        .padding(4)
    }
}

private struct DownsampledMemoryImage: View {
    @EnvironmentObject private var repository: MemoryRepository
    @State private var image: UIImage?
    let memory: MemoryRecord
    let purpose: MemoryImagePurpose
    let targetPointSize: CGSize

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(white: 0.52)
                    .overlay(Image(systemName: "photo").foregroundStyle(.white.opacity(0.65)))
            }
        }
        .task(id: loadKey) {
            image = await repository.imageAsync(
                for: memory,
                purpose: purpose,
                targetPointSize: targetPointSize
            )
        }
        .onDisappear { image = nil }
    }

    private var loadKey: String {
        "\(memory.id.uuidString)-\(purpose.rawValue)-\(Int(targetPointSize.width.rounded()))x\(Int(targetPointSize.height.rounded()))"
    }
}

private struct PolaroidVisualVariant {
    let index: Int
    let digicamStyle: DigicamPhotoStyle

    init(memoryID: UUID) {
        let stableHash = memoryID.uuidString.utf8.reduce(0) { ($0 &* 31 + Int($1)) % 9_973 }
        index = stableHash % 4
        digicamStyle = DigicamPhotoStyle.variant(stableHash % 5)
    }

    var paperColor: Color {
        switch index {
        case 0: Color(red: 246/255, green: 244/255, blue: 238/255)
        case 1: Color(red: 248/255, green: 245/255, blue: 239/255)
        case 2: Color(red: 244/255, green: 243/255, blue: 237/255)
        default: Color(red: 247/255, green: 242/255, blue: 236/255)
        }
    }

    var dateOffset: CGSize {
        [CGSize(width: -1.5, height: 0.5), CGSize(width: 1, height: -0.5), CGSize(width: -0.5, height: 0), CGSize(width: 1.5, height: 0.8)][index]
    }
}

private struct DigicamPhotoStyle {
    let exposure: Double
    let contrast: Double
    let saturation: Double
    let coolOpacity: Double
    let warmOpacity: Double
    let blackLiftOpacity: Double
    let highlightOpacity: Double
    let noiseAmount: Double
    let flashAmount: Double

    static func variant(_ index: Int) -> Self {
        switch index {
        case 0: // Clear Day
            Self(exposure: 0.010, contrast: 1.04, saturation: 1.00, coolOpacity: 0.012, warmOpacity: 0.004, blackLiftOpacity: 0.008, highlightOpacity: 0.018, noiseAmount: 0.020, flashAmount: 0)
        case 1: // Soft Summer
            Self(exposure: 0.015, contrast: 1.02, saturation: 0.98, coolOpacity: 0.006, warmOpacity: 0.008, blackLiftOpacity: 0.010, highlightOpacity: 0.022, noiseAmount: 0.018, flashAmount: 0)
        case 2: // Indoor Digicam
            Self(exposure: 0.004, contrast: 1.05, saturation: 0.98, coolOpacity: 0, warmOpacity: 0.004, blackLiftOpacity: 0.008, highlightOpacity: 0.012, noiseAmount: 0.024, flashAmount: 0)
        case 3: // Restrained Direct Flash
            Self(exposure: 0.004, contrast: 1.06, saturation: 0.97, coolOpacity: 0.004, warmOpacity: 0.004, blackLiftOpacity: 0.006, highlightOpacity: 0.016, noiseAmount: 0.022, flashAmount: 0.028)
        default: // Faded Digital
            Self(exposure: 0.006, contrast: 1.03, saturation: 0.96, coolOpacity: 0.006, warmOpacity: 0.002, blackLiftOpacity: 0.014, highlightOpacity: 0.014, noiseAmount: 0.020, flashAmount: 0)
        }
    }
}

private struct PolaroidPaperView: View {
    let variant: PolaroidVisualVariant
    let isVisible: Bool

    var body: some View {
        if isVisible {
            ImperfectPhotoShape()
                .fill(variant.paperColor)
                .overlay(PhotoPaperTexture().opacity(0.10))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color(red: 121/255, green: 113/255, blue: 101/255).opacity(0.08))
                        .frame(height: 0.7)
                }
        } else {
            Color.clear
        }
    }
}

private struct MemoryPhotoSurface<Content: View>: View {
    let memoryID: UUID
    let variant: PolaroidVisualVariant
    let content: Content

    init(
        memoryID: UUID,
        variant: PolaroidVisualVariant,
        @ViewBuilder content: () -> Content
    ) {
        self.memoryID = memoryID
        self.variant = variant
        self.content = content()
    }

    var body: some View {
        let style = variant.digicamStyle
        content
            .brightness(style.exposure)
            .contrast(style.contrast)
            .saturation(style.saturation)
            .overlay(coolTone(style).blendMode(SwiftUI.BlendMode.softLight))
            .overlay(warmTone(style).blendMode(SwiftUI.BlendMode.softLight))
            .overlay(Color(red: 1, green: 0.86, blue: 0.72).opacity(0.008).blendMode(SwiftUI.BlendMode.softLight))
            .overlay(blackLift(style).blendMode(SwiftUI.BlendMode.screen))
            .overlay(highlightTone(style).blendMode(SwiftUI.BlendMode.softLight))
            .overlay(DigicamFlashTreatment(amount: style.flashAmount))
            .overlay(PhotoPrintGrain(seed: grainSeed, amount: style.noiseAmount))
            .clipped()
    }

    private var grainSeed: Int {
        memoryID.uuidString.utf8.reduce(0) { ($0 &* 33 + Int($1)) % 101 }
    }

    private func coolTone(_ style: DigicamPhotoStyle) -> SwiftUI.Color {
        SwiftUI.Color(.sRGB, red: 0.72, green: 0.88, blue: 1, opacity: style.coolOpacity)
    }

    private func warmTone(_ style: DigicamPhotoStyle) -> SwiftUI.Color {
        SwiftUI.Color(.sRGB, red: 1, green: 0.84, blue: 0.68, opacity: style.warmOpacity)
    }

    private func blackLift(_ style: DigicamPhotoStyle) -> SwiftUI.Color {
        SwiftUI.Color(.sRGB, red: 0.32, green: 0.32, blue: 0.32, opacity: style.blackLiftOpacity)
    }

    private func highlightTone(_ style: DigicamPhotoStyle) -> SwiftUI.Color {
        SwiftUI.Color(.sRGB, red: 1, green: 1, blue: 1, opacity: style.highlightOpacity)
    }
}

private struct PhotoPrintGrain: View {
    let seed: Int
    let amount: Double

    var body: some View {
        Canvas { context, size in
            for index in 0..<30 {
                let x = CGFloat((index * 41 + seed * 7 + index * index) % 103) / 103 * size.width
                let y = CGFloat((index * 67 + seed * 3 + index * index * 2) % 101) / 101 * size.height
                let diameter = CGFloat(5 + (index + seed) % 6) / 10
                let color = index.isMultiple(of: 3)
                    ? Color.white.opacity(amount)
                    : Color(red: 83/255, green: 87/255, blue: 91/255).opacity(amount * 0.72)
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)), with: .color(color))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct DigicamFlashTreatment: View {
    let amount: Double

    var body: some View {
        if amount > 0 {
            RadialGradient(
                colors: [.white.opacity(amount), .clear, .black.opacity(amount * 0.45)],
                center: .center,
                startRadius: 0,
                endRadius: 150
            )
            .blendMode(.softLight)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        } else {
            Color.clear
        }
    }
}

private struct LockerMemoryFilterModifier: ViewModifier {
    let style: LockerFilterStyle
    let adjustment: DailyLockerFilterAdjustment

    func body(content: Content) -> some View {
        content
            .saturation(saturation)
            .contrast(contrast)
            .brightness(brightness)
            .overlay(tint.blendMode(.softLight).allowsHitTesting(false))
            .overlay(dailyWarmth.blendMode(.softLight).allowsHitTesting(false))
    }

    private var saturation: Double {
        let base: Double
        switch style { case .clear: base = 1; case .digicam: base = 0.96; case .film: base = 0.91; case .aoharu: base = 0.94; case .soft: base = 0.88 }
        return base + adjustment.saturation
    }
    private var contrast: Double {
        let base: Double
        switch style { case .clear: base = 1.0; case .digicam: base = 1.08; case .film: base = 1.02; case .aoharu: base = 0.98; case .soft: base = 0.93 }
        return base + adjustment.contrast
    }
    private var brightness: Double {
        adjustment.brightness + (style == .soft ? 0.018 : 0)
    }
    private var tint: Color {
        switch style {
        case .clear: .clear
        case .digicam: Color(red: 0.72, green: 0.88, blue: 0.94).opacity(0.025)
        case .film: Color(red: 0.96, green: 0.80, blue: 0.58).opacity(0.035)
        case .aoharu: Color(red: 0.60, green: 0.82, blue: 0.96).opacity(0.030)
        case .soft: Color(red: 1.0, green: 0.88, blue: 0.80).opacity(0.025)
        }
    }
    private var dailyWarmth: Color {
        adjustment.warmth >= 0
            ? Color(red: 1, green: 0.77, blue: 0.55).opacity(adjustment.warmth)
            : Color(red: 0.55, green: 0.78, blue: 1).opacity(abs(adjustment.warmth))
    }
}

private struct MemoryDateStampView: View {
    let date: Date
    let memoryID: UUID
    let printWidth: CGFloat

    var body: some View {
        Text(dateText)
            .font(.system(size: fontSize, weight: .regular, design: .monospaced))
            .tracking(0.5)
            .foregroundStyle(Color(red: 79/255, green: 76/255, blue: 70/255).opacity(inkOpacity))
            .lineLimit(1)
            .padding(.trailing, min(9, max(6, printWidth * 0.055)))
            .offset(y: baselineOffset)
            .rotationEffect(.degrees(rotation))
            .accessibilityLabel(date.formatted(date: .long, time: .omitted))
    }

    private var dateText: String {
        let components = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "'%02d %02d %02d",
            (components.year ?? 0) % 100,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private var stableVariant: Int {
        memoryID.uuidString.utf8.reduce(0) { ($0 &* 31 + Int($1)) % 997 }
    }

    private var fontSize: CGFloat { min(9, max(7, printWidth * 0.062)) }
    private var inkOpacity: Double { 0.70 + Double(stableVariant % 3) * 0.025 }
    private var baselineOffset: CGFloat { CGFloat((stableVariant % 3) - 1) * 0.4 }
    private var rotation: Double { Double((stableVariant / 3) % 3 - 1) * 0.25 }
}

private enum MemoryDepthLevel {
    case wall, flatPhoto, paper, raisedSticker, shelfObject, camera
    var shadow: (opacity: Double, radius: CGFloat, y: CGFloat) {
        switch self {
        case .wall: return (0, 0, 0)
        case .flatPhoto: return (0.18, 2, 1)
        case .paper: return (0.22, 4, 2)
        case .raisedSticker: return (0.18, 5, 3)
        case .shelfObject: return (0.24, 6, 5)
        case .camera: return (0.28, 8, 7)
        }
    }
}

private struct MemoryPhysicalView: View {
    @EnvironmentObject private var repository: MemoryRepository
    @EnvironmentObject private var reflectionRepository: MemoryReflectionRepository
    @EnvironmentObject private var demoClock: LockUDemoClock
    @EnvironmentObject private var appModel: LockUAppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let memory: MemoryRecord
    let role: MemoryVisualRole
    let attachment: MemoryAttachment
    let frameStyle: LockerFrameStyle
    let filterStyle: LockerFilterStyle
    let filterAdjustment: DailyLockerFilterAdjustment
    let printAspectRatio: CGFloat
    let tapePaletteIndex: Int
    let isSelected: Bool
    let isResurfaced: Bool
    let onSelect: () -> Void

    private var depth: MemoryDepthLevel {
        switch role { case .cheki: return .paper; case .cutout: return .raisedSticker; default: return .flatPhoto }
    }

    var body: some View {
        PolaroidPrint(memory: memory, frameStyle: frameStyle, filterStyle: filterStyle, filterAdjustment: filterAdjustment, isFeatured: false, printAspectRatio: printAspectRatio)
        .overlay(alignment: .bottomLeading) {
            if frameStyle == .thinWhite || frameStyle == .borderless {
                Text(compactDateStamp)
                    .font(.system(size: 6.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.88))
                    .shadow(color: .black.opacity(0.42), radius: 1)
                    .padding(4)
            }
        }
        .overlay(alignment: .top) { attachmentView }
        .overlay(alignment: .topTrailing) {
            if reflectionCount > 0 {
                Text("↺")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(LockUDesign.Color.softInk.opacity(0.42))
                    .padding(4)
                    .accessibilityLabel("現在のReflectionがあります")
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .topLeading) {
            if isResurfaced {
                Text(resurfacedDateText)
                    .font(.system(size: 6.5, weight: .semibold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(LockUDesign.Color.softInk.opacity(0.52))
                    .padding(5)
                    .accessibilityLabel(resurfacedAccessibilityLabel)
            }
        }
        .saturation(isResurfaced ? 0.90 : 1)
        .overlay(LockUDesign.Color.cameraCream.opacity(isResurfaced ? 0.035 : 0).allowsHitTesting(false))
        .shadow(color: LockUSceneTokens.Shadow.paper, radius: 2.5, y: 1.5)
        .contentShape(Rectangle())
        .onTapGesture { UIImpactFeedbackGenerator(style: .light).impactOccurred(); onSelect() }
        .onTapGesture(count: 2) {
            if !isResurfaced { appModel.selectedTab = .book }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.30), value: reflectionCount)
    }

    private var resurfacedDaysAgo: Int {
        max(1, Calendar.autoupdatingCurrent.dateComponents(
            [.day],
            from: Calendar.autoupdatingCurrent.startOfDay(for: memory.memoryDate),
            to: Calendar.autoupdatingCurrent.startOfDay(for: demoClock.now)
        ).day ?? 1)
    }

    private var resurfacedDateText: String { "\(resurfacedDaysAgo) DAYS AGO" }
    private var resurfacedAccessibilityLabel: String { "\(resurfacedDaysAgo)日前に残したMemory" }
    private var reflectionCount: Int { reflectionRepository.reflections(for: memory.id).count }
    private var compactDateStamp: String {
        let components = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day], from: memory.createdAt)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        if frameStyle == .borderless { return String(format: "%04d %02d %02d", year, month, day) }
        return String(format: "%02d.%02d.%02d", month, day, year % 100)
    }

    @ViewBuilder private var physicalPhoto: some View {
        switch role {
        case .hero, .digicam: digicam
        case .cheki: cheki
        case .mini: photoBooth
        case .cutout: EmptyView()
        }
    }

    private var image: some View {
        Group {
            if let image = repository.image(for: memory, purpose: .locker, targetPointSize: CGSize(width: 220, height: 220)) { Image(uiImage: image).resizable().scaledToFill() }
            else { Color(white: 0.52).overlay(Image(systemName: "photo").foregroundStyle(.white.opacity(0.65))) }
        }
        .overlay {
            Color.white
                .opacity(role == .cheki ? 0.055 : 0.025)
                .blendMode(SwiftUI.BlendMode.screen)
        }
        .contrast(role == .cheki ? 0.92 : 1.04).saturation(role == .cheki ? 0.88 : 0.94)
        .clipped()
    }

    private var digicam: some View {
        image.aspectRatio(4/3, contentMode: .fit)
            .overlay(alignment: .bottomTrailing) { timestamp.padding(5) }
            .clipShape(ImperfectPhotoShape())
            .shadow(color: LockUSceneTokens.Shadow.paper, radius: 3, y: 1)
    }

    private var cheki: some View {
        VStack(spacing: 0) {
            image.aspectRatio(1/1.05, contentMode: .fit)
            Text(handwriting).font(.system(size: 9, weight: .regular).italic()).foregroundStyle(Color(red: 45/255, green: 62/255, blue: 91/255)).rotationEffect(.degrees(-0.7)).frame(height: 23)
        }
        .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 3)
        .background(ImperfectPhotoShape().fill(LockUSceneTokens.Material.paperBase))
        .overlay(PhotoPaperTexture()).shadow(color: .black.opacity(0.16), radius: 6, y: 3)
    }

    private var photoBooth: some View {
        VStack(spacing: 2) { ForEach(0..<3, id: \.self) { _ in image.aspectRatio(4/3, contentMode: .fit) } }
            .padding(3).background(Color(white: 0.08)).shadow(color: .black.opacity(0.17), radius: 3, y: 2)
    }

    private var timestamp: some View {
        Text(memory.createdAt.formatted(.dateTime.month(.twoDigits).day(.twoDigits).year(.twoDigits)) + "\n" + memory.createdAt.formatted(.dateTime.hour().minute()))
            .font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.82)).multilineTextAlignment(.trailing).shadow(color: .black.opacity(0.45), radius: 1)
    }

    private var metadata: some View {
        VStack(spacing: 1) {
            Text(memory.createdAt.formatted(.dateTime.month(.abbreviated).day())).font(.system(size: 10, weight: .medium))
            Text(memory.createdAt.formatted(.dateTime.hour().minute())).font(.system(size: 9, design: .monospaced))
        }.tracking(0.7).foregroundStyle(.white.opacity(0.88)).shadow(color: .black.opacity(0.32), radius: 2, y: 1).transition(.opacity)
    }

    @ViewBuilder private var attachmentView: some View {
        GeometryReader { proxy in
            switch attachment {
            case .none:
                Color.clear
            case .clearTape:
                ImperfectTape()
                    .fill(.white.opacity(0.76))
                    .overlay(TapeSurface(isClear: true))
                    .frame(width: proxy.size.width * 0.34, height: min(11, proxy.size.width * 0.13))
                    .position(tapePosition(in: proxy.size))
                    .rotationEffect(.degrees(-1.6))
            case .maskingTape:
                MaskingTapeView(memoryID: memory.id, paletteIndex: tapePaletteIndex)
                    .frame(width: proxy.size.width * tapeWidthFraction, height: tapeHeight)
                    .position(maskingTapePosition(in: proxy.size))
            case .magnet:
                PhysicalMagnet()
                    .frame(width: 15, height: 15)
                    .position(x: proxy.size.width * 0.74, y: 1)
            }
        }
    }

    private func tapePosition(in size: CGSize) -> CGPoint {
        let checksum = memory.id.uuidString.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % 3 }
        let x: CGFloat = checksum == 0 ? size.width * 0.30 : (checksum == 1 ? size.width * 0.50 : size.width * 0.70)
        return CGPoint(x: x, y: 1)
    }

    private var tapeVariant: Int {
        memory.id.uuidString.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % 3 }
    }

    private var tapeWidthFraction: CGFloat {
        [0.28, 0.35, 0.43][tapeVariant]
    }

    private var tapeHeight: CGFloat { [12, 14.5, 17][tapeVariant] }

    private func maskingTapePosition(in size: CGSize) -> CGPoint {
        switch tapeVariant {
        case 0: CGPoint(x: size.width * 0.50, y: 1)
        case 1: CGPoint(x: size.width * 0.23, y: 3)
        default: CGPoint(x: size.width * 0.77, y: 3)
        }
    }

    private var handwriting: String {
        let checksum = memory.id.uuidString.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % 4 }
        return ["after school ♡", "また行こ", "summer", "8.9 best day!!"][checksum]
    }
}

private struct ImperfectPhotoShape: Shape {
    func path(in r: CGRect) -> Path { Path { p in
        p.move(to: CGPoint(x: 0.7, y: 0)); p.addLine(to: CGPoint(x: r.width - 0.5, y: 0.8)); p.addLine(to: CGPoint(x: r.width, y: r.height - 1)); p.addLine(to: CGPoint(x: 1.2, y: r.height)); p.addQuadCurve(to: CGPoint(x: 0.7, y: 0), control: CGPoint(x: -0.3, y: r.height * 0.55)); p.closeSubpath()
    } }
}

private struct TapeSurface: View {
    let isClear: Bool
    var body: some View {
        ZStack {
            LinearGradient(colors: [.white.opacity(isClear ? 0.30 : 0.10), .clear, .white.opacity(isClear ? 0.16 : 0.05)], startPoint: .top, endPoint: .bottom)
            Ellipse().stroke(.white.opacity(isClear ? 0.16 : 0.07), lineWidth: 0.4).frame(width: 7, height: 3).offset(x: 9, y: 1)
            Rectangle().fill(.black.opacity(0.025)).frame(width: 0.5).rotationEffect(.degrees(8)).offset(x: -6)
        }.allowsHitTesting(false)
    }
}

private struct MaskingTapeView: View {
    let memoryID: UUID
    let paletteIndex: Int

    var body: some View {
        ImperfectTape()
            .fill(tapeColor)
            .overlay {
                TapeSurface(isClear: false)
                Canvas { context, size in
                    for index in 0..<9 {
                        let x = CGFloat((index * 19 + variant * 7) % 47) / 47 * size.width
                        var fiber = Path()
                        fiber.move(to: CGPoint(x: x, y: 1))
                        fiber.addLine(to: CGPoint(x: x + 1, y: size.height - 1))
                        context.stroke(fiber, with: .color(.white.opacity(0.020)), lineWidth: 0.3)
                    }
                }
            }
            .rotationEffect(.degrees(rotation))
            .shadow(color: .black.opacity(0.065), radius: 1.2, x: 0.5, y: 0.7)
            .accessibilityHidden(true)
    }

    private var variant: Int {
        memoryID.uuidString.utf8.reduce(0) { ($0 &* 31 + Int($1)) % 3 }
    }

    private var rotation: Double {
        switch variant {
        case 0: -2
        case 1: -8
        default: 8
        }
    }

    private var tapeColor: Color {
        switch paletteIndex {
        case 0: Color(red: 215/255, green: 232/255, blue: 238/255).opacity(0.76)
        case 1: LockUSceneTokens.Material.warmTape.opacity(0.78)
        default: Color(red: 231/255, green: 210/255, blue: 211/255).opacity(0.70)
        }
    }
}

private struct ImperfectTape: Shape {
    func path(in r: CGRect) -> Path { Path { p in
        p.move(to: CGPoint(x: 1, y: 1)); p.addLine(to: CGPoint(x: r.width - 2, y: 0))
        p.addLine(to: CGPoint(x: r.width, y: r.height - 2)); p.addLine(to: CGPoint(x: r.width - 3, y: r.height))
        p.addLine(to: CGPoint(x: 1, y: r.height - 1)); p.addLine(to: CGPoint(x: 0, y: 3)); p.closeSubpath()
    } }
}

private struct PhysicalMagnet: View {
    var body: some View {
        Circle().fill(RadialGradient(colors: [.white.opacity(0.62), Color(red: 111/255, green: 129/255, blue: 137/255), Color(red: 62/255, green: 72/255, blue: 76/255)], center: .topLeading, startRadius: 1, endRadius: 12))
            .overlay(Circle().stroke(.white.opacity(0.24), lineWidth: 0.7))
            .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
    }
}

struct PolaroidMemoryView: View {
    @EnvironmentObject private var repository: MemoryRepository
    @EnvironmentObject private var appModel: LockUAppModel
    let memory: MemoryRecord

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            appModel.selectedTab = .book
        } label: {
            VStack(spacing: 0) {
                Group {
                    if let image = repository.image(for: memory, purpose: .locker, targetPointSize: CGSize(width: 220, height: 260)) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            LockUDesign.Color.dustBlue.opacity(0.35)
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .clipped()

                Text(memory.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(.caption2).weight(.medium))
                    .foregroundStyle(LockUDesign.Color.ink.opacity(0.82))
                    .lineLimit(1)
                    .padding(.vertical, 6)
            }
            .padding(6)
            .background(LockUDesign.Color.notebookPaper)
            .overlay {
                PhotoPaperTexture()
            }
            .overlay(alignment: .top) {
                ImperfectTape()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.38), indexedTapeColor, .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 13)
                    .offset(y: -8)
                    .rotationEffect(.degrees(1))
                    .shadow(color: .black.opacity(0.16), radius: 2, y: 2)
            }
            .overlay(alignment: .bottomTrailing) {
                CurledPhotoCorner()
                    .frame(width: 12, height: 12)
            }
            .shadow(color: .black.opacity(0.34), radius: 3, y: 2)
            .shadow(color: LockUDesign.Color.summerShadow.opacity(0.22), radius: 15, y: 8)
        }
        .buttonStyle(LockerPressStyle())
        .accessibilityLabel("\(memory.createdAt.formatted(date: .long, time: .omitted))の思い出")
        .accessibilityHint("Opens Memory Book")
    }

    private var indexedTapeColor: Color {
        memory.id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }.isMultiple(of: 2)
            ? LockUDesign.Color.lockerSummerBlueLight.opacity(0.58)
            : LockUDesign.Color.notebookPaper.opacity(0.72)
    }
}

private struct PhotoPaperTexture: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<32 {
                let x = CGFloat((index * 43) % 97) / 97 * size.width
                let y = CGFloat((index * 67) % 89) / 89 * size.height
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 0.65, height: 0.65)),
                    with: .color(index.isMultiple(of: 2) ? .white.opacity(0.18) : .black.opacity(0.035))
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct CurledPhotoCorner: View {
    var body: some View {
        Triangle()
            .fill(
                LinearGradient(
                    colors: [
                        LockUDesign.Color.fadedPaper,
                        .white.opacity(0.92),
                        LockUDesign.Color.summerShadow.opacity(0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: .black.opacity(0.2), radius: 2, x: -1, y: -1)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct LockerWeatherNoteView: View {
    let memory: MemoryRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("今日の思い出")
                .font(.system(size: 8, weight: .bold))
            if let weather = memory.weather {
                Label(temperature(weather), systemImage: weatherSymbol(weather.summary))
                    .font(.caption.weight(.semibold))
                Text(weather.summary)
                    .font(.caption2)
                    .lineLimit(1)
            } else {
                Label(
                    memory.createdAt.formatted(.dateTime.month(.abbreviated).day()),
                    systemImage: "calendar"
                )
                .font(.caption2.weight(.medium))
            }
        }
        .foregroundStyle(LockUDesign.Color.ink)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LockUDesign.Color.paperCream.opacity(0.94), in: RoundedRectangle(cornerRadius: 3))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        .accessibilityElement(children: .combine)
    }

    private func temperature(_ weather: WeatherSnapshot) -> String {
        guard let temperature = weather.temperatureCelsius else { return weather.summary }
        return "\(Int(temperature.rounded()))°C"
    }

    private func weatherSymbol(_ summary: String) -> String {
        let lowercased = summary.lowercased()
        if lowercased.contains("rain") { return "cloud.rain.fill" }
        if lowercased.contains("cloud") { return "cloud.fill" }
        if lowercased.contains("snow") { return "snowflake" }
        return "sun.max.fill"
    }
}

struct LockerMemoCardView: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(.caption).weight(.medium).italic())
            .foregroundStyle(LockUDesign.Color.ink)
            .minimumScaleFactor(0.75)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MemoPaperShape().fill(Color(red: 243/255, green: 240/255, blue: 231/255)))
            .shadow(color: .black.opacity(0.12), radius: 2, x: 1, y: 1.5)
    }
}

private struct MemoPaperShape: Shape {
    func path(in r: CGRect) -> Path { Path { p in p.move(to: CGPoint(x: 1, y: 0)); p.addLine(to: CGPoint(x: r.width, y: 1)); p.addLine(to: CGPoint(x: r.width-1, y: r.height-1)); p.addLine(to: CGPoint(x: r.width*0.72, y: r.height)); p.addLine(to: CGPoint(x: r.width*0.45, y: r.height-0.6)); p.addLine(to: CGPoint(x: 0, y: r.height)); p.closeSubpath() } }
}

struct LockerEmptyStateView: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 233/255, green: 230/255, blue: 218/255))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 23, weight: .regular))
                            .opacity(0.50)
                    }
                Text("今日の思い出を残そう")
                    .font(.system(size: 12, weight: .regular))
                    .multilineTextAlignment(.center)
                    .frame(height: 28)
            }
            .foregroundStyle(LockUDesign.Color.ink.opacity(0.62))
            .padding(7)
            .padding(.bottom, 14)
            .background(Color(red: 245/255, green: 242/255, blue: 232/255), in: RoundedRectangle(cornerRadius: 1.5))
            .overlay(alignment: .top) {
                ImperfectTape()
                    .fill(Color(red: 243/255, green: 240/255, blue: 223/255).opacity(0.65))
                    .frame(width: 46, height: 10)
                    .offset(y: -6)
                    .rotationEffect(.degrees(0.7))
            }
            .rotationEffect(.degrees(0.8))
            .shadow(color: .black.opacity(0.17), radius: 3, x: 1, y: 2)
        }
        .buttonStyle(LockerPressStyle())
        .accessibilityLabel("今日の思い出を撮影")
        .accessibilityHint("Cameraタブを開きます")
    }
}

struct LockerPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(LockUDesign.Motion.quick, value: configuration.isPressed)
    }
}
