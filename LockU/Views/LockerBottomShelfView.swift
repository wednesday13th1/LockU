import SwiftUI
import UIKit

struct LockerBottomShelfView: View {
    @EnvironmentObject private var appModel: LockUAppModel

    var body: some View {
        GeometryReader { proxy in
            PhysicalMetalShelf().frame(maxHeight: .infinity, alignment: .bottom)
        }
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
        .accessibilityLabel("Camera")
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
