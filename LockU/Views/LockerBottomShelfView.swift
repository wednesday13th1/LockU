import SwiftUI
import UIKit

struct LockerBottomShelfView: View {
    var body: some View {
        GeometryReader { proxy in
            let shelfTopY = proxy.size.height - 21

            ZStack(alignment: .topLeading) {
                LockerShelfObjectLayer()
                    .frame(width: proxy.size.width, height: shelfTopY)
                    .zIndex(50)

                PhysicalMetalShelf()
                    .frame(width: proxy.size.width, height: 21)
                    .position(x: proxy.size.width * 0.5, y: shelfTopY + 10.5)
                    .zIndex(40)
            }
            .accessibilityElement(children: .contain)
        }
    }
}

private struct LockerShelfObjectLayer: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let baseline = height - 1

            ZStack(alignment: .topLeading) {
                LockerBookStack()
                    .frame(width: width * 0.29, height: min(height * 0.90, 76))
                    .position(x: width * 0.16, y: baseline - min(height * 0.90, 76) * 0.5)

                LockerSmallBottle()
                    .frame(width: width * 0.075, height: min(height * 0.62, 49))
                    .position(x: width * 0.49, y: baseline - min(height * 0.62, 49) * 0.5)

                LockerSmallCase()
                    .frame(width: width * 0.13, height: min(height * 0.31, 25))
                    .position(x: width * 0.57, y: baseline - min(height * 0.31, 25) * 0.5)

                LockerFabricPouch()
                    .frame(width: width * 0.25, height: min(height * 0.36, 29))
                    .position(x: width * 0.81, y: baseline - min(height * 0.36, 29) * 0.5)
            }
        }
        .accessibilityLabel("教科書、ボトル、小物ケース、布のポーチ")
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
