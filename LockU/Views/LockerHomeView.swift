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
            let widthRatio = isOpen ? 0.88 : 0.86
            let maxWidth: CGFloat = LockUDesign.lockerMaxWidth
            let maxHeight: CGFloat = isOpen ? 680 : 640
            let lockerWidth = min(proxy.size.width * widthRatio, maxWidth)
            let lockerHeight = min(lockerWidth / 0.58, maxHeight, proxy.size.height - 116)

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
            let frameWidth = max(14.0, min(18.0, proxy.size.width * 0.045))
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
                    metalBar.frame(height: frameWidth)
                }

                HStack(spacing: 0) {
                    metalBar.frame(width: frameWidth)
                    Spacer(minLength: 0)
                    metalBar.frame(width: frameWidth)
                }
                .padding(.top, topHeight - 1)

                LockerNamePlateView(
                    number: settingsRepository.settings.lockerNumber,
                    ownerName: settingsRepository.settings.ownerName
                )
                .frame(width: min(118, proxy.size.width * 0.29))
                .position(x: frameWidth + min(66, proxy.size.width * 0.17), y: topHeight / 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(
                        LinearGradient(
                            colors: [
                                LockUDesign.Color.lockerEdgeHighlight.opacity(0.72),
                                .white.opacity(0.12),
                                LockUDesign.Color.lockerSummerBlueDark.opacity(0.74)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
            .shadow(color: .black.opacity(0.18), radius: 4, y: 3)
            .shadow(color: LockUDesign.Color.summerShadow.opacity(0.18), radius: 18, y: 9)
        }
    }

    private var metalBar: some View {
        LinearGradient(
            colors: [
                LockUDesign.Color.lockerSummerBlueLight,
                LockUDesign.Color.lockerSummerBlue,
                LockUDesign.Color.lockerSummerBlueDark
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            LinearGradient(
                colors: [
                    LockUDesign.Color.lockerEdgeHighlight.opacity(0.34),
                    .clear,
                    LockUDesign.Color.sunlight.opacity(0.11)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func topFrame(height: CGFloat) -> some View {
        metalBar
            .frame(height: height)
            .overlay(alignment: .bottom) {
                Rectangle().fill(LockUDesign.Color.lockerEdge.opacity(0.25)).frame(height: 1)
            }
    }
}

private struct LockerInteriorSurface: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        LockUDesign.Color.lockerInteriorSoft,
                        LockUDesign.Color.lockerInteriorBack
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                LinearGradient(
                    colors: [
                        .white.opacity(0.12),
                        .clear,
                        LockUDesign.Color.lockerInteriorBack.opacity(0.34)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(InteriorPerspectiveShape())
                .padding(6)
                LinearGradient(
                    colors: [.white.opacity(0.06), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                LockerInteriorContent()
                    .shadow(color: .black.opacity(0.16), radius: 2)
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(.black.opacity(0.35), lineWidth: 3)
            }
            .shadow(color: .black.opacity(0.32), radius: 3, y: 2)
            .shadow(color: LockUDesign.Color.summerShadow.opacity(0.22), radius: 16, y: 8)
        }
    }
}

private struct InteriorPerspectiveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - 9, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + 9, y: rect.maxY))
        path.closeSubpath()
        return path
    }
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
        .background(
            LockUDesign.Color.notebookPaper,
            in: RoundedRectangle(cornerRadius: 3)
        )
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.black.opacity(0.08)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Locker \(number), \(ownerName.isEmpty ? "My Locker" : ownerName)")
    }
}

#Preview("Locker Home") {
    LockURootView()
}
