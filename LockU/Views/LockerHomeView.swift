import SwiftUI

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

    var body: some View {
        GeometryReader { proxy in
            let isOpen = appModel.lockerDoorState.isOpenOrOpening
            let maxHeight: CGFloat = isOpen ? 670 : 655
            let lockerHeight = min(maxHeight, proxy.size.height - 104)
            let lockerWidth = min(
                proxy.size.width * 0.94,
                lockerHeight / LockUSceneTokens.Home.lockerAspectRatio
            )

            VStack(spacing: LockUSceneTokens.Home.headerToLocker) {
                LockerUtilityBar(
                    date: demoClock.now,
                    onShare: onShare,
                    onCode: onCode,
                    onSettings: onSettings
                )
                .padding(.horizontal, LockUSceneTokens.Home.headerHorizontalMargin)
                .zIndex(LockUSceneTokens.Layer.interface)

                ZStack {
                    LockerFrameView(
                        lockerColor: Color(lockUHex: settingsRepository.settings.lockerColorHex)
                    )
                    .opacity(appModel.lockerDoorState.isOpenOrOpening ? 1 : 0.12)
                    .blur(radius: appModel.lockerDoorState == .closed ? 1.5 : 0)
                    .animation(
                        reduceMotion
                            ? LockUDesign.Motion.soft
                            : LockUDesign.Motion.soft.delay(
                                appModel.lockerDoorState == .opening ? 0.2 : 0
                            ),
                        value: appModel.lockerDoorState
                    )

                    LockerDoorView()
                        .zIndex(10)
                }
                .frame(width: lockerWidth, height: lockerHeight)
                .animation(.easeOut(duration: 0.22), value: isOpen)
                .zIndex(LockUSceneTokens.Layer.physical)

                Spacer(minLength: 24)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .opacity(appeared ? 1 : 0.65)
            .offset(y: appeared ? 0 : 8)
            .onAppear {
                appModel.refreshTimeDependentState()
                guard !appeared else { return }
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(.easeOut(duration: 0.45)) { appeared = true }
                }
            }
        }
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
                .font(.system(size: 29, weight: .semibold))
                .tracking(-0.5)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(date.formatted(.dateTime.month(.abbreviated).day()))
                .font(.system(size: 18, weight: .medium))
                .frame(maxWidth: .infinity)
            Menu {
                Button("Share", systemImage: "square.and.arrow.up", action: onShare)
                Button("Locker Code", systemImage: "number", action: onCode)
                Button("Settings", systemImage: "gearshape", action: onSettings)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .foregroundStyle(Color(red: 48/255, green: 69/255, blue: 87/255).opacity(0.84))
            .accessibilityLabel("Locker menu")
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .foregroundStyle(.white.opacity(0.94))
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        .frame(height: LockUSceneTokens.Home.headerHeight)
    }
}

struct LockerFrameView: View {
    @EnvironmentObject private var settingsRepository: LockerSettingsRepository
    let lockerColor: Color

    var body: some View {
        GeometryReader { proxy in
            let frameWidth = max(LockUSceneTokens.Home.frameThickness.lowerBound, min(LockUSceneTokens.Home.frameThickness.upperBound, proxy.size.width * 0.038))
            let topHeight: CGFloat = 16

            ZStack {
                LockerInteriorSurface()
                    .padding(.horizontal, frameWidth)
                    .padding(.top, topHeight)
                    .padding(.bottom, frameWidth)
                    .shadow(color: .black.opacity(0.34), radius: 5, x: 0, y: 5)

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
                        LinearGradient(
                            colors: [
                                LockUDesign.Color.lockerEdgeHighlight.opacity(0.42),
                                .clear,
                                .black.opacity(0.18)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: frameWidth)
                        .shadow(color: .black.opacity(0.18), radius: 8, x: 8)
                        Spacer()
                        LinearGradient(
                            colors: [.black.opacity(0.2), .clear],
                            startPoint: .trailing,
                            endPoint: .leading
                        )
                        .frame(width: frameWidth)
                        .shadow(color: .black.opacity(0.18), radius: 8, x: -8)
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
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .overlay {
                RoundedRectangle(cornerRadius: 2)
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
            .shadow(color: .black.opacity(0.20), radius: 12, y: 9)
        }
    }

    private func layeredFrameBar(axis: Axis, reversed: Bool = false) -> some View {
        let start: UnitPoint = axis == .horizontal ? (reversed ? .bottom : .top) : (reversed ? .trailing : .leading)
        let end: UnitPoint = axis == .horizontal ? (reversed ? .top : .bottom) : (reversed ? .leading : .trailing)
        return LinearGradient(
            stops: [
                .init(color: Color(red: 98/255, green: 107/255, blue: 111/255), location: 0),
                .init(color: Color(red: 157/255, green: 166/255, blue: 170/255), location: 0.18),
                .init(color: Color(red: 197/255, green: 204/255, blue: 207/255), location: 0.54),
                .init(color: Color(red: 125/255, green: 135/255, blue: 139/255), location: 0.82),
                .init(color: Color(red: 78/255, green: 87/255, blue: 90/255), location: 1)
            ], startPoint: start, endPoint: end
        )
        .overlay(LinearGradient(colors: [LockUDesign.Color.worldSkyReflection.opacity(0.08), .clear], startPoint: .topLeading, endPoint: .center))
        .overlay(alignment: axis == .horizontal ? .bottom : (reversed ? .leading : .trailing)) {
            Rectangle().fill(.black.opacity(0.23)).frame(width: axis == .vertical ? 2 : nil, height: axis == .horizontal ? 2 : nil)
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
    @EnvironmentObject private var settingsRepository: LockerSettingsRepository

    var body: some View {
        GeometryReader { proxy in
            let side = proxy.size.width * LockUSceneTokens.Home.sideWallFraction
            let ceiling = max(16, min(22, proxy.size.height * 0.032))
            let floor = max(14, proxy.size.height * 0.045)
            ZStack {
                LockerInteriorBackground(style: settingsRepository.settings.appearance.backgroundStyle)
                    .clipShape(BackWallShape(side: side, ceiling: ceiling, floor: floor))
                LockUSceneTokens.Material.leftWall
                    .clipShape(LeftInteriorWall(side: side, ceiling: ceiling, floor: floor))
                LockUSceneTokens.Material.rightWall
                    .clipShape(RightInteriorWall(side: side, ceiling: ceiling, floor: floor))
                LinearGradient(colors: [Color(red: 137/255, green: 147/255, blue: 151/255), Color(red: 105/255, green: 114/255, blue: 118/255)], startPoint: .top, endPoint: .bottom)
                    .clipShape(CeilingPlane(side: side, depth: ceiling))
                Color(red: 120/255, green: 131/255, blue: 135/255)
                    .clipShape(BottomPlane(side: side, depth: floor))

                PhysicalMetalGrain()
                    .opacity(0.36)
                    .padding(.horizontal, 1)

                InteriorLightFalloff(side: side, ceiling: ceiling, floor: floor)
                InteriorHardwareOverlay(side: side, ceiling: ceiling, floor: floor)

                LockerInteriorContent()
                    .padding(.horizontal, side + 1)
                    .padding(.top, ceiling)
                    .padding(.bottom, floor)

                InteriorAmbientOcclusion(side: side, ceiling: ceiling, floor: floor)
                LinearGradient(colors: [.black.opacity(0.12), .clear, .white.opacity(0.08), .clear, .black.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .allowsHitTesting(false)
            }
            .background(LockUDesign.Color.darkCavity)
            .overlay(Rectangle().strokeBorder(.black.opacity(0.24), lineWidth: 2))
            .shadow(color: .black.opacity(0.24), radius: 14, y: 4)
        }
    }
}

struct LockerInteriorBackground: View {
    let style: LockerBackgroundStyle

    var body: some View {
        LinearGradient(colors: style.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                Canvas { context, size in
                    for index in 0..<18 {
                        let x = CGFloat((index * 47) % 101) / 101 * size.width
                        let y = CGFloat((index * 71) % 103) / 103 * size.height
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 0.7, height: 0.7)), with: .color(.white.opacity(0.035)))
                    }
                }
            }
            .overlay(LinearGradient(colors: [.white.opacity(style.topLightOpacity), .clear], startPoint: .top, endPoint: .center))
            .accessibilityHidden(true)
    }
}

private extension LockerBackgroundStyle {
    var colors: [Color] {
        switch self {
        case .clearBlue: [Color(red: 166/255, green: 187/255, blue: 194/255), Color(red: 140/255, green: 163/255, blue: 170/255)]
        case .softSky: [Color(red: 184/255, green: 205/255, blue: 214/255), Color(red: 155/255, green: 180/255, blue: 188/255)]
        case .warmSunset: [Color(red: 205/255, green: 188/255, blue: 169/255), Color(red: 171/255, green: 158/255, blue: 149/255)]
        case .paleCream: [Color(red: 218/255, green: 214/255, blue: 201/255), Color(red: 185/255, green: 184/255, blue: 176/255)]
        case .coolGray: [Color(red: 181/255, green: 190/255, blue: 193/255), Color(red: 148/255, green: 160/255, blue: 164/255)]
        case .fadedSchoolBlue: [Color(red: 146/255, green: 170/255, blue: 179/255), Color(red: 117/255, green: 143/255, blue: 153/255)]
        }
    }
    var topLightOpacity: Double { self == .warmSunset ? 0.08 : 0.11 }
}

private struct PhysicalMetalGrain: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<28 {
                let x = CGFloat((index * 37) % 101) / 101 * size.width
                let y = CGFloat((index * 61) % 97) / 97 * size.height
                var grain = Path(); grain.move(to: CGPoint(x: x, y: y)); grain.addLine(to: CGPoint(x: x + CGFloat(index % 3), y: y + CGFloat(5 + index % 13)))
                context.stroke(grain, with: .color(index.isMultiple(of: 4) ? .white.opacity(0.025) : .black.opacity(0.018)), lineWidth: 0.35)
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
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
            Ellipse().fill(Color(red: 115/255, green: 89/255, blue: 74/255).opacity(0.08)).frame(width: 8, height: 2)
                .position(x: side + 4, y: p.size.height - floor - 1)
            Ellipse().fill(Color(red: 139/255, green: 105/255, blue: 86/255).opacity(0.06)).frame(width: 7, height: 2)
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
        .accessibilityLabel("Locker \(number), \(ownerName.isEmpty ? "My Locker" : ownerName)")
    }
}

#Preview("Locker Home") {
    LockURootView()
}
