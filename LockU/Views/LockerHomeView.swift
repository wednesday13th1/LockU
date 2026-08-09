import SwiftUI

struct LockerHomeView: View {
    @EnvironmentObject private var settingsRepository: LockerSettingsRepository
    @EnvironmentObject private var appModel: LockUAppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onShare: () -> Void
    let onCode: () -> Void
    let onSettings: () -> Void
    @State private var appeared = false

    var body: some View {
        GeometryReader { proxy in
            let isOpen = appModel.lockerDoorState.isOpenOrOpening
            let maxHeight: CGFloat = isOpen ? 680 : 640
            let lockerHeight = min(maxHeight, proxy.size.height - 116)
            let lockerWidth = min(
                proxy.size.width * 0.94,
                lockerHeight * 0.62,
                LockUDesign.lockerMaxWidth * 1.08
            )

            VStack(spacing: 20) {
                LockerUtilityBar(
                    onShare: onShare,
                    onCode: onCode,
                    onSettings: onSettings
                )
                .padding(.horizontal, 16)

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
                .animation(LockUDesign.Motion.softSpring, value: isOpen)

                Spacer(minLength: 8)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .opacity(appeared ? 1 : 0.65)
            .offset(y: appeared ? 0 : 8)
            .onAppear {
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
    let onShare: () -> Void
    let onCode: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(Date.now.formatted(.dateTime.month(.abbreviated).day()))
                .font(.caption.weight(.medium))
                .foregroundStyle(LockUDesign.Color.schoolNavy)
            Spacer()
            utilityButton("Share", icon: "square.and.arrow.up", action: onShare)
            utilityButton("Locker Code", icon: "number", action: onCode)
            utilityButton("Settings", icon: "gearshape", action: onSettings)
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
        .background(.white.opacity(0.70), in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.38), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.08), radius: 18, y: 6)
    }

    private func utilityButton(
        _ label: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .frame(width: 36, height: 36)
                .background(.clear, in: Circle())
        }
        .foregroundStyle(LockUDesign.Color.schoolNavy.opacity(0.82))
        .accessibilityLabel(label)
    }
}

struct LockerFrameView: View {
    @EnvironmentObject private var settingsRepository: LockerSettingsRepository
    let lockerColor: Color

    var body: some View {
        GeometryReader { proxy in
            let frameWidth = max(15.0, min(17.0, proxy.size.width * 0.03))
            let topHeight = max(38.0, min(50.0, proxy.size.height * 0.09))

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
                .frame(width: min(118, proxy.size.width * 0.29))
                .position(x: frameWidth + min(66, proxy.size.width * 0.17), y: topHeight / 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 5))
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
            .shadow(color: .black.opacity(0.20), radius: 12, y: 9)
        }
    }

    private func layeredFrameBar(axis: Axis, reversed: Bool = false) -> some View {
        let start: UnitPoint = axis == .horizontal ? (reversed ? .bottom : .top) : (reversed ? .trailing : .leading)
        let end: UnitPoint = axis == .horizontal ? (reversed ? .top : .bottom) : (reversed ? .leading : .trailing)
        return LinearGradient(
            stops: [
                .init(color: Color(red: 109/255, green: 116/255, blue: 119/255), location: 0),
                .init(color: Color(red: 173/255, green: 179/255, blue: 181/255), location: 0.18),
                .init(color: Color(red: 205/255, green: 209/255, blue: 210/255), location: 0.55),
                .init(color: LockUDesign.Color.deepMetal, location: 0.82),
                .init(color: Color(red: 98/255, green: 105/255, blue: 108/255), location: 1)
            ], startPoint: start, endPoint: end
        )
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
    var body: some View {
        GeometryReader { proxy in
            let side = proxy.size.width * 0.075
            let ceiling = max(12, proxy.size.height * 0.035)
            let floor = max(14, proxy.size.height * 0.045)
            ZStack {
                Color(red: 169/255, green: 175/255, blue: 176/255)
                    .clipShape(BackWallShape(side: side, ceiling: ceiling, floor: floor))
                Color(red: 148/255, green: 155/255, blue: 157/255)
                    .clipShape(LeftInteriorWall(side: side, ceiling: ceiling, floor: floor))
                Color(red: 133/255, green: 141/255, blue: 144/255)
                    .clipShape(RightInteriorWall(side: side, ceiling: ceiling, floor: floor))
                Color(red: 123/255, green: 131/255, blue: 134/255)
                    .clipShape(CeilingPlane(side: side, depth: ceiling))
                Color(red: 140/255, green: 148/255, blue: 150/255)
                    .clipShape(BottomPlane(side: side, depth: floor))

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

struct LockerNamePlateView: View {
    let number: String
    let ownerName: String

    var body: some View {
        VStack(spacing: 0) {
            Text("LOCKU")
                .font(.system(size: 10, weight: .medium))
                .tracking(1.4)
            Text(number.isEmpty ? "24" : number)
                .font(.system(size: 28, weight: .semibold))
                .minimumScaleFactor(0.7)
            Text(ownerName.isEmpty ? "My Locker" : ownerName)
                .font(.system(size: 12, weight: .regular))
                .lineLimit(1)
        }
        .foregroundStyle(LockUDesign.Color.ink)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(Color(red: 247/255, green: 246/255, blue: 241/255), in: RoundedRectangle(cornerRadius: 1))
        .overlay(RoundedRectangle(cornerRadius: 1).stroke(Color(red: 199/255, green: 197/255, blue: 190/255), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.10), radius: 1, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Locker \(number), \(ownerName.isEmpty ? "My Locker" : ownerName)")
    }
}

#Preview("Locker Home") {
    LockURootView()
}
