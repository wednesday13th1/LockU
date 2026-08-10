import SwiftUI
import UIKit

struct LockerMemoryBoardView: View {
    @EnvironmentObject private var memoryRepository: MemoryRepository
    @EnvironmentObject private var appModel: LockUAppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var selectedMemoryID: UUID?

    private var recentMemories: [MemoryRecord] {
        Array(memoryRepository.memories.sorted { $0.createdAt > $1.createdAt }.prefix(5))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                boardSurface

                if recentMemories.isEmpty {
                    LockerMemoCardView(text: "a day to remember", tint: LockUDesign.Color.notebookPaper)
                        .frame(width: min(120, proxy.size.width * 0.39), height: 56)
                        .position(x: proxy.size.width * 0.25, y: proxy.size.height * 0.18)
                        .rotationEffect(.degrees(-1.6))
                    LockerEmptyStateView {
                        appModel.selectedTab = .camera
                    }
                    .frame(width: min(proxy.size.width * 0.43, 158), height: 190)
                    .position(x: proxy.size.width * 0.53, y: proxy.size.height * 0.47)
                } else {
                    ForEach(Array(recentMemories.enumerated()), id: \.element.id) { index, memory in
                        MemoryPhysicalView(
                            memory: memory,
                            role: memoryRole(for: memory, index: index),
                            attachment: attachment(for: memory, index: index),
                            isSelected: selectedMemoryID == memory.id,
                            onSelect: { selectedMemoryID = selectedMemoryID == memory.id ? nil : memory.id }
                        )
                            .frame(width: photoWidth(for: index, in: proxy.size))
                            .rotationEffect(.degrees(stableRotation(for: memory.id, index: index)))
                            .position(position(for: index, in: proxy.size))
                            .zIndex(selectedMemoryID == memory.id ? 30 : (index == 0 ? 6 : 4 - Double(index)))
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 7)
                            .animation(
                                reduceMotion ? nil : .easeOut(duration: 0.38).delay(Double(index) * 0.08),
                                value: appeared
                            )
                            .transition(.scale(scale: 0.85).combined(with: .opacity))
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

    private func photoWidth(for index: Int, in size: CGSize) -> CGFloat {
        let base = min(size.width, 470)
        switch index {
        case 0: return min(base * 0.50, 196)
        case 1, 2: return base * 0.29
        default: return base * 0.22
        }
    }

    private func position(for index: Int, in size: CGSize) -> CGPoint {
        switch index {
        case 0:
            return CGPoint(x: size.width * 0.47, y: size.height * 0.47)
        case 1:
            return CGPoint(x: size.width * 0.22, y: size.height * 0.28)
        case 2:
            return CGPoint(x: size.width * 0.78, y: size.height * 0.30)
        case 3:
            return CGPoint(x: size.width * 0.25, y: size.height * 0.75)
        default:
            return CGPoint(x: size.width * 0.76, y: size.height * 0.73)
        }
    }

    private func stableRotation(for id: UUID, index: Int) -> Double {
        let checksum = id.uuidString.unicodeScalars.reduce(0) {
            ($0 + Int($1.value)) % 7
        }
        let prescribedRotations = [0.6, -1.7, 1.2, -3.2, 2.4]
        let magnitude = prescribedRotations[index % prescribedRotations.count]
        return checksum.isMultiple(of: 2) ? magnitude : -magnitude * 0.72
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

    private func attachment(for memory: MemoryRecord, index: Int) -> MemoryAttachment {
        let value = memory.id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 20
        if value < 8 { return .none }
        if value < 13 { return .maskingTape }
        if value < 17 { return .clearTape }
        return .magnet
    }
}

enum MemoryVisualRole { case hero, cheki, digicam, cutout, mini }
enum MemoryAttachment { case none, clearTape, maskingTape, magnet }

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
        Group {
            if role == .cutout {
                CutoutMemoryStickerView(memory: memory)
            } else {
                physicalPhoto
            }
        }
        .overlay(alignment: .top) { attachmentView }
        .overlay(alignment: .bottom) { if isSelected { metadata.offset(y: 28) } }
        .scaleEffect(drag == .zero ? (isSelected ? 1.025 : 1) : 1.03)
        .offset(drag)
        .shadow(color: .black.opacity(drag == .zero ? depth.shadow.opacity * 0.22 : 0.16), radius: drag == .zero ? depth.shadow.radius * 0.35 : 7, y: drag == .zero ? depth.shadow.y : 5)
        .contentShape(Rectangle())
        .onTapGesture { UIImpactFeedbackGenerator(style: .light).impactOccurred(); onSelect() }
        .onTapGesture(count: 2) { appModel.selectedTab = .book }
        .gesture(DragGesture(minimumDistance: 3).updating($drag) { value, state, _ in state = value.translation })
        .animation(.easeOut(duration: 0.19), value: isSelected)
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
            .clipShape(RoundedRectangle(cornerRadius: 1))
            .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
    }

    private var cheki: some View {
        VStack(spacing: 0) {
            image.aspectRatio(1/1.05, contentMode: .fit)
            Text(handwriting).font(.system(size: 9, weight: .regular).italic()).foregroundStyle(Color(red: 45/255, green: 62/255, blue: 91/255)).rotationEffect(.degrees(-0.7)).frame(height: 23)
        }
        .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 3)
        .background(Color(red: 247/255, green: 244/255, blue: 234/255), in: RoundedRectangle(cornerRadius: 2))
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
        switch attachment {
        case .none: EmptyView()
        case .clearTape: ImperfectTape().fill(.white.opacity(0.48)).frame(width: 42, height: 13).overlay(LinearGradient(colors: [.white.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom)).offset(x: 11, y: -7).rotationEffect(.degrees(-2))
        case .maskingTape: ImperfectTape().fill(Color(red: 224/255, green: 214/255, blue: 183/255).opacity(0.72)).frame(width: 46, height: 13).offset(x: -8, y: -7).rotationEffect(.degrees(2.4)).shadow(color: .black.opacity(0.12), radius: 1, y: 1)
        case .magnet: PhysicalMagnet().frame(width: 20, height: 20).offset(x: 16, y: -5)
        }
    }

    private var handwriting: String {
        let checksum = memory.id.uuidString.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % 4 }
        return ["after school ♡", "また行こ", "summer", "8.9 best day!!"][checksum]
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
            .shadow(color: .black.opacity(0.25), radius: 2, x: 1, y: 2)
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
            .frame(maxWidth: .infinity)
            .background(Color(red: 243/255, green: 240/255, blue: 231/255), in: RoundedRectangle(cornerRadius: 2))
            .shadow(color: .black.opacity(0.12), radius: 2, x: 1, y: 1.5)
    }
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
