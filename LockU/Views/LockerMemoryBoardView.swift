import SwiftUI
import UIKit

struct LockerMemoryBoardView: View {
    @EnvironmentObject private var memoryRepository: MemoryRepository
    @EnvironmentObject private var appModel: LockUAppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var selectedMemoryID: UUID?

    private var recentMemories: [MemoryRecord] {
        Array(memoryRepository.memories.sorted { $0.createdAt > $1.createdAt }.prefix(10))
    }

    var body: some View {
        GeometryReader { proxy in
            let placements = DeterministicMemoryWallPlacementEngine().layout(memories: recentMemories, containerSize: proxy.size)
            ZStack {
                boardSurface

                if recentMemories.isEmpty {
                    Color.clear
                } else {
                    ForEach(placements) { placement in
                        Group {
                            if placement.isLiving {
                                LivingMemoryView(memory: placement.memory)
                            } else {
                                MemoryPhysicalView(
                                    memory: placement.memory,
                                    role: memoryRole(for: placement.memory, index: placement.index),
                                    attachment: placement.tapeStyle,
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
    let isLiving: Bool

    var id: UUID { memory.id }
}

private struct DeterministicMemoryWallPlacementEngine {
    private let anchors: [CGPoint] = [
        CGPoint(x: 0.50, y: 0.49),
        CGPoint(x: 0.18, y: 0.15), CGPoint(x: 0.49, y: 0.14), CGPoint(x: 0.81, y: 0.17),
        CGPoint(x: 0.13, y: 0.43), CGPoint(x: 0.87, y: 0.43),
        CGPoint(x: 0.18, y: 0.77), CGPoint(x: 0.50, y: 0.82), CGPoint(x: 0.82, y: 0.77),
        CGPoint(x: 0.88, y: 0.67)
    ]
    private let widthFractions: [CGFloat] = [0.40, 0.22, 0.22, 0.18, 0.22, 0.26, 0.22, 0.18, 0.22, 0.22]
    private let rotationPresets: [Double] = [-0.4, -2.0, 1.2, 2.8, -1.4, 0.6, -3.0, 1.8, -0.8, 2.1]
    private let looseOffsets: [CGSize] = [
        .zero, CGSize(width: -5, height: 5), CGSize(width: 4, height: -4), CGSize(width: 6, height: 8),
        CGSize(width: -4, height: -7), CGSize(width: 5, height: 4), CGSize(width: -7, height: -5),
        CGSize(width: 4, height: 7), CGSize(width: 7, height: -4), CGSize(width: -5, height: 6)
    ]

    func layout(memories: [MemoryRecord], containerSize: CGSize) -> [MemoryWallPlacement] {
        let density = MemoryDensity(count: memories.count)
        guard density != .empty, containerSize.width > 0, containerSize.height > 0 else { return [] }

        return memories.enumerated().map { index, memory in
            let presetIndex = index % anchors.count
            let anchor = anchors[presetIndex]
            let looseOffset = looseOffsets[presetIndex]
            let width = containerSize.width * widthFractions[presetIndex]
            let halfX = width / containerSize.width / 2 + 0.012
            let estimatedHeight = width / 0.82
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
                    x: min(max(anchor.x + looseOffset.width / containerSize.width, halfX), 1 - halfX) * containerSize.width,
                    y: min(max(anchor.y + looseOffset.height / containerSize.height, halfY), 1 - halfY) * containerSize.height
                ),
                width: width,
                rotation: rotationPresets[presetIndex],
                zIndex: index == 0 ? 30 : Double(20 + (index % 7)),
                tapeStyle: index == 0 ? .none : attachment,
                isLiving: index == 0
            )
        }
    }
}

private struct LivingMemoryView: View {
    @EnvironmentObject private var appModel: LockUAppModel
    let memory: MemoryRecord

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            appModel.selectedTab = .book
        } label: {
            PolaroidPrint(memory: memory, bottomMarginFraction: 0.19, allowsAnnotation: false)
                .shadow(color: .black.opacity(0.13), radius: 3, y: 1.5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Latest memory from \(memory.createdAt.formatted(date: .abbreviated, time: .shortened))")
    }
}

private struct PolaroidPrint: View {
    @EnvironmentObject private var repository: MemoryRepository
    let memory: MemoryRecord
    let bottomMarginFraction: CGFloat
    let allowsAnnotation: Bool

    var body: some View {
        GeometryReader { proxy in
            let sideMargin = proxy.size.width * 0.055
            let topMargin = proxy.size.height * 0.055
            let bottomMargin = proxy.size.height * bottomMarginFraction
            let photoHeight = max(0, proxy.size.height - topMargin - bottomMargin)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(LockUSceneTokens.Material.paperBase)
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
                .frame(width: proxy.size.width - sideMargin * 2, height: photoHeight)
                .clipped()
                .offset(x: sideMargin, y: topMargin)

                if showsAnnotation {
                    Text(annotation)
                        .font(.system(size: max(7, proxy.size.width * 0.09), weight: .regular).italic())
                        .foregroundStyle(Color(red: 99/255, green: 135/255, blue: 160/255).opacity(0.86))
                        .lineLimit(1)
                        .rotationEffect(.degrees(-0.6))
                        .frame(width: proxy.size.width - sideMargin * 2, alignment: .leading)
                        .offset(x: sideMargin, y: proxy.size.height - bottomMargin * 0.68)
                }
            }
        }
        .aspectRatio(0.82, contentMode: .fit)
    }

    private var showsAnnotation: Bool {
        allowsAnnotation && checksum.isMultiple(of: 3)
    }

    private var annotation: String {
        ["8.10", "after school", ":)", "summer"][checksum % 4]
    }

    private var checksum: Int {
        memory.id.uuidString.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % 997 }
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
    let isSelected: Bool
    let onSelect: () -> Void
    @GestureState private var drag: CGSize = .zero

    private var depth: MemoryDepthLevel {
        switch role { case .cheki: return .paper; case .cutout: return .raisedSticker; default: return .flatPhoto }
    }

    var body: some View {
        PolaroidPrint(memory: memory, bottomMarginFraction: 0.17, allowsAnnotation: true)
        .overlay(alignment: .top) { attachmentView }
        .scaleEffect(drag == .zero ? 1 : 1.01)
        .offset(drag)
        .shadow(color: .black.opacity(drag == .zero ? 0.12 : 0.14), radius: drag == .zero ? 2.5 : 4, y: drag == .zero ? 1.25 : 1.5)
        .contentShape(Rectangle())
        .onTapGesture { UIImpactFeedbackGenerator(style: .light).impactOccurred(); onSelect() }
        .onTapGesture(count: 2) { appModel.selectedTab = .book }
        .gesture(DragGesture(minimumDistance: 3).updating($drag) { value, state, _ in state = value.translation })
        .animation(.easeOut(duration: 0.20), value: drag)
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
