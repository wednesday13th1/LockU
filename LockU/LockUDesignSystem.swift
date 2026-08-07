import SwiftUI

enum LockUDesign {
    enum Color {
        static let summerSkyTop = SwiftUI.Color(red: 126 / 255, green: 207 / 255, blue: 1)
        static let summerSkyMiddle = SwiftUI.Color(red: 0.65, green: 0.86, blue: 0.98)
        static let summerSkyBottom = SwiftUI.Color(red: 0.93, green: 0.98, blue: 1.00)
        static let cloudWhite = SwiftUI.Color(red: 1.00, green: 0.99, blue: 0.96)
        static let sunlight = SwiftUI.Color(red: 1, green: 216 / 255, blue: 144 / 255)
        static let sunsetPeach = SwiftUI.Color(red: 1.00, green: 0.72, blue: 0.55)
        static let ramuneBlue = SwiftUI.Color(red: 105 / 255, green: 183 / 255, blue: 217 / 255)
        static let schoolNavy = SwiftUI.Color(red: 0.18, green: 0.31, blue: 0.44)
        static let lockerSummerBlue = SwiftUI.Color(red: 111 / 255, green: 145 / 255, blue: 163 / 255)
        static let lockerSummerBlueLight = SwiftUI.Color(red: 168 / 255, green: 199 / 255, blue: 213 / 255)
        static let lockerSummerBlueDark = SwiftUI.Color(red: 79 / 255, green: 103 / 255, blue: 118 / 255)
        static let lockerEdgeHighlight = SwiftUI.Color(red: 207 / 255, green: 228 / 255, blue: 237 / 255)
        static let lockerWornEdge = SwiftUI.Color(red: 71 / 255, green: 95 / 255, blue: 111 / 255)
        static let notebookPaper = SwiftUI.Color(red: 1, green: 248 / 255, blue: 237 / 255)
        static let summerShadow = SwiftUI.Color(red: 90 / 255, green: 109 / 255, blue: 121 / 255)
        static let warmWood = SwiftUI.Color(red: 212 / 255, green: 184 / 255, blue: 138 / 255)
        static let fadedPaper = SwiftUI.Color(red: 0.96, green: 0.93, blue: 0.83)
        static let softInk = SwiftUI.Color(red: 0.12, green: 0.20, blue: 0.26)
        static let softInkSecondary = SwiftUI.Color(red: 0.38, green: 0.48, blue: 0.54)
        static let glassWhite = SwiftUI.Color.white.opacity(0.72)
        static let cream = SwiftUI.Color(red: 0.96, green: 0.93, blue: 0.86)
        static let dustBlue = SwiftUI.Color(red: 0.48, green: 0.60, blue: 0.68)
        static let lavender = SwiftUI.Color(red: 0.75, green: 0.72, blue: 0.82)
        static let softOrange = SwiftUI.Color(red: 0.84, green: 0.56, blue: 0.38)
        static let ink = SwiftUI.Color(red: 0.15, green: 0.17, blue: 0.18)
        static let skyTop = SwiftUI.Color(red: 0.66, green: 0.76, blue: 0.82)
        static let skyBottom = SwiftUI.Color(red: 0.88, green: 0.84, blue: 0.77)
        static let lockerBlue = SwiftUI.Color(red: 0.42, green: 0.55, blue: 0.63)
        static let lockerBlueDark = SwiftUI.Color(red: 0.22, green: 0.31, blue: 0.37)
        static let lockerInterior = SwiftUI.Color(red: 0.18, green: 0.25, blue: 0.29)
        static let metalHighlight = SwiftUI.Color.white.opacity(0.28)
        static let paperCream = SwiftUI.Color(red: 0.97, green: 0.94, blue: 0.86)
        static let mutedLavender = SwiftUI.Color(red: 0.66, green: 0.63, blue: 0.74)
        static let shelfCream = SwiftUI.Color(red: 0.82, green: 0.79, blue: 0.70)
        static let warmLight = SwiftUI.Color(red: 1.0, green: 0.81, blue: 0.49)
        static let cameraCream = SwiftUI.Color(red: 0.94, green: 0.91, blue: 0.83)
        static let backgroundPrimary = SwiftUI.Color(red: 246 / 255, green: 243 / 255, blue: 237 / 255)
        static let backgroundSecondary = SwiftUI.Color(red: 233 / 255, green: 239 / 255, blue: 242 / 255)
        static let surface = SwiftUI.Color(red: 1, green: 0.995, blue: 0.985)
        static let surfaceMuted = SwiftUI.Color(red: 241 / 255, green: 240 / 255, blue: 236 / 255)
        static let surfaceTranslucent = SwiftUI.Color.white.opacity(0.68)
        static let textPrimary = SwiftUI.Color(red: 40 / 255, green: 47 / 255, blue: 51 / 255)
        static let textSecondary = SwiftUI.Color(red: 102 / 255, green: 115 / 255, blue: 124 / 255)
        static let accent = SwiftUI.Color(red: 125 / 255, green: 171 / 255, blue: 201 / 255)
        static let accentDark = SwiftUI.Color(red: 86 / 255, green: 133 / 255, blue: 163 / 255)
        static let accentSoft = SwiftUI.Color(red: 215 / 255, green: 229 / 255, blue: 237 / 255)
        static let accentPressed = accentDark
        static let warmAccent = SwiftUI.Color(red: 242 / 255, green: 167 / 255, blue: 122 / 255)
        static let warningBackground = SwiftUI.Color(red: 252 / 255, green: 237 / 255, blue: 228 / 255)
        static let warningBorder = SwiftUI.Color(red: 224 / 255, green: 139 / 255, blue: 105 / 255)
        static let success = SwiftUI.Color(red: 124 / 255, green: 164 / 255, blue: 153 / 255)
        static let warning = SwiftUI.Color(red: 0.73, green: 0.48, blue: 0.32)
        static let cameraOverlay = SwiftUI.Color.black.opacity(0.32)
        static let cameraBlack = SwiftUI.Color(red: 17 / 255, green: 19 / 255, blue: 21 / 255)
        static let pageBackground = SwiftUI.Color(red: 242 / 255, green: 246 / 255, blue: 247 / 255)
        static let lockerBody = lockerSummerBlue
        static let lockerBodyLight = lockerSummerBlueLight
        static let lockerEdge = lockerWornEdge
        static let lockerInteriorSoft = SwiftUI.Color(red: 0.29, green: 0.38, blue: 0.43)
        static let lockerInteriorBack = SwiftUI.Color(red: 53 / 255, green: 72 / 255, blue: 83 / 255)
        static let shelfWarm = SwiftUI.Color(red: 225 / 255, green: 217 / 255, blue: 193 / 255)
        static let paper = SwiftUI.Color(red: 248 / 255, green: 244 / 255, blue: 232 / 255)
    }

    enum Typography {
        static let largeTitle = Font.system(size: 30, weight: .bold, design: .rounded)
        static let screenTitle = Font.system(size: 24, weight: .bold, design: .rounded)
        static let sectionTitle = Font.system(size: 18, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 15, weight: .regular, design: .rounded)
        static let bodyEmphasized = Font.system(size: 15, weight: .semibold, design: .rounded)
        static let caption = Font.system(size: 12, weight: .medium, design: .rounded)
        static let microLabel = Font.system(size: 10, weight: .medium, design: .rounded)
    }

    enum Spacing {
        static let s4: CGFloat = 4
        static let s8: CGFloat = 8
        static let s12: CGFloat = 12
        static let s16: CGFloat = 16
        static let s20: CGFloat = 20
        static let s24: CGFloat = 24
        static let s32: CGFloat = 32
        static let xxSmall: CGFloat = 4
        static let xSmall: CGFloat = 8
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 20
        static let xLarge: CGFloat = 24
        static let xxLarge: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 28
    }

    enum Shadow {
        static let soft = SwiftUI.Color.black.opacity(0.14)
        static let floating = SwiftUI.Color.black.opacity(0.24)
        static let inner = SwiftUI.Color.black.opacity(0.3)
        static let deep = SwiftUI.Color.black.opacity(0.28)
    }

    enum Motion {
        static let quick = Animation.easeOut(duration: 0.22)
        static let softSpring = Animation.spring(response: 0.45, dampingFraction: 0.86)
        static let door = Animation.interactiveSpring(
            response: 0.55,
            dampingFraction: 0.86,
            blendDuration: 0.15
        )
        static let soft = Animation.easeOut(duration: 0.28)
    }

    static let contentMaxWidth: CGFloat = 760
    static let lockerMaxWidth: CGFloat = 430
    static let bottomBarHeight: CGFloat = 76
    static let shadow = SwiftUI.Color.black.opacity(0.12)
}

extension SwiftUI.Color {
    init(lockUHex hex: String, fallback: SwiftUI.Color = LockUDesign.Color.lockerBlue) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else {
            self = fallback
            return
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

struct SummerSkyBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drifting = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    LockUDesign.Color.summerSkyTop,
                    LockUDesign.Color.summerSkyMiddle,
                    LockUDesign.Color.summerSkyBottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            SummerCloudLayer(scale: 1.2, opacity: 0.72)
                .offset(x: drifting ? 12 : -12, y: -150)
            SummerCloudLayer(scale: 0.78, opacity: 0.42)
                .offset(x: drifting ? -18 : 8, y: 100)
            SunlightOverlay()
            FloatingLightParticles()
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 24).repeatForever(autoreverses: true)) {
                drifting = true
            }
        }
    }
}

struct SkyBackground: View {
    var body: some View { SummerSkyBackground() }
}

struct LockerSceneBackground: View {
    var body: some View {
        SummerSkyBackground()
    }
}

struct SummerCloudLayer: View {
    let scale: CGFloat
    let opacity: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Ellipse().fill(LockUDesign.Color.cloudWhite.opacity(opacity * 0.42))
                    .frame(width: 340, height: 100).blur(radius: 18)
                    .position(x: proxy.size.width * 0.14, y: proxy.size.height * 0.38)
                Ellipse().fill(LockUDesign.Color.cloudWhite.opacity(opacity))
                    .frame(width: 220, height: 125).blur(radius: 7)
                    .position(x: proxy.size.width * 0.22, y: proxy.size.height * 0.33)
                Ellipse().fill(LockUDesign.Color.cloudWhite.opacity(opacity * 0.85))
                    .frame(width: 180, height: 150).blur(radius: 9)
                    .position(x: proxy.size.width * 0.05, y: proxy.size.height * 0.29)
                Ellipse().fill(LockUDesign.Color.summerSkyMiddle.opacity(opacity * 0.28))
                    .frame(width: 360, height: 70).blur(radius: 18)
                    .position(x: proxy.size.width * 0.15, y: proxy.size.height * 0.42)
            }
            .scaleEffect(scale)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct SunlightOverlay: View {
    var body: some View {
        RadialGradient(
            colors: [
                LockUDesign.Color.sunlight.opacity(0.46),
                LockUDesign.Color.cloudWhite.opacity(0.18),
                .clear
            ],
            center: .topLeading,
            startRadius: 4,
            endRadius: 390
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct FloatingLightParticles: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<21 {
                let x = CGFloat((index * 47) % 101) / 101 * size.width
                let y = CGFloat((index * 83) % 97) / 97 * size.height
                let diameter = CGFloat(1 + index % 3)
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)),
                    with: .color(.white.opacity(0.28))
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct SummerGlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
            .background(LockUDesign.Color.glassWhite, in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.62)))
            .shadow(color: LockUDesign.Color.schoolNavy.opacity(0.08), radius: 24, y: 11)
    }
}

struct LockUPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LockUDesign.Typography.bodyEmphasized)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 16)
            .background(
                configuration.isPressed
                    ? LockUDesign.Color.lockerSummerBlue
                    : LockUDesign.Color.ramuneBlue,
                in: RoundedRectangle(cornerRadius: 18)
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct LockUSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LockUDesign.Typography.bodyEmphasized)
            .foregroundStyle(LockUDesign.Color.schoolNavy)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 16)
            .background(
                LockUDesign.Color.glassWhite,
                in: RoundedRectangle(cornerRadius: 18)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.white.opacity(0.65))
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct LockUIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 44, height: 44)
            .foregroundStyle(LockUDesign.Color.textPrimary)
            .background(.thinMaterial, in: Circle())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct LockUCameraControlStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 46, height: 46)
            .foregroundStyle(.white)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.22)))
            .background(LockUDesign.Color.cameraOverlay, in: Circle())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct LockUDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LockUDesign.Typography.bodyEmphasized)
            .foregroundStyle(.red.opacity(0.82))
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }
}
