import SwiftUI
import UIKit

struct LockerBottomShelfView: View {
    @EnvironmentObject private var appModel: LockUAppModel

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: max(7, proxy.size.width * 0.02)) {
                LockerBookSpineView(title: monthTitle, color: LockUDesign.Color.notebookPaper)
                    .frame(width: proxy.size.width * 0.33)
                    .rotationEffect(.degrees(-2))
                .onTapGesture {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    appModel.selectedTab = .book
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Open Memory Book")

                RamuneBottleView()
                    .frame(width: min(18, proxy.size.width * 0.06), height: 82)

                LockerCameraButton {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    appModel.selectedTab = .camera
                }
                .frame(width: min(96, proxy.size.width * 0.29))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                LockUDesign.Color.notebookPaper,
                                LockUDesign.Color.fadedPaper,
                                LockUDesign.Color.warmWood.opacity(0.72)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 23)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(LockUDesign.Color.lockerEdgeHighlight.opacity(0.42))
                            .frame(height: 1.5)
                    }
                    .overlay(alignment: .bottom) {
                        LinearGradient(
                            colors: [.clear, LockUDesign.Color.summerShadow.opacity(0.44)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 8)
                    }
                    .overlay(alignment: .bottomLeading) {
                        HStack {
                            Circle()
                            Spacer()
                            Circle()
                        }
                        .foregroundStyle(
                            SwiftUI.Color(red: 0.34, green: 0.29, blue: 0.26).opacity(0.065)
                        )
                        .frame(height: 3)
                        .padding(.horizontal, 7)
                        .padding(.bottom, 1)
                    }
                    .shadow(color: .black.opacity(0.38), radius: 3, y: 3)
                    .shadow(color: LockUDesign.Color.summerShadow.opacity(0.30), radius: 18, y: 12)
            }
        }
    }

    private var monthTitle: String {
        Date.now.formatted(.dateTime.month(.wide).year()).uppercased()
    }
}

struct LockerBookSpineView: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Rectangle().fill(.black.opacity(0.14)).frame(width: 5)
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.7)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Spacer(minLength: 2)
        }
        .foregroundStyle(LockUDesign.Color.ink)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, minHeight: 22, maxHeight: 28)
        .background(color, in: RoundedRectangle(cornerRadius: 3))
        .overlay(alignment: .bottom) {
            Rectangle().fill(.white.opacity(0.45)).frame(height: 2).padding(.horizontal, 5)
        }
        .shadow(color: .black.opacity(0.2), radius: 2, y: 2)
    }
}

struct LockerCameraButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                SwiftUI.Color(red: 245 / 255, green: 240 / 255, blue: 228 / 255),
                                LockUDesign.Color.fadedPaper
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .aspectRatio(1.18, contentMode: .fit)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [.black.opacity(0.13), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 19)
                            .padding(.vertical, 7)
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
                        CameraBodyMicroTexture()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                LockUDesign.Color.lockerEdgeHighlight,
                                LockUDesign.Color.summerShadow,
                                .white.opacity(0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 53, height: 53)
                    .shadow(color: .black.opacity(0.38), radius: 3, x: 2, y: 3)
                Circle()
                    .fill(LockUDesign.Color.schoolNavy.opacity(0.94))
                    .frame(width: 48, height: 48)
                    .overlay(Circle().stroke(.black.opacity(0.55), lineWidth: 1))
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(0.62),
                                SwiftUI.Color(red: 57 / 255, green: 75 / 255, blue: 92 / 255),
                                .black
                            ],
                            center: .topLeading,
                            startRadius: 2,
                            endRadius: 24
                        )
                    )
                    .frame(width: 42, height: 42)
                    .overlay(Circle().stroke(LockUDesign.Color.schoolNavy.opacity(0.72), lineWidth: 5))
                    .overlay(Circle().stroke(.white.opacity(0.38), lineWidth: 1))
                    .overlay {
                        Circle()
                            .trim(from: 0.08, to: 0.38)
                            .stroke(.white.opacity(0.72), lineWidth: 1.5)
                            .rotationEffect(.degrees(-28))
                            .padding(9)
                    }
                    .overlay {
                        Circle()
                            .fill(.black.opacity(0.72))
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(.white.opacity(0.16)))
                    }
                    .overlay {
                        Circle()
                            .trim(from: 0.57, to: 0.78)
                            .stroke(
                                LinearGradient(
                                    colors: [.green.opacity(0.54), .purple.opacity(0.42)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 2
                            )
                            .padding(12)
                    }
                    .overlay {
                        Canvas { context, size in
                            for index in 0..<5 {
                                let point = CGPoint(
                                    x: size.width * (0.34 + CGFloat(index * 11 % 37) / 100),
                                    y: size.height * (0.31 + CGFloat(index * 17 % 39) / 100)
                                )
                                context.fill(
                                    Path(ellipseIn: CGRect(x: point.x, y: point.y, width: 0.8, height: 0.8)),
                                    with: .color(.white.opacity(0.34))
                                )
                            }
                        }
                    }
                Circle()
                    .fill(LockUDesign.Color.sunsetPeach)
                    .frame(width: 9, height: 9)
                    .offset(x: 24, y: -20)
                Capsule()
                    .fill(LockUDesign.Color.ink.opacity(0.7))
                    .frame(width: 18, height: 5)
                    .offset(x: -22, y: -23)
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle().fill(LockUDesign.Color.schoolNavy.opacity(0.62)).frame(width: 1.5, height: 1.5)
                    }
                }
                .offset(x: -22, y: -14)
                Text("LU")
                    .font(.system(size: 6, weight: .bold, design: .rounded))
                    .foregroundStyle(LockUDesign.Color.schoolNavy.opacity(0.62))
                    .offset(x: -25, y: 19)
                ForEach([-1.0, 1.0], id: \.self) { direction in
                    Circle()
                        .fill(LockUDesign.Color.schoolNavy.opacity(0.55))
                        .frame(width: 2, height: 2)
                        .offset(x: direction * 35, y: 25)
                }
            }
            .shadow(color: .black.opacity(0.38), radius: 3, y: 3)
            .shadow(color: LockUDesign.Color.summerShadow.opacity(0.22), radius: 15, y: 9)
        }
        .buttonStyle(LockerPressStyle())
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("Camera")
        .accessibilityHint("Opens Camera tab")
    }
}

private struct CameraBodyMicroTexture: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<26 {
                let x = CGFloat((index * 29) % 97) / 97 * size.width
                let y = CGFloat((index * 53) % 89) / 89 * size.height
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 0.7, height: 0.7)),
                    with: .color(index.isMultiple(of: 3) ? .white.opacity(0.15) : .black.opacity(0.055))
                )
            }
        }
        .allowsHitTesting(false)
    }
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
