import SwiftUI
import UIKit

struct LockerBottomShelfView: View {
    var body: some View {
        GeometryReader { proxy in
            let shelfTopY = proxy.size.height - 21

            PhysicalMetalShelf()
                .frame(width: proxy.size.width, height: 21)
                .position(x: proxy.size.width * 0.5, y: shelfTopY + 10.5)
                .accessibilityHidden(true)
        }
    }
}

struct LockerGrowthDecorationLayer: View {
    @EnvironmentObject private var memoryRepository: MemoryRepository
    @EnvironmentObject private var settingsRepository: LockerSettingsRepository
    @EnvironmentObject private var resurfacingCoordinator: LockerResurfacingCoordinator
    @State private var growthState = LockerGrowthState.fresh

    var body: some View {
        GeometryReader { proxy in
            let configuration = LockerItemThemeConfiguration.theme(
                settingsRepository.settings.appearance.itemTheme
            )
            ZStack(alignment: .topLeading) {
                ForEach(growthState.decorations) { decoration in
                    growthTrace(
                        decoration,
                        configuration: configuration,
                        containerSize: proxy.size
                    )
                    .position(
                        x: proxy.size.width * CGFloat(decoration.normalizedPosition.x),
                        y: proxy.size.height * CGFloat(decoration.normalizedPosition.y)
                    )
                    .rotationEffect(.degrees(decoration.rotation))
                    .scaleEffect(decoration.scale)
                }
            }
        }
        .onAppear(perform: refreshGrowthState)
        .onChange(of: memoryRepository.memories.count) { _, _ in refreshGrowthState() }
    }

    @ViewBuilder
    private func growthTrace(
        _ decoration: LockerGrowthDecoration,
        configuration: LockerItemThemeConfiguration,
        containerSize: CGSize
    ) -> some View {
        let trace = LockerGrowthTraceView(
            decoration: decoration,
            configuration: configuration,
            containerSize: containerSize,
            reflectionMetadata: decoration.role == .resurfacing
                ? resurfacingCoordinator.candidateReflectionTrace
                : nil
        )
        trace
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }

    private func refreshGrowthState() {
        let next = LockerGrowthGenerator().state(memories: memoryRepository.memories)
        guard next != growthState else { return }
        growthState = next
    }
}

private struct LockerGrowthTraceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct LockerGrowthTraceView: View {
    let decoration: LockerGrowthDecoration
    let configuration: LockerItemThemeConfiguration
    let containerSize: CGSize
    let reflectionMetadata: MemoryReflectionTraceMetadata?

    private var palette: LockerItemPalette { configuration.palette }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            traceContent
            if let reflectionMetadata {
                ReflectionTraceView(
                    metadata: reflectionMetadata,
                    configuration: configuration,
                    referenceSize: traceReferenceSize
                )
            }
        }
    }

    private var traceReferenceSize: CGSize {
        switch decoration.type {
        case .miniPhoto: CGSize(width: containerSize.width * 0.115, height: containerSize.width * 0.135)
        case .memo: CGSize(width: containerSize.width * 0.10, height: containerSize.width * 0.075)
        default: CGSize(width: 44, height: 44)
        }
    }

    @ViewBuilder
    private var traceContent: some View {
        switch decoration.type {
        case .tape:
            Rectangle()
                .fill(palette.primary.opacity(0.42))
                .frame(width: containerSize.width * 0.105, height: max(6, containerSize.width * 0.022))
                .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.14)).frame(height: 0.6) }
        case .sticker:
            Text(configuration.minorMark)
                .font(.system(size: max(9, containerSize.width * 0.045), weight: .regular, design: .rounded))
                .foregroundStyle(palette.accent.opacity(0.48))
                .padding(2)
                .background(palette.surface.opacity(0.30), in: Circle())
        case .miniPhoto:
            GrowthMiniPhoto(configuration: configuration)
                .frame(width: containerSize.width * 0.115, height: containerSize.width * 0.135)
        case .memo:
            VStack(spacing: 2) {
                Text("remember")
                Rectangle().fill(palette.dark.opacity(0.13)).frame(width: 18, height: 0.6)
                Rectangle().fill(palette.dark.opacity(0.10)).frame(width: 13, height: 0.6)
            }
            .font(.system(size: 4.5, weight: .regular, design: .serif))
            .foregroundStyle(palette.dark.opacity(0.42))
            .frame(width: containerSize.width * 0.10, height: containerSize.width * 0.075)
            .background(palette.surface.opacity(0.66))
        case .wear:
            GrowthShelfWear(color: palette.dark)
                .frame(width: containerSize.width * 0.14, height: 8)
        case .tag:
            EmptyView()
        }
    }
}

private struct ReflectionTraceView: View {
    let metadata: MemoryReflectionTraceMetadata
    let configuration: LockerItemThemeConfiguration
    let referenceSize: CGSize

    private var palette: LockerItemPalette { configuration.palette }

    @ViewBuilder
    var body: some View {
        switch metadata.traceStyle {
        case .dateTape:
            Text(metadata.firstReflectedAt.formatted(.dateTime.month(.twoDigits).day(.twoDigits)))
                .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.dark.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(width: max(22, referenceSize.width * 0.48), height: 10)
                .background(palette.surface.opacity(0.82))
                .rotationEffect(.degrees(-3))
                .offset(x: 3, y: 2)
        case .pencilMark:
            PencilReflectionMark(color: palette.dark)
                .frame(width: 18, height: 8)
                .offset(x: 2, y: -1)
        case .tinyStar:
            Text("☆")
                .font(.system(size: 9, weight: .regular))
                .foregroundStyle(palette.accent.opacity(0.72))
                .offset(x: 2, y: 1)
        case .cornerFold:
            CornerFoldTrace(color: palette.surface)
                .frame(width: 8, height: 8)
                .offset(x: 1, y: 1)
        case .softCheck:
            Text("✓")
                .font(.system(size: 8, weight: .light, design: .serif))
                .foregroundStyle(palette.dark.opacity(0.48))
                .rotationEffect(.degrees(-8))
                .offset(x: 2, y: 1)
        }
    }
}

private struct PencilReflectionMark: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 1, y: size.height * 0.62))
            path.addQuadCurve(
                to: CGPoint(x: size.width - 1, y: size.height * 0.42),
                control: CGPoint(x: size.width * 0.48, y: size.height * 0.78)
            )
            context.stroke(path, with: .color(color.opacity(0.34)), lineWidth: 0.7)
        }
    }
}

private struct CornerFoldTrace: View {
    let color: Color

    var body: some View {
        TriangleFoldShape()
            .fill(color.opacity(0.82))
            .overlay(TriangleFoldShape().stroke(.black.opacity(0.07), lineWidth: 0.5))
    }
}

private struct TriangleFoldShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct GrowthMiniPhoto: View {
    let configuration: LockerItemThemeConfiguration

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Rectangle().fill(configuration.palette.surface.opacity(0.78))
                LockerThemePhoto(style: configuration.photoStyle, palette: configuration.palette)
                    .padding(.horizontal, 3)
                    .padding(.top, 3)
                    .padding(.bottom, 8)
                Rectangle()
                    .fill(configuration.palette.primary.opacity(0.46))
                    .frame(width: proxy.size.width * 0.54, height: 5)
                    .offset(y: -2)
            }
            .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        }
    }
}

private struct GrowthShelfWear: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            for index in 0..<3 {
                var path = Path()
                let y = size.height * (0.28 + CGFloat(index) * 0.22)
                path.move(to: CGPoint(x: size.width * (0.08 + CGFloat(index) * 0.11), y: y))
                path.addQuadCurve(
                    to: CGPoint(x: size.width * (0.72 + CGFloat(index) * 0.06), y: y + 0.5),
                    control: CGPoint(x: size.width * 0.46, y: y - 1)
                )
                context.stroke(path, with: .color(color.opacity(0.07)), lineWidth: 0.55)
            }
        }
    }
}

private struct LockerShelfObjectLayer: View {
    @EnvironmentObject private var settingsRepository: LockerSettingsRepository
    @EnvironmentObject private var demoClock: LockUDemoClock
    @State private var dailyVariation = LockerDailyVariation.base()

    var body: some View {
        GeometryReader { proxy in
            let configuration = LockerItemThemeConfiguration.theme(
                settingsRepository.settings.appearance.itemTheme
            )
            LockerShelfDecorationsView(
                configuration: configuration,
                dailyVariation: dailyVariation,
                metrics: LockerShelfLayoutMetrics(containerSize: proxy.size)
            )
        }
        .animation(.easeInOut(duration: 0.22), value: settingsRepository.settings.appearance.itemTheme)
        .onAppear(perform: refreshDailyVariation)
        .onChange(of: settingsRepository.settings.appearance.itemTheme) { _, _ in refreshDailyVariation() }
        .onChange(of: demoClock.preset) { _, _ in refreshDailyVariation() }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func refreshDailyVariation() {
        let next = LockerDailyVariationGenerator().variation(
            for: demoClock.now,
            theme: settingsRepository.settings.appearance.itemTheme
        )
        guard next != dailyVariation else { return }
        dailyVariation = next
    }
}

private struct LockerItemPalette {
    let primary: Color
    let secondary: Color
    let accent: Color
    let neutral: Color
    let surface: Color
    let dark: Color
    let glassTint: Color
    let flower: Color

    static let blush = LockerItemPalette(
        primary: Color(red: 231/255, green: 195/255, blue: 197/255),
        secondary: Color(red: 239/255, green: 217/255, blue: 216/255),
        accent: Color(red: 217/255, green: 210/255, blue: 227/255),
        neutral: Color(red: 190/255, green: 183/255, blue: 175/255),
        surface: Color(red: 243/255, green: 237/255, blue: 228/255),
        dark: Color(red: 80/255, green: 81/255, blue: 84/255),
        glassTint: Color(red: 222/255, green: 215/255, blue: 210/255),
        flower: Color(red: 235/255, green: 200/255, blue: 197/255)
    )

    static let blue = LockerItemPalette(
        primary: Color(red: 185/255, green: 205/255, blue: 213/255),
        secondary: Color(red: 214/255, green: 225/255, blue: 228/255),
        accent: Color(red: 100/255, green: 118/255, blue: 126/255),
        neutral: Color(red: 187/255, green: 195/255, blue: 197/255),
        surface: Color(red: 244/255, green: 241/255, blue: 234/255),
        dark: Color(red: 70/255, green: 81/255, blue: 87/255),
        glassTint: Color(red: 206/255, green: 222/255, blue: 227/255),
        flower: Color(red: 242/255, green: 241/255, blue: 234/255)
    )

    static let sage = LockerItemPalette(
        primary: Color(red: 195/255, green: 201/255, blue: 182/255),
        secondary: Color(red: 216/255, green: 220/255, blue: 207/255),
        accent: Color(red: 222/255, green: 208/255, blue: 164/255),
        neutral: Color(red: 183/255, green: 181/255, blue: 170/255),
        surface: Color(red: 240/255, green: 234/255, blue: 221/255),
        dark: Color(red: 83/255, green: 88/255, blue: 80/255),
        glassTint: Color(red: 211/255, green: 220/255, blue: 207/255),
        flower: Color(red: 226/255, green: 211/255, blue: 159/255)
    )

    static let aoharu = LockerItemPalette(
        primary: Color(red: 175/255, green: 203/255, blue: 213/255),
        secondary: Color(red: 207/255, green: 224/255, blue: 229/255),
        accent: Color(red: 230/255, green: 199/255, blue: 200/255),
        neutral: Color(red: 132/255, green: 151/255, blue: 158/255),
        surface: Color(red: 241/255, green: 236/255, blue: 226/255),
        dark: Color(red: 70/255, green: 82/255, blue: 88/255),
        glassTint: Color(red: 207/255, green: 224/255, blue: 229/255),
        flower: Color(red: 244/255, green: 241/255, blue: 234/255)
    )
}

enum LockerFlowerStyle: Equatable, Sendable { case tulip, whiteTulip, daisy, paleYellowDaisy, paleTulip }
enum LockerPhotoStyle: Equatable, Sendable {
    case sunset, clearSky, greenField, summerSky
    case softCloud, sunlight, classroomWindow, warmCloud
    case deepBlue, cityLights, moonGlow, summerTree
}

private struct LockerItemThemeConfiguration {
    let palette: LockerItemPalette
    let flowerStyle: LockerFlowerStyle
    let photoStyle: LockerPhotoStyle
    let notebookTitle: String
    let minorMark: String
    let perfumeLabel: String
    let cameraButtonColor: Color

    static func theme(_ theme: LockerItemTheme) -> LockerItemThemeConfiguration {
        switch theme {
        case .blush:
            LockerItemThemeConfiguration(palette: .blush, flowerStyle: .tulip, photoStyle: .sunset, notebookTitle: "MEMORY\nNOTE", minorMark: "♡", perfumeLabel: "BREEZE", cameraButtonColor: LockerItemPalette.blush.accent)
        case .blue:
            LockerItemThemeConfiguration(palette: .blue, flowerStyle: .daisy, photoStyle: .clearSky, notebookTitle: "MEMORY\nNOTE", minorMark: "☁", perfumeLabel: "BREEZE", cameraButtonColor: LockerItemPalette.blue.neutral)
        case .sage:
            LockerItemThemeConfiguration(palette: .sage, flowerStyle: .paleTulip, photoStyle: .greenField, notebookTitle: "MEMORY\nNOTE", minorMark: "⌁", perfumeLabel: "MOMENT", cameraButtonColor: LockerItemPalette.sage.accent)
        case .aoharu:
            LockerItemThemeConfiguration(palette: .aoharu, flowerStyle: .daisy, photoStyle: .summerSky, notebookTitle: "SUMMER\nNOTES", minorMark: "✦", perfumeLabel: "DAYLIGHT", cameraButtonColor: LockerItemPalette.aoharu.accent)
        }
    }
}

private struct LockerShelfLayoutMetrics {
    let size: CGSize
    let baseline: CGFloat

    init(containerSize: CGSize) {
        size = containerSize
        baseline = containerSize.height - 1
    }

    var notebookSize: CGSize { CGSize(width: size.width * 0.22, height: min(size.height * 0.92, size.width * 0.20)) }
    var cameraSize: CGSize { CGSize(width: size.width * 0.24, height: min(size.height * 0.56, size.width * 0.105)) }
    var vaseSize: CGSize { CGSize(width: size.width * 0.10, height: min(size.height * 0.91, size.width * 0.18)) }
    var perfumeSize: CGSize { CGSize(width: size.width * 0.10, height: min(size.height * 0.66, size.width * 0.125)) }
    var frameSize: CGSize { CGSize(width: size.width * 0.17, height: min(size.height * 0.76, size.width * 0.15)) }

    func position(x: CGFloat, itemSize: CGSize, lift: CGFloat = 0) -> CGPoint {
        CGPoint(x: size.width * x, y: baseline - itemSize.height * 0.5 - lift)
    }
}

private struct LockerShelfDecorationsView: View {
    let configuration: LockerItemThemeConfiguration
    let dailyVariation: LockerDailyVariation
    let metrics: LockerShelfLayoutMetrics

    private var palette: LockerItemPalette { configuration.palette }

    var body: some View {
        ZStack(alignment: .topLeading) {
            MemoryNotebookView(
                configuration: configuration,
                dailyDetail: dailyVariation.notebookDetail
            )
                .frame(width: metrics.notebookSize.width, height: metrics.notebookSize.height)
                .rotationEffect(.degrees(-6 + dailyVariation.notebookPose.rotationDelta), anchor: .bottom)
                .position(metrics.position(x: 0.16, itemSize: metrics.notebookSize, lift: 1))
                .offset(x: CGFloat(dailyVariation.notebookPose.xOffset), y: CGFloat(dailyVariation.notebookPose.yOffset))
                .zIndex(1)

            MiniPhotoFrameView(
                configuration: configuration,
                dailyPhotoStyle: dailyVariation.framePhotoStyle
            )
                .frame(width: metrics.frameSize.width, height: metrics.frameSize.height)
                .rotationEffect(.degrees(4 + dailyVariation.framePose.rotationDelta), anchor: .bottom)
                .position(metrics.position(x: 0.84, itemSize: metrics.frameSize, lift: 1))
                .offset(x: CGFloat(dailyVariation.framePose.xOffset), y: CGFloat(dailyVariation.framePose.yOffset))
                .zIndex(1)

            FlowerVaseView(
                configuration: configuration,
                dailyFlowerStyle: dailyVariation.flowerStyle
            )
                .frame(width: metrics.vaseSize.width, height: metrics.vaseSize.height)
                .rotationEffect(.degrees(-1), anchor: .bottom)
                .position(metrics.position(x: 0.56, itemSize: metrics.vaseSize))
                .zIndex(2)

            PerfumeBottleView(
                configuration: configuration,
                dailyLabel: dailyVariation.perfumeLabel
            )
                .frame(width: metrics.perfumeSize.width, height: metrics.perfumeSize.height)
                .rotationEffect(.degrees(1), anchor: .bottom)
                .position(metrics.position(x: 0.69, itemSize: metrics.perfumeSize))
                .zIndex(2)

            PastelCameraView(
                configuration: configuration,
                dailyAccentEnabled: dailyVariation.cameraAccentEnabled
            )
                .frame(width: metrics.cameraSize.width, height: metrics.cameraSize.height)
                .rotationEffect(.degrees(2 + dailyVariation.cameraPose.rotationDelta), anchor: .bottom)
                .position(metrics.position(x: 0.35, itemSize: metrics.cameraSize, lift: -1))
                .offset(x: CGFloat(dailyVariation.cameraPose.xOffset), y: CGFloat(dailyVariation.cameraPose.yOffset))
                .zIndex(3)
        }
    }
}

private struct MemoryNotebookView: View {
    let configuration: LockerItemThemeConfiguration
    let dailyDetail: String?
    private var palette: LockerItemPalette { configuration.palette }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(palette.neutral.opacity(0.45))
                    .offset(x: 2, y: 1.5)
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [palette.primary.opacity(0.94), palette.primary, palette.primary.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .leading) {
                        VStack(spacing: max(1.4, proxy.size.height * 0.045)) {
                            ForEach(0..<9, id: \.self) { _ in
                                Capsule().fill(palette.dark.opacity(0.46)).frame(width: 4.5, height: 1)
                            }
                        }
                        .offset(x: -2)
                    }
                    .overlay {
                        VStack(spacing: 1) {
                            Text(configuration.notebookTitle)
                                .multilineTextAlignment(.center)
                            Text(dailyDetail ?? configuration.minorMark)
                                .font(.system(size: 6, weight: .regular))
                                .foregroundStyle(palette.accent.opacity(0.74))
                        }
                        .font(.system(size: 5.5, weight: .medium, design: .serif))
                        .tracking(0.8)
                        .foregroundStyle(palette.dark.opacity(0.62))
                        .fixedSize()
                    }
                    .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.18)).frame(height: 0.7).padding(.horizontal, 4) }
            }
            .shadow(color: .black.opacity(0.09), radius: 4, y: 3)
            .overlay(alignment: .bottom) { ContactShadow(width: proxy.size.width * 0.78, opacity: 0.08) }
        }
    }
}

private struct PastelCameraView: View {
    let configuration: LockerItemThemeConfiguration
    let dailyAccentEnabled: Bool
    private var palette: LockerItemPalette { configuration.palette }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        LinearGradient(
                            colors: [palette.secondary, palette.secondary.opacity(0.94), palette.neutral.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .top) {
                        Rectangle().fill(.white.opacity(0.34)).frame(height: 1).padding(.horizontal, 5)
                    }
                RoundedRectangle(cornerRadius: 2)
                    .fill(palette.primary.opacity(0.76))
                    .frame(width: proxy.size.width * 0.28, height: proxy.size.height * 0.17)
                    .position(x: proxy.size.width * 0.22, y: proxy.size.height * 0.19)
                Circle()
                    .fill(configuration.cameraButtonColor.opacity(dailyAccentEnabled ? 0.96 : 0.72))
                    .frame(width: dailyAccentEnabled ? 4.2 : 3.5, height: dailyAccentEnabled ? 4.2 : 3.5)
                    .position(x: proxy.size.width * 0.83, y: proxy.size.height * 0.16)
                ZStack {
                    Circle().fill(palette.neutral.opacity(0.72))
                    Circle().stroke(.white.opacity(0.55), lineWidth: 1).padding(2)
                    Circle().fill(palette.dark.opacity(0.94)).padding(5)
                    Circle().fill(
                        RadialGradient(
                            colors: [Color(red: 72/255, green: 93/255, blue: 105/255), palette.dark, .black.opacity(0.94)],
                            center: UnitPoint(x: 0.38, y: 0.32),
                            startRadius: 1,
                            endRadius: 14
                        )
                    ).padding(8)
                    Ellipse().fill(.white.opacity(0.23)).frame(width: 10, height: 5).offset(x: -3, y: -4).rotationEffect(.degrees(-18))
                }
                .frame(width: proxy.size.height * 0.84, height: proxy.size.height * 0.84)
                .position(x: proxy.size.width * 0.58, y: proxy.size.height * 0.52)
                Text("LU")
                    .font(.system(size: 5, weight: .medium))
                    .foregroundStyle(palette.dark.opacity(0.58))
                    .position(x: proxy.size.width * 0.18, y: proxy.size.height * 0.72)
            }
            .shadow(color: .black.opacity(0.11), radius: 5, y: 4)
            .overlay(alignment: .bottom) { ContactShadow(width: proxy.size.width * 0.70, opacity: 0.11) }
        }
    }
}

private struct FlowerVaseView: View {
    let configuration: LockerItemThemeConfiguration
    let dailyFlowerStyle: LockerFlowerStyle?
    private var palette: LockerItemPalette { configuration.palette }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color(red: 94/255, green: 116/255, blue: 91/255).opacity(0.82))
                    .frame(width: 1.6, height: proxy.size.height * 0.66)
                    .rotationEffect(.degrees(3), anchor: .bottom)
                    .offset(x: 1, y: -proxy.size.height * 0.25)
                FlowerHead(style: dailyFlowerStyle ?? configuration.flowerStyle, palette: palette)
                    .frame(width: proxy.size.width * 0.62, height: proxy.size.height * 0.23)
                    .rotationEffect(.degrees(-6))
                    .offset(x: 2, y: -proxy.size.height * 0.76)
                Capsule()
                    .fill(Color(red: 121/255, green: 142/255, blue: 110/255).opacity(0.70))
                    .frame(width: proxy.size.width * 0.42, height: 4)
                    .rotationEffect(.degrees(-25))
                    .offset(x: -3, y: -proxy.size.height * 0.48)
                VaseGlassShape()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.52), palette.glassTint.opacity(0.25), .white.opacity(0.16)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(VaseGlassShape().stroke(.white.opacity(0.42), lineWidth: 0.7))
                    .frame(width: proxy.size.width * 0.58, height: proxy.size.height * 0.43)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .shadow(color: .black.opacity(0.09), radius: 4, y: 3)
            .overlay(alignment: .bottom) { ContactShadow(width: proxy.size.width * 0.55, opacity: 0.09) }
        }
    }
}

private struct PerfumeBottleView: View {
    let configuration: LockerItemThemeConfiguration
    let dailyLabel: String?
    private var palette: LockerItemPalette { configuration.palette }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(palette.primary.opacity(0.82))
                    .frame(width: proxy.size.width * 0.48, height: proxy.size.height * 0.18)
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.58), palette.glassTint.opacity(0.27), .white.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(0.42), lineWidth: 0.7))
                    .overlay {
                        Text(dailyLabel ?? configuration.perfumeLabel)
                            .font(.system(size: 3.8, weight: .medium, design: .serif))
                            .tracking(0.35)
                            .foregroundStyle(palette.dark.opacity(0.56))
                            .padding(.horizontal, 3)
                            .padding(.vertical, 2)
                            .background(palette.secondary.opacity(0.70))
                    }
            }
            .shadow(color: .black.opacity(0.09), radius: 4, y: 3)
            .overlay(alignment: .bottom) { ContactShadow(width: proxy.size.width * 0.72, opacity: 0.08) }
        }
    }
}

private struct MiniPhotoFrameView: View {
    let configuration: LockerItemThemeConfiguration
    let dailyPhotoStyle: LockerPhotoStyle?
    private var palette: LockerItemPalette { configuration.palette }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(palette.surface)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.50), lineWidth: 1.2))
                LockerThemePhoto(style: dailyPhotoStyle ?? configuration.photoStyle, palette: palette)
                    .padding(proxy.size.width * 0.13)
                    .overlay(alignment: .topTrailing) {
                        Ellipse().fill(.white.opacity(0.48)).frame(width: proxy.size.width * 0.28, height: proxy.size.height * 0.12).offset(x: -7, y: 8)
                    }
            }
            .shadow(color: .black.opacity(0.08), radius: 4, y: 3)
            .overlay(alignment: .bottom) { ContactShadow(width: proxy.size.width * 0.72, opacity: 0.07) }
        }
    }
}

private struct FlowerHead: View {
    let style: LockerFlowerStyle
    let palette: LockerItemPalette

    var body: some View {
        switch style {
        case .tulip, .whiteTulip, .paleTulip:
            ZStack {
                Ellipse().fill(style == .whiteTulip ? palette.surface : palette.flower)
                Ellipse().fill(.white.opacity(0.18)).frame(width: 7, height: 3).offset(x: -2, y: -2)
            }
            .clipShape(UnevenFlowerShape())
        case .daisy, .paleYellowDaisy:
            ZStack {
                ForEach(0..<6, id: \.self) { index in
                    Capsule()
                        .fill(palette.flower)
                        .frame(width: 5, height: 12)
                        .offset(y: -4)
                        .rotationEffect(.degrees(Double(index) * 60))
                }
                Circle()
                    .fill(style == .paleYellowDaisy ? Color(red: 222/255, green: 208/255, blue: 164/255) : palette.accent.opacity(0.88))
                    .frame(width: 5, height: 5)
            }
        }
    }
}

private struct LockerThemePhoto: View {
    let style: LockerPhotoStyle
    let palette: LockerItemPalette

    private var colors: [Color] {
        switch style {
        case .sunset: [palette.secondary.opacity(0.84), palette.primary.opacity(0.56), palette.glassTint]
        case .clearSky: [palette.glassTint, palette.primary.opacity(0.78), palette.surface]
        case .greenField: [palette.glassTint, palette.secondary, palette.primary.opacity(0.76)]
        case .summerSky: [Color(red: 202/255, green: 225/255, blue: 234/255), palette.primary, palette.surface]
        case .softCloud: [palette.surface, palette.glassTint.opacity(0.82), palette.primary.opacity(0.50)]
        case .sunlight: [palette.surface, Color(red: 239/255, green: 222/255, blue: 182/255), palette.glassTint]
        case .classroomWindow: [palette.glassTint, palette.neutral.opacity(0.68), palette.surface]
        case .warmCloud: [palette.secondary, palette.accent.opacity(0.54), palette.surface]
        case .deepBlue: [Color(red: 96/255, green: 122/255, blue: 139/255), palette.glassTint, palette.surface.opacity(0.78)]
        case .cityLights: [Color(red: 111/255, green: 129/255, blue: 141/255), palette.accent.opacity(0.56), palette.surface]
        case .moonGlow: [Color(red: 126/255, green: 145/255, blue: 158/255), palette.surface, palette.glassTint]
        case .summerTree: [palette.glassTint, Color(red: 169/255, green: 185/255, blue: 157/255), palette.surface]
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(alignment: (style == .greenField || style == .summerTree) ? .bottom : .topTrailing) {
                if style == .greenField || style == .summerTree {
                    Ellipse().fill(palette.primary.opacity(0.52)).frame(width: 44, height: 18).offset(y: 8)
                } else {
                    Ellipse().fill(.white.opacity(style == .summerSky ? 0.62 : 0.46)).frame(width: 17, height: 6).offset(x: -5, y: 7)
                }
            }
            .saturation(0.82)
            .blur(radius: 0.22)
    }
}

private struct UnevenFlowerShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addCurve(to: CGPoint(x: rect.minX, y: rect.height * 0.25), control1: CGPoint(x: rect.width * 0.22, y: rect.height * 0.90), control2: CGPoint(x: rect.minX, y: rect.height * 0.55))
            path.addCurve(to: CGPoint(x: rect.midX, y: rect.height * 0.20), control1: CGPoint(x: rect.width * 0.18, y: 0), control2: CGPoint(x: rect.width * 0.38, y: rect.height * 0.12))
            path.addCurve(to: CGPoint(x: rect.maxX, y: rect.height * 0.22), control1: CGPoint(x: rect.width * 0.66, y: rect.height * 0.04), control2: CGPoint(x: rect.width * 0.88, y: 0))
            path.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control1: CGPoint(x: rect.maxX, y: rect.height * 0.62), control2: CGPoint(x: rect.width * 0.78, y: rect.height * 0.90))
            path.closeSubpath()
        }
    }
}

private struct ContactShadow: View {
    let width: CGFloat
    let opacity: Double

    var body: some View {
        Ellipse()
            .fill(.black.opacity(opacity))
            .frame(width: width, height: 4)
            .blur(radius: 1.8)
            .offset(y: 2)
    }
}

private struct VaseGlassShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.width * 0.34, y: 0))
            path.addLine(to: CGPoint(x: rect.width * 0.66, y: 0))
            path.addLine(to: CGPoint(x: rect.width * 0.72, y: rect.height * 0.20))
            path.addQuadCurve(to: CGPoint(x: rect.width * 0.88, y: rect.height), control: CGPoint(x: rect.width * 0.84, y: rect.height * 0.60))
            path.addLine(to: CGPoint(x: rect.width * 0.12, y: rect.height))
            path.addQuadCurve(to: CGPoint(x: rect.width * 0.28, y: rect.height * 0.20), control: CGPoint(x: rect.width * 0.16, y: rect.height * 0.60))
            path.closeSubpath()
        }
    }
}

private struct LockerBookStack: View {
    var body: some View {
        GeometryReader { proxy in
            let bookWidth = proxy.size.width * 0.28
            let height = proxy.size.height

            ZStack(alignment: .bottomLeading) {
                LockerStandingBook(
                    cover: Color(red: 86/255, green: 104/255, blue: 114/255),
                    page: Color(red: 229/255, green: 224/255, blue: 212/255),
                    title: "国語"
                )
                .frame(width: bookWidth, height: height * 0.91)
                .rotationEffect(.degrees(-2), anchor: .bottom)
                .offset(x: proxy.size.width * 0.04)

                LockerStandingBook(
                    cover: Color(red: 116/255, green: 139/255, blue: 147/255),
                    page: Color(red: 233/255, green: 229/255, blue: 218/255),
                    title: "英語"
                )
                .frame(width: bookWidth * 0.94, height: height * 0.86)
                .rotationEffect(.degrees(1), anchor: .bottom)
                .offset(x: proxy.size.width * 0.32)

                LockerStandingBook(
                    cover: Color(red: 194/255, green: 192/255, blue: 181/255),
                    page: Color(red: 233/255, green: 229/255, blue: 218/255),
                    title: "NOTE"
                )
                .frame(width: bookWidth * 0.78, height: height * 0.78)
                .rotationEffect(.degrees(4), anchor: .bottom)
                .offset(x: proxy.size.width * 0.58)
            }
            .overlay(alignment: .bottom) {
                Ellipse()
                    .fill(.black.opacity(0.065))
                    .frame(width: proxy.size.width * 0.92, height: 4)
                    .blur(radius: 2)
                    .offset(y: 2)
            }
        }
    }
}

private struct LockerStandingBook: View {
    let cover: Color
    let page: Color
    let title: String

    var body: some View {
        GeometryReader { proxy in
            let spineWidth = max(5, proxy.size.width * 0.18)

            ZStack(alignment: .leading) {
                BookCoverSilhouette()
                    .fill(
                        LinearGradient(
                            colors: [cover.opacity(0.94), cover, cover.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(page)
                            .frame(width: max(3, proxy.size.width * 0.10))
                            .padding(.vertical, 3)
                            .overlay(alignment: .leading) { Rectangle().fill(.black.opacity(0.05)).frame(width: 0.6) }
                    }
                    .overlay {
                        BookPaperGrain()
                            .clipShape(BookCoverSilhouette())
                    }

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.12), cover.opacity(0.72)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: spineWidth)
                    .padding(.vertical, 1)

                Text(title)
                    .font(.system(size: 6, weight: .medium, design: .serif))
                    .foregroundStyle(.white.opacity(0.68))
                    .rotationEffect(.degrees(90))
                    .fixedSize()
                    .offset(x: -1)
            }
            .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.13)).frame(height: 0.7).padding(.horizontal, 2) }
            .overlay(alignment: .bottom) { Rectangle().fill(.black.opacity(0.07)).frame(height: 1.2).padding(.horizontal, 2) }
        }
    }
}

private struct BookPaperGrain: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<13 {
                let x = CGFloat((index * 37) % 97) / 97 * size.width
                let y = CGFloat((index * 61) % 89) / 89 * size.height
                let color: Color = index.isMultiple(of: 3) ? .white.opacity(0.035) : .black.opacity(0.025)
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 0.65, height: 0.65)), with: .color(color))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct LockerSmallBottle: View {
    var body: some View {
        ZStack(alignment: .top) {
            LockerBottleBody()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.22), Color(red: 191/255, green: 210/255, blue: 213/255).opacity(0.34), .white.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    LockerBottleBody().stroke(.white.opacity(0.24), lineWidth: 0.7)
                }
                .overlay(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.28)).frame(width: 1.1).padding(.vertical, 10).padding(.leading, 3)
                }
                .padding(.top, 6)

            RoundedRectangle(cornerRadius: 1.2)
                .fill(Color(red: 127/255, green: 139/255, blue: 140/255))
                .frame(width: 9, height: 7)
        }
        .overlay(alignment: .bottom) {
            Ellipse().fill(.black.opacity(0.075)).frame(width: 18, height: 4).blur(radius: 2).offset(y: 2)
        }
    }
}

private struct LockerBottleBody: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.width * 0.30, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.width * 0.70, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.width * 0.76, y: rect.height * 0.14))
            path.addQuadCurve(to: CGPoint(x: rect.width * 0.90, y: rect.height * 0.25), control: CGPoint(x: rect.width * 0.88, y: rect.height * 0.18))
            path.addLine(to: CGPoint(x: rect.width * 0.94, y: rect.height * 0.92))
            path.addQuadCurve(to: CGPoint(x: rect.width * 0.82, y: rect.height), control: CGPoint(x: rect.width * 0.94, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width * 0.18, y: rect.height))
            path.addQuadCurve(to: CGPoint(x: rect.width * 0.06, y: rect.height * 0.92), control: CGPoint(x: rect.width * 0.06, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width * 0.10, y: rect.height * 0.25))
            path.addQuadCurve(to: CGPoint(x: rect.width * 0.24, y: rect.height * 0.14), control: CGPoint(x: rect.width * 0.12, y: rect.height * 0.18))
            path.closeSubpath()
        }
    }
}

private struct LockerSmallCase: View {
    var body: some View {
        ZStack {
            UnevenCaseShape()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 227/255, green: 224/255, blue: 213/255), Color(red: 205/255, green: 210/255, blue: 204/255)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.25)).frame(height: 0.7).padding(.horizontal, 3) }
                .overlay(alignment: .center) { Rectangle().fill(.black.opacity(0.055)).frame(height: 0.7).padding(.horizontal, 2) }
        }
        .overlay(alignment: .bottom) {
            Ellipse().fill(.black.opacity(0.055)).frame(height: 4).blur(radius: 2).offset(y: 2)
        }
    }
}

private struct UnevenCaseShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 2, y: 1))
            path.addQuadCurve(to: CGPoint(x: rect.width - 2, y: 0), control: CGPoint(x: rect.midX, y: 1))
            path.addQuadCurve(to: CGPoint(x: rect.width, y: 3), control: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width - 1, y: rect.height - 2))
            path.addQuadCurve(to: CGPoint(x: 2, y: rect.height), control: CGPoint(x: rect.midX, y: rect.height - 1))
            path.addQuadCurve(to: CGPoint(x: 0, y: rect.height - 3), control: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()
        }
    }
}

private struct LockerFabricPouch: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                FabricPouchShape()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 178/255, green: 196/255, blue: 202/255), Color(red: 165/255, green: 185/255, blue: 192/255), Color(red: 145/255, green: 167/255, blue: 175/255)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay { FabricTexture().clipShape(FabricPouchShape()) }
                    .overlay(alignment: .top) {
                        HStack(spacing: 0) {
                            Rectangle().fill(.white.opacity(0.22)).frame(height: 0.8)
                            Capsule().fill(Color(red: 105/255, green: 118/255, blue: 121/255)).frame(width: 7, height: 2.2)
                        }
                        .padding(.horizontal, 7)
                        .offset(y: 4)
                    }
                    .overlay(alignment: .bottom) {
                        Capsule().fill(.black.opacity(0.07)).frame(width: proxy.size.width * 0.68, height: 2).blur(radius: 1).offset(y: -2)
                    }

                Text("LU")
                    .font(.system(size: 4.5, weight: .medium, design: .serif))
                    .foregroundStyle(Color(red: 89/255, green: 102/255, blue: 106/255).opacity(0.64))
                    .frame(width: 15, height: 8)
                    .background(Color(red: 220/255, green: 215/255, blue: 201/255).opacity(0.82))
                    .offset(x: proxy.size.width * 0.24, y: proxy.size.height * 0.14)
            }
            .overlay(alignment: .bottom) {
                Ellipse()
                    .fill(.black.opacity(0.085))
                    .frame(width: proxy.size.width * 0.86, height: 5)
                    .blur(radius: 2.5)
                    .offset(y: 2)
            }
        }
    }
}

private struct FabricPouchShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.width * 0.08, y: rect.height * 0.14))
            path.addQuadCurve(to: CGPoint(x: rect.width * 0.90, y: rect.height * 0.08), control: CGPoint(x: rect.width * 0.50, y: -1))
            path.addQuadCurve(to: CGPoint(x: rect.width * 0.97, y: rect.height * 0.30), control: CGPoint(x: rect.width, y: rect.height * 0.12))
            path.addLine(to: CGPoint(x: rect.width * 0.94, y: rect.height * 0.82))
            path.addQuadCurve(to: CGPoint(x: rect.width * 0.78, y: rect.height * 0.96), control: CGPoint(x: rect.width * 0.90, y: rect.height))
            path.addQuadCurve(to: CGPoint(x: rect.width * 0.20, y: rect.height), control: CGPoint(x: rect.width * 0.50, y: rect.height * 0.91))
            path.addQuadCurve(to: CGPoint(x: rect.width * 0.04, y: rect.height * 0.78), control: CGPoint(x: rect.width * 0.07, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width * 0.02, y: rect.height * 0.31))
            path.addQuadCurve(to: CGPoint(x: rect.width * 0.08, y: rect.height * 0.14), control: CGPoint(x: 0, y: rect.height * 0.16))
            path.closeSubpath()
        }
    }
}

private struct FabricTexture: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<14 {
                let y = CGFloat(index) / 14 * size.height
                var path = Path()
                path.move(to: CGPoint(x: 2, y: y))
                path.addQuadCurve(to: CGPoint(x: size.width - 2, y: y + CGFloat(index % 3 - 1)), control: CGPoint(x: size.width * 0.52, y: y - 0.8))
                context.stroke(path, with: .color(index.isMultiple(of: 4) ? .white.opacity(0.035) : .black.opacity(0.022)), lineWidth: 0.45)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct PhysicalMetalShelf: View {
    var body: some View {
        VStack(spacing: 0) {
            TrapezoidShelfTop()
                .fill(LockUSceneTokens.Material.shelfTop)
                .frame(height: 6)
                .overlay(TrapezoidShelfTop().fill(LockUDesign.Color.worldSkyReflection.opacity(0.06)))
                .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.40)).frame(height: 0.7).padding(.horizontal, 2) }
            Rectangle()
                .fill(LockUSceneTokens.Material.shelfFront)
                .frame(height: 9)
            Rectangle().fill(LockUSceneTokens.Material.recess).frame(height: 6)
        }
        .overlay { HStack { Rectangle().fill(.black.opacity(0.25)).frame(width: 2); Spacer(); Rectangle().fill(.black.opacity(0.25)).frame(width: 2) } }
        .shadow(color: LockUSceneTokens.Shadow.structural, radius: 12, y: 8)
    }
}

private struct TrapezoidShelfTop: Shape {
    func path(in rect: CGRect) -> Path { Path { p in
        p.move(to: CGPoint(x: 4, y: 0)); p.addLine(to: CGPoint(x: rect.width-4, y: 0))
        p.addLine(to: CGPoint(x: rect.width, y: rect.height)); p.addLine(to: CGPoint(x: 0, y: rect.height)); p.closeSubpath()
    } }
}

struct LockerBookSpineView: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Rectangle().fill(.black.opacity(0.14)).frame(width: 5)
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(1.3)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Spacer(minLength: 2)
        }
        .foregroundStyle(LockUDesign.Color.ink)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 34)
        .background(BookCoverSilhouette().fill(color))
        .overlay(alignment: .top) {
            Rectangle().fill(Color(red: 235/255, green: 232/255, blue: 221/255)).frame(height: 4).padding(.horizontal, 7)
                .overlay(Rectangle().fill(.black.opacity(0.08)).frame(height: 0.5).padding(.horizontal, 7), alignment: .bottom)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(.white.opacity(0.45)).frame(height: 2).padding(.horizontal, 5)
        }
        .overlay(alignment: .trailing) { Rectangle().fill(.black.opacity(0.15)).frame(width: 2) }
        .overlay(alignment: .bottomLeading) { Rectangle().fill(.white.opacity(0.10)).frame(width: 16, height: 0.7).offset(x: 9, y: -1) }
        .shadow(color: LockUSceneTokens.Shadow.contact.opacity(0.70), radius: 1, y: 1)
    }
}

struct LockerCameraButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                CameraBodySilhouette()
                    .fill(LinearGradient(colors: [Color(red: 217/255, green: 215/255, blue: 207/255), Color(red: 200/255, green: 197/255, blue: 188/255), Color(red: 150/255, green: 148/255, blue: 142/255)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .aspectRatio(1.18, contentMode: .fit)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(.black.opacity(0.10)).frame(width: 12).padding(.vertical, 5)
                    }
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.8), LockUDesign.Color.summerShadow.opacity(0.5)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 19, height: 5)
                            .offset(x: 23, y: -3)
                    }
                    .overlay {
                        CameraBodyMicroTexture().clipShape(CameraBodySilhouette())
                    }
                    .overlay(alignment: .bottom) { Rectangle().fill(.black.opacity(0.20)).frame(height: 3).padding(.horizontal, 4) }
                    .overlay(alignment: .trailing) { Rectangle().fill(.black.opacity(0.16)).frame(width: 3).padding(.vertical, 5) }
                ZStack {
                    Circle().fill(Color(red: 130/255, green: 132/255, blue: 134/255)).frame(width: 42, height: 42).shadow(color: .black.opacity(0.23), radius: 2.5, y: 3)
                    Circle().fill(LinearGradient(colors: [Color(red: 155/255, green: 157/255, blue: 157/255), Color(red: 81/255, green: 84/255, blue: 86/255)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 37, height: 37)
                    Circle().fill(Color(red: 51/255, green: 55/255, blue: 58/255)).frame(width: 32, height: 32).shadow(color: .black.opacity(0.20), radius: 1.5, y: 1.5)
                    Circle().fill(RadialGradient(colors: [Color(red: 45/255, green: 58/255, blue: 70/255), Color(red: 16/255, green: 24/255, blue: 31/255), Color(red: 7/255, green: 9/255, blue: 11/255)], center: UnitPoint(x: 0.38, y: 0.32), startRadius: 1, endRadius: 15)).frame(width: 27, height: 27)
                    Ellipse().fill(LinearGradient(colors: [LockUDesign.Color.worldSkyReflection.opacity(0.22), Color.purple.opacity(0.07), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 14, height: 8).offset(x: -3, y: -4).rotationEffect(.degrees(-18))
                    Circle().fill(Color(red: 5/255, green: 6/255, blue: 7/255)).frame(width: 10, height: 10)
                    Circle().trim(from: 0.10, to: 0.25).stroke(.white.opacity(0.32), lineWidth: 0.8).frame(width: 20, height: 20).rotationEffect(.degrees(-24))
                }
                RoundedRectangle(cornerRadius: 1).fill(Color(white: 0.82)).frame(width: 18, height: 7).offset(x: -25, y: -22).overlay(RoundedRectangle(cornerRadius: 1).stroke(.black.opacity(0.18))).offset(x: 0, y: 0)
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle().fill(LockUDesign.Color.schoolNavy.opacity(0.62)).frame(width: 1.5, height: 1.5)
                    }
                }
                    .offset(x: -25, y: -12)
                Text("LU")
                    .font(.system(size: 6, weight: .medium))
                    .foregroundStyle(.black.opacity(0.48))
                    .offset(x: -25, y: 19)
                ForEach([-1.0, 1.0], id: \.self) { direction in
                    Circle()
                        .fill(LockUDesign.Color.schoolNavy.opacity(0.55))
                        .frame(width: 2, height: 2)
                        .offset(x: direction * 35, y: 25)
                }
                RoundedRectangle(cornerRadius: 2)
                    .stroke(LockUDesign.Color.schoolNavy.opacity(0.66), lineWidth: 1.5)
                    .frame(width: 5, height: 11)
                    .offset(x: 45, y: 8)
            }
            .shadow(color: .black.opacity(0.30), radius: 1, y: 1)
            .shadow(color: .black.opacity(0.16), radius: 5, y: 4)
        }
        .buttonStyle(LockerPressStyle())
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("カメラ")
        .accessibilityHint("Opens Camera tab")
    }
}

private struct CameraBodyMicroTexture: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<16 {
                let x = CGFloat((index * 29) % 97) / 97 * size.width
                let y = CGFloat((index * 53) % 89) / 89 * size.height
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 0.7, height: 0.7)),
                    with: .color(index.isMultiple(of: 3) ? .white.opacity(0.035) : .black.opacity(0.025))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct CameraBodySilhouette: Shape {
    func path(in r: CGRect) -> Path { Path { p in
        p.move(to: CGPoint(x: 5, y: 1)); p.addQuadCurve(to: CGPoint(x: r.width - 4, y: 0), control: CGPoint(x: r.width * 0.55, y: -0.5))
        p.addQuadCurve(to: CGPoint(x: r.width, y: 5), control: CGPoint(x: r.width, y: 1))
        p.addLine(to: CGPoint(x: r.width - 1, y: r.height - 4)); p.addQuadCurve(to: CGPoint(x: r.width - 5, y: r.height), control: CGPoint(x: r.width, y: r.height))
        p.addLine(to: CGPoint(x: 4, y: r.height - 1)); p.addQuadCurve(to: CGPoint(x: 0, y: r.height - 5), control: CGPoint(x: 0, y: r.height))
        p.addLine(to: CGPoint(x: 1, y: 5)); p.addQuadCurve(to: CGPoint(x: 5, y: 1), control: CGPoint(x: 1, y: 1)); p.closeSubpath()
    } }
}

private struct BookCoverSilhouette: Shape {
    func path(in r: CGRect) -> Path { Path { p in
        p.move(to: CGPoint(x: 1, y: 1)); p.addLine(to: CGPoint(x: r.width - 2, y: 0.5)); p.addLine(to: CGPoint(x: r.width, y: r.height - 1.5)); p.addLine(to: CGPoint(x: 2, y: r.height)); p.addQuadCurve(to: CGPoint(x: 1, y: 1), control: CGPoint(x: -0.5, y: r.height * 0.5)); p.closeSubpath()
    } }
}

private struct RamuneBottleView: View {
    var body: some View {
        ZStack {
            RamuneBottleShape()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.76),
                            LockUDesign.Color.ramuneBlue.opacity(0.28),
                            .white.opacity(0.18),
                            LockUDesign.Color.ramuneBlue.opacity(0.38),
                            .white.opacity(0.64)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay {
                    RamuneBottleShape()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.92), LockUDesign.Color.ramuneBlue.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.2
                        )
                }
                .shadow(color: .white.opacity(0.22), radius: 1, x: -1)
            RamuneBottleShape()
                .inset(by: 3)
                .stroke(.white.opacity(0.34), lineWidth: 1)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, LockUDesign.Color.ramuneBlue.opacity(0.78), .white.opacity(0.25)],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: 7
                    )
                )
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 1))
                .offset(y: -24)

            VStack(spacing: 1) {
                Text("ラムネ")
                    .font(.system(size: 4, weight: .bold, design: .rounded))
                Text("RAMUNE")
                    .font(.system(size: 2.5, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(LockUDesign.Color.ramuneBlue)
            .frame(width: 16, height: 15)
            .background(LockUDesign.Color.notebookPaper.opacity(0.83))
            .overlay(Rectangle().stroke(.white.opacity(0.6), lineWidth: 0.5))
            .rotation3DEffect(.degrees(-6), axis: (x: 0, y: 1, z: 0))
            .offset(y: 19)

            Canvas { context, size in
                for index in 0..<9 {
                    let x = size.width * (0.22 + CGFloat((index * 31) % 57) / 100)
                    let y = size.height * (0.18 + CGFloat((index * 23) % 69) / 100)
                    let diameter = CGFloat(index.isMultiple(of: 3) ? 2.2 : 1.3)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)),
                        with: .color(.white.opacity(0.72))
                    )
                }
                for index in 0..<5 {
                    let x = size.width * (0.3 + CGFloat(index * 13 % 42) / 100)
                    let y = size.height * (0.2 + CGFloat(index * 19 % 61) / 100)
                    var fingerprint = Path()
                    fingerprint.addArc(
                        center: CGPoint(x: x, y: y),
                        radius: 2 + CGFloat(index % 2),
                        startAngle: .degrees(25),
                        endAngle: .degrees(290),
                        clockwise: false
                    )
                    context.stroke(fingerprint, with: .color(.white.opacity(0.12)), lineWidth: 0.45)
                }
            }
            .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.35), radius: 2, y: 2)
        .shadow(color: LockUDesign.Color.ramuneBlue.opacity(0.22), radius: 10, y: 6)
        .overlay(alignment: .bottom) {
            Ellipse()
                .fill(LockUDesign.Color.ramuneBlue.opacity(0.18))
                .frame(width: 26, height: 7)
                .blur(radius: 3)
                .offset(y: 4)
        }
        .accessibilityLabel("ラムネ瓶")
    }
}

private struct RamuneBottleShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let x = r.minX
        let y = r.minY
        let w = r.width
        let h = r.height
        var path = Path()
        path.move(to: CGPoint(x: x + w * 0.37, y: y))
        path.addCurve(
            to: CGPoint(x: x + w * 0.31, y: y + h * 0.24),
            control1: CGPoint(x: x + w * 0.34, y: y + h * 0.07),
            control2: CGPoint(x: x + w * 0.34, y: y + h * 0.17)
        )
        path.addCurve(
            to: CGPoint(x: x + w * 0.19, y: y + h * 0.41),
            control1: CGPoint(x: x + w * 0.30, y: y + h * 0.31),
            control2: CGPoint(x: x + w * 0.20, y: y + h * 0.33)
        )
        path.addCurve(
            to: CGPoint(x: x + w * 0.25, y: y + h * 0.58),
            control1: CGPoint(x: x + w * 0.17, y: y + h * 0.48),
            control2: CGPoint(x: x + w * 0.23, y: y + h * 0.53)
        )
        path.addCurve(
            to: CGPoint(x: x + w * 0.11, y: y + h * 0.78),
            control1: CGPoint(x: x + w * 0.23, y: y + h * 0.67),
            control2: CGPoint(x: x + w * 0.11, y: y + h * 0.69)
        )
        path.addCurve(
            to: CGPoint(x: x + w * 0.22, y: y + h),
            control1: CGPoint(x: x + w * 0.08, y: y + h * 0.90),
            control2: CGPoint(x: x + w * 0.13, y: y + h)
        )
        path.addLine(to: CGPoint(x: x + w * 0.78, y: y + h))
        path.addCurve(
            to: CGPoint(x: x + w * 0.89, y: y + h * 0.78),
            control1: CGPoint(x: x + w * 0.87, y: y + h),
            control2: CGPoint(x: x + w * 0.92, y: y + h * 0.90)
        )
        path.addCurve(
            to: CGPoint(x: x + w * 0.75, y: y + h * 0.58),
            control1: CGPoint(x: x + w * 0.89, y: y + h * 0.69),
            control2: CGPoint(x: x + w * 0.77, y: y + h * 0.67)
        )
        path.addCurve(
            to: CGPoint(x: x + w * 0.81, y: y + h * 0.41),
            control1: CGPoint(x: x + w * 0.77, y: y + h * 0.53),
            control2: CGPoint(x: x + w * 0.83, y: y + h * 0.48)
        )
        path.addCurve(
            to: CGPoint(x: x + w * 0.69, y: y + h * 0.24),
            control1: CGPoint(x: x + w * 0.80, y: y + h * 0.33),
            control2: CGPoint(x: x + w * 0.70, y: y + h * 0.31)
        )
        path.addCurve(
            to: CGPoint(x: x + w * 0.63, y: y),
            control1: CGPoint(x: x + w * 0.66, y: y + h * 0.17),
            control2: CGPoint(x: x + w * 0.66, y: y + h * 0.07)
        )
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> RamuneBottleShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}
