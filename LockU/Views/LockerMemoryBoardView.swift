import SwiftUI
import UIKit

struct LockerMemoryBoardView: View {
    @EnvironmentObject private var memoryRepository: MemoryRepository
    @EnvironmentObject private var appModel: LockUAppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var recentMemories: [MemoryRecord] {
        Array(memoryRepository.memories.sorted { $0.createdAt > $1.createdAt }.prefix(3))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                boardSurface

                LockerMemoCardView(text: "Be yourself", tint: LockUDesign.Color.mutedLavender)
                    .frame(width: proxy.size.width * 0.25)
                    .position(x: proxy.size.width * 0.16, y: proxy.size.height * 0.19)
                    .rotationEffect(.degrees(-3))

                if let newest = recentMemories.first {
                    LockerWeatherNoteView(memory: newest)
                        .frame(width: proxy.size.width * 0.28)
                        .position(x: proxy.size.width * 0.83, y: proxy.size.height * 0.19)
                        .rotationEffect(.degrees(2))
                }

                if recentMemories.isEmpty {
                    LockerEmptyStateView {
                        appModel.selectedTab = .camera
                    }
                    .frame(width: min(proxy.size.width * 0.48, 205))
                    .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.55)
                } else {
                    ForEach(Array(recentMemories.enumerated()), id: \.element.id) { index, memory in
                        Group {
                            if memory.isSubjectCutout ?? false {
                                CutoutMemoryStickerView(memory: memory)
                            } else {
                                PolaroidMemoryView(memory: memory)
                            }
                        }
                            .frame(width: photoWidth(for: index, in: proxy.size))
                            .rotationEffect(.degrees(stableRotation(for: memory.id, index: index)))
                            .position(position(for: index, in: proxy.size))
                            .zIndex(index == 0 ? 6 : 4 - Double(index))
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
        RoundedRectangle(cornerRadius: 3)
            .fill(.black.opacity(0.07))
            .overlay {
                LinearGradient(
                    colors: [.white.opacity(0.035), .clear, .black.opacity(0.07)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(0.05)))
    }

    private func photoWidth(for index: Int, in size: CGSize) -> CGFloat {
        let base = min(size.width, 470)
        return index == 0 ? base * 0.39 : base * 0.28
    }

    private func position(for index: Int, in size: CGSize) -> CGPoint {
        switch index {
        case 0:
            return CGPoint(x: size.width * 0.51, y: size.height * 0.46)
        case 1:
            return CGPoint(x: size.width * 0.25, y: size.height * 0.71)
        default:
            return CGPoint(x: size.width * 0.78, y: size.height * 0.72)
        }
    }

    private func stableRotation(for id: UUID, index: Int) -> Double {
        let checksum = id.uuidString.unicodeScalars.reduce(0) {
            ($0 + Int($1.value)) % 7
        }
        let magnitude = 1.0 + Double(checksum % 4) * 0.7
        return index == 1 || checksum.isMultiple(of: 2) ? -magnitude : magnitude
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
                    .font(.system(.caption2, design: .rounded).weight(.medium))
                    .foregroundStyle(LockUDesign.Color.ink.opacity(0.82))
                    .lineLimit(1)
                    .padding(.vertical, 6)
            }
            .padding(6)
            .background(LockUDesign.Color.paperCream)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(LockUDesign.Color.paperCream.opacity(0.72))
                    .frame(width: 42, height: 12)
                    .offset(y: -8)
                    .rotationEffect(.degrees(1))
            }
            .shadow(color: .black.opacity(0.3), radius: 5, x: 2, y: 4)
        }
        .buttonStyle(LockerPressStyle())
        .accessibilityLabel("Memory from \(memory.createdAt.formatted(date: .long, time: .omitted))")
        .accessibilityHint("Opens Memory Book")
    }
}

struct LockerWeatherNoteView: View {
    let memory: MemoryRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("TODAY'S MEMORY")
                .font(.system(size: 8, weight: .bold, design: .rounded))
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
        .shadow(color: .black.opacity(0.16), radius: 3, y: 2)
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
            .font(.system(.caption, design: .rounded).weight(.medium).italic())
            .foregroundStyle(LockUDesign.Color.ink)
            .minimumScaleFactor(0.75)
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(tint.opacity(0.92), in: RoundedRectangle(cornerRadius: 3))
            .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
    }
}

struct LockerEmptyStateView: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.black.opacity(0.045))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                    }
                Text("今日の思い出を残そう")
                    .font(.caption.weight(.medium))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(LockUDesign.Color.ink.opacity(0.7))
            .padding(7)
            .background(LockUDesign.Color.paperCream.opacity(0.9))
            .overlay(alignment: .top) {
                Capsule()
                    .fill(LockUDesign.Color.paperCream.opacity(0.82))
                    .frame(width: 44, height: 12)
                    .offset(y: -8)
            }
            .rotationEffect(.degrees(2))
            .shadow(color: .black.opacity(0.22), radius: 5, y: 3)
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
