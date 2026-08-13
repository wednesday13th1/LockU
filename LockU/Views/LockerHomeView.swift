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
            let maxHeight: CGFloat = isOpen ? 680 : 664
            let lockerHeight = min(maxHeight, proxy.size.height - 60)
            let lockerWidth = min(
                proxy.size.width * 0.93,
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

                Spacer(minLength: 8)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .opacity(appeared ? 1 : 0.65)
            .offset(y: appeared ? 0 : 8)
            .onAppear {
                if !appeared { appModel.markLockerFirstRender() }
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
                .font(.system(size: 21, weight: .semibold))
                .tracking(-0.2)
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
            .foregroundStyle(LockUSceneTokens.Material.lockerInk.opacity(0.84))
            .accessibilityLabel("Locker menu")
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .foregroundStyle(LockUSceneTokens.Material.lockerInk.opacity(0.92))
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
    @EnvironmentObject private var settingsRepository: LockerSettingsRepository

    var body: some View {
        GeometryReader { proxy in
            let side = proxy.size.width * LockUSceneTokens.Home.sideWallFraction
            let ceiling = max(16, min(22, proxy.size.height * 0.032))
            let floor = max(14, proxy.size.height * 0.045)
            let shelfLip = min(8, floor * 0.36)
            let aging = LockUDesign.LockerSurfaceAge.threeMonths.agingProfile
            ZStack {
                LockerInteriorBackground(style: settingsRepository.settings.appearance.backgroundStyle)
                    .clipShape(BackWallShape(side: side, ceiling: ceiling, floor: floor))
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
                InteriorHardwareOverlay(side: side, ceiling: ceiling, floor: floor)

                LockerInteriorContent()
                    .padding(.horizontal, side + 1)
                    .padding(.top, ceiling)
                    .padding(.bottom, floor)

                InteriorAmbientOcclusion(side: side, ceiling: ceiling, floor: floor)
                LinearGradient(colors: [.black.opacity(0.12), .clear, .white.opacity(0.08), .clear, .black.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .allowsHitTesting(false)
            }
            .background(LockUSceneTokens.Material.lockerMetalShadow)
            .overlay(Rectangle().strokeBorder(LockUSceneTokens.Material.lockerInk.opacity(0.12), lineWidth: 1))
            .shadow(color: LockUSceneTokens.Shadow.structural, radius: 5, x: 1, y: 2)
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
        .accessibilityLabel("Locker \(number), \(ownerName.isEmpty ? "My Locker" : ownerName)")
    }
}

#Preview("Locker Home") {
    LockURootView()
}
