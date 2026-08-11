import SwiftUI
import UIKit

struct LockerMemoryBoardView: View {
    @EnvironmentObject private var memoryRepository: MemoryRepository
    @EnvironmentObject private var appModel: LockUAppModel
    @EnvironmentObject private var settingsRepository: LockerSettingsRepository
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var selectedMemoryID: UUID?
    let appearanceOverride: LockerAppearanceSettings?

    init(appearanceOverride: LockerAppearanceSettings? = nil) {
        self.appearanceOverride = appearanceOverride
    }

    private var appearance: LockerAppearanceSettings {
        appearanceOverride ?? settingsRepository.settings.appearance
    }

    private var recentMemories: [MemoryRecord] {
        let sorted = memoryRepository.memories.sorted { $0.createdAt > $1.createdAt }
        guard let featuredID = appearance.featuredVideoMemoryID,
              let featured = sorted.first(where: { $0.id == featuredID }) else {
            return Array(sorted.prefix(8))
        }
        return [featured] + Array(sorted.filter { $0.id != featured.id }.prefix(7))
    }

    var body: some View {
        GeometryReader { proxy in
            let placements = DeterministicMemoryWallPlacementEngine().layout(
                memories: recentMemories,
                containerSize: proxy.size,
                appearance: appearance,
                date: .now
            )
            ZStack {
                boardSurface

                if recentMemories.isEmpty {
                    Color.clear
                } else {
                    ForEach(placements) { placement in
                        Group {
                            if placement.isLiving {
                                LivingMemoryView(memory: placement.memory, frameStyle: placement.frameStyle, filterStyle: placement.filterStyle, filterAdjustment: placement.filterAdjustment, printAspectRatio: placement.printAspectRatio)
                            } else {
                                MemoryPhysicalView(
                                    memory: placement.memory,
                                    role: memoryRole(for: placement.memory, index: placement.index),
                                    attachment: placement.tapeStyle,
                                    frameStyle: placement.frameStyle,
                                    filterStyle: placement.filterStyle,
                                    filterAdjustment: placement.filterAdjustment,
                                    printAspectRatio: placement.printAspectRatio,
                                    isSelected: selectedMemoryID == placement.id,
                                    onSelect: { selectedMemoryID = selectedMemoryID == placement.id ? nil : placement.id }
                                )
                            }
                        }
                            .frame(width: placement.width)
                            .rotationEffect(.degrees(placement.rotation))
                            .position(placement.position)
                            .zIndex(selectedMemoryID == placement.id ? LockUSceneTokens.Layer.memory + 40 : LockUSceneTokens.Layer.memory + placement.zIndex)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 5)
                            .animation(
                                reduceMotion ? nil : .easeOut(duration: 0.35).delay(Double(min(placement.index, 8)) * 0.035),
                                value: appeared
                            )
                            .transition(.scale(scale: 0.98).combined(with: .opacity))
                    }
                }

                LockerDecorationLayer()
                    .zIndex(20)
            }
            .padding(.horizontal, max(4, proxy.size.width * 0.025))
            .padding(.vertical, 5)
            .onAppear { appeared = true }
        }
    }

    private var boardSurface: some View {
        Color.clear
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
    let printAspectRatio: CGFloat
    let isLiving: Bool

    var id: UUID { memory.id }
}

private struct DeterministicMemoryWallPlacementEngine {
    private let anchors: [CGPoint] = [
        CGPoint(x: 0.51, y: 0.45),
        CGPoint(x: 0.22, y: 0.15), CGPoint(x: 0.73, y: 0.18),
        CGPoint(x: 0.18, y: 0.40), CGPoint(x: 0.80, y: 0.43),
        CGPoint(x: 0.23, y: 0.72), CGPoint(x: 0.43, y: 0.77), CGPoint(x: 0.78, y: 0.72)
    ]
    private let widthFractions: [CGFloat] = [0.294, 0.1995, 0.2205, 0.189, 0.21, 0.1932, 0.2268, 0.2016]
    private let rotationPresets: [Double] = [0.4, -3.0, 2.0, -1.5, 3.0, -2.0, 1.0, -2.5]
    private let aspectRatios: [CGFloat] = [0.82, 0.82, 0.72, 1.0, 0.82, 0.96, 0.74, 0.88]

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
            case 6, 8: attachment = .clearTape
            case 7: attachment = .maskingTape
            case 9: attachment = .magnet
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
                rotation: min(max(rotationPresets[presetIndex] + daily.rotationOffset, -4), 4),
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
        case .balanced, .casual: sequence = [.polaroid, .thinWhite, .borderless, .polaroid]
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
        let photoIDs = Array(memories.dropFirst().prefix(7).map(\.id))
        let affectedCount = min(photoIDs.count, generator.nextInt(in: 1...2))
        var available = photoIDs
        var selected: [UUID] = []
        for _ in 0..<affectedCount where !available.isEmpty {
            selected.append(available.remove(at: generator.nextInt(in: 0...(available.count - 1))))
        }

        let frameOptions: [LockerFrameStyle] = [.polaroid, .thinWhite, .borderless]
        var adjustments: [UUID: DailyLockerMemoryAdjustment] = [:]
        for (offset, id) in selected.enumerated() {
            let x = generator.nextDouble(in: -8...8)
            let y = generator.nextDouble(in: -8...8)
            let rotationMagnitude = generator.nextDouble(in: 0.5...1.5)
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

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            appModel.selectedTab = .book
        } label: {
            PolaroidPrint(memory: memory, frameStyle: frameStyle, filterStyle: filterStyle, filterAdjustment: filterAdjustment, isFeatured: true, printAspectRatio: printAspectRatio)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.90))
                        .frame(width: 19, height: 19)
                        .background(.black.opacity(0.32), in: Circle())
                        .padding(7)
                }
                .shadow(color: .black.opacity(0.08), radius: 3.5, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Latest memory from \(memory.createdAt.formatted(date: .abbreviated, time: .shortened))")
    }
}

private struct PolaroidPrint: View {
    @EnvironmentObject private var repository: MemoryRepository
    let memory: MemoryRecord
    let frameStyle: LockerFrameStyle
    let filterStyle: LockerFilterStyle
    let filterAdjustment: DailyLockerFilterAdjustment
    let isFeatured: Bool
    let printAspectRatio: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let sideMargin = proxy.size.width * sideMarginFraction
            let topMargin = proxy.size.height * topMarginFraction
            let bottomMargin = proxy.size.height * bottomMarginFraction
            let photoHeight = max(0, proxy.size.height - topMargin - bottomMargin)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(paperColor)
                    .overlay {
                        LinearGradient(
                            colors: [LockUSceneTokens.Material.paperHighlight.opacity(0.22), .clear, LockUSceneTokens.Material.paperShadow.opacity(0.07)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 2.5))
                    }

                Group {
                    if let image = repository.image(for: memory) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color(white: 0.52)
                            .overlay(Image(systemName: "photo").foregroundStyle(.white.opacity(0.65)))
                    }
                }
                .modifier(LockerMemoryFilterModifier(style: filterStyle, adjustment: filterAdjustment))
                .frame(width: proxy.size.width - sideMargin * 2, height: photoHeight)
                .clipped()
                .offset(x: sideMargin, y: topMargin)

                if frameStyle == .polaroid || frameStyle == .mixed {
                    Text(memory.createdAt.formatted(.dateTime.month(.twoDigits).day(.twoDigits).year(.twoDigits)))
                        .font(.system(size: max(6, proxy.size.width * 0.072), weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(red: 99/255, green: 115/255, blue: 124/255).opacity(0.80))
                        .lineLimit(1)
                        .frame(width: proxy.size.width - sideMargin * 2, alignment: .leading)
                        .offset(x: sideMargin, y: proxy.size.height - bottomMargin * 0.64)
                }
            }
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
    private var paperColor: Color {
        frameStyle == .borderless ? .clear : LockUSceneTokens.Material.paperBase
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
    @EnvironmentObject private var appModel: LockUAppModel
    let memory: MemoryRecord
    let role: MemoryVisualRole
    let attachment: MemoryAttachment
    let frameStyle: LockerFrameStyle
    let filterStyle: LockerFilterStyle
    let filterAdjustment: DailyLockerFilterAdjustment
    let isSelected: Bool
    let onSelect: () -> Void

    private var depth: MemoryDepthLevel {
        switch role { case .cheki: return .paper; case .cutout: return .raisedSticker; default: return .flatPhoto }
    }

    var body: some View {
        PolaroidPrint(memory: memory, frameStyle: frameStyle, filterStyle: filterStyle, filterAdjustment: filterAdjustment, isFeatured: false, printAspectRatio: printAspectRatio)
        .overlay(alignment: .bottomLeading) {
            if frameStyle == .thinWhite || frameStyle == .borderless {
                Text(memory.createdAt.formatted(.dateTime.month(.twoDigits).day(.twoDigits)))
                    .font(.system(size: 6.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.88))
                    .shadow(color: .black.opacity(0.42), radius: 1)
                    .padding(4)
            }
        }
        .overlay(alignment: .top) { attachmentView }
        .shadow(color: .black.opacity(0.08), radius: 3.5, y: 2)
        .contentShape(Rectangle())
        .onTapGesture { UIImpactFeedbackGenerator(style: .light).impactOccurred(); onSelect() }
        .onTapGesture(count: 2) { appModel.selectedTab = .book }
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
            if let image = repository.image(for: memory) { Image(uiImage: image).resizable().scaledToFill() }
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
                ImperfectTape()
                    .fill(Color(red: 216/255, green: 234/255, blue: 244/255).opacity(0.82))
                    .overlay(TapeSurface(isClear: false))
                    .frame(width: proxy.size.width * 0.38, height: min(12, proxy.size.width * 0.14))
                    .position(tapePosition(in: proxy.size))
                    .rotationEffect(.degrees(1.8))
                    .shadow(color: .black.opacity(0.06), radius: 0.8, y: 0.6)
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
        return CGPoint(x: x, y: 0)
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
                    if let image = repository.image(for: memory) {
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
        .accessibilityLabel("Memory from \(memory.createdAt.formatted(date: .long, time: .omitted))")
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
            Text("Today’s memory")
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
