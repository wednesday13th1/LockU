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

                Spacer(minLength: max(10, proxy.size.width * 0.05))

                LockerCameraButton {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    appModel.selectedTab = .camera
                }
                .frame(width: min(96, proxy.size.width * 0.29))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 15)
            .overlay(alignment: .bottom) {
                PhysicalMetalShelf()
            }
        }
    }

    private var monthTitle: String {
        Date.now.formatted(.dateTime.month(.wide).year()).uppercased()
    }
}

private struct PhysicalMetalShelf: View {
    var body: some View {
        VStack(spacing: 0) {
            TrapezoidShelfTop()
                .fill(Color(red: 174/255, green: 180/255, blue: 181/255))
                .frame(height: 7)
                .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.40)).frame(height: 0.7).padding(.horizontal, 2) }
            Rectangle()
                .fill(LinearGradient(colors: [Color(red: 126/255, green: 134/255, blue: 136/255), Color(red: 116/255, green: 124/255, blue: 126/255)], startPoint: .top, endPoint: .bottom))
                .frame(height: 11)
            Rectangle().fill(Color(red: 86/255, green: 93/255, blue: 96/255)).frame(height: 5)
        }
        .overlay { HStack { Rectangle().fill(.black.opacity(0.25)).frame(width: 2); Spacer(); Rectangle().fill(.black.opacity(0.25)).frame(width: 2) } }
        .shadow(color: .black.opacity(0.28), radius: 12, y: 9)
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
                .font(.system(size: 9, weight: .bold))
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
                RoundedRectangle(cornerRadius: 5)
                    .fill(LinearGradient(colors: [Color(red: 0.82, green: 0.81, blue: 0.77), Color(red: 0.78, green: 0.77, blue: 0.74), Color(red: 0.55, green: 0.55, blue: 0.53)], startPoint: .topLeading, endPoint: .bottomTrailing))
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
                        CameraBodyMicroTexture()
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                ZStack {
                    Circle().fill(LinearGradient(colors: [.white.opacity(0.75), Color(white: 0.55), Color(white: 0.78)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 52, height: 52)
                    Circle().fill(Color(red: 21/255, green: 23/255, blue: 25/255)).frame(width: 44, height: 44)
                    Circle().fill(RadialGradient(colors: [Color(red: 36/255, green: 58/255, blue: 68/255), Color(red: 16/255, green: 24/255, blue: 32/255), .black], center: .topLeading, startRadius: 1, endRadius: 21)).frame(width: 35, height: 35)
                    Circle().fill(.black.opacity(0.88)).frame(width: 15, height: 15)
                    Circle().fill(.white.opacity(0.62)).frame(width: 4, height: 2).offset(x: -8, y: -9).blur(radius: 0.3)
                }.shadow(color: .black.opacity(0.42), radius: 3, x: 2, y: 4)
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
            .shadow(color: .black.opacity(0.26), radius: 1, y: 1)
            .shadow(color: .black.opacity(0.20), radius: 6, y: 5)
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
