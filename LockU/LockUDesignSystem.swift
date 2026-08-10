import SwiftUI

enum LockUDesign {
    enum LockerSurfaceAge: String, Codable, CaseIterable {
        case initial, oneMonth, threeMonths, sixMonths, oneYear

        var wearOpacity: Double {
            switch self {
            case .initial: 0.02
            case .oneMonth: 0.03
            case .threeMonths: 0.045
            case .sixMonths: 0.055
            case .oneYear: 0.07
            }
        }

        var showsOxidation: Bool { self == .sixMonths || self == .oneYear }
    }
    enum Color {
        static let summerSkyTop = SwiftUI.Color(red: 112 / 255, green: 189 / 255, blue: 235 / 255)
        static let summerSkyMiddle = SwiftUI.Color(red: 191 / 255, green: 230 / 255, blue: 247 / 255)
        static let summerSkyBottom = SwiftUI.Color(red: 247 / 255, green: 235 / 255, blue: 213 / 255)
        static let cloudWhite = SwiftUI.Color(red: 1.00, green: 0.99, blue: 0.96)
        static let sunlight = SwiftUI.Color(red: 1, green: 216 / 255, blue: 144 / 255)
        static let worldSkyReflection = SwiftUI.Color(red: 169 / 255, green: 214 / 255, blue: 239 / 255)
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
        static let lockerSilver = SwiftUI.Color(red: 135 / 255, green: 146 / 255, blue: 150 / 255)
        static let midMetal = SwiftUI.Color(red: 104 / 255, green: 115 / 255, blue: 120 / 255)
        static let deepMetal = SwiftUI.Color(red: 66 / 255, green: 76 / 255, blue: 80 / 255)
        static let darkCavity = SwiftUI.Color(red: 48 / 255, green: 56 / 255, blue: 59 / 255)
        static let lockerBody = lockerSilver
        static let lockerBodyLight = SwiftUI.Color(red: 174 / 255, green: 183 / 255, blue: 186 / 255)
        static let lockerEdge = deepMetal
        static let lockerInteriorSoft = SwiftUI.Color(red: 137 / 255, green: 146 / 255, blue: 151 / 255)
        static let lockerInteriorBack = SwiftUI.Color(red: 115 / 255, green: 124 / 255, blue: 128 / 255)
        static let shelfWarm = SwiftUI.Color(red: 225 / 255, green: 217 / 255, blue: 193 / 255)
        static let paper = SwiftUI.Color(red: 248 / 255, green: 244 / 255, blue: 232 / 255)
    }

    enum Typography {
        static let largeTitle = Font.system(size: 30, weight: .bold)
        static let screenTitle = Font.system(size: 24, weight: .bold)
        static let sectionTitle = Font.system(size: 18, weight: .semibold)
        static let body = Font.system(size: 15, weight: .regular)
        static let bodyEmphasized = Font.system(size: 15, weight: .semibold)
        static let caption = Font.system(size: 12, weight: .medium)
        static let microLabel = Font.system(size: 10, weight: .medium)
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

enum WorldTimeOfDay: String, CaseIterable, Sendable {
    case morningClear, aoharuBlue, afterSchool, goldenSunset, blueHour, quietNight
}

enum WorldWeather: String, CaseIterable, Sendable {
    case sunny, cloudy, rain, afterRain, sunset
}

struct WorldProfile: Sendable {
    let time: WorldTimeOfDay
    let weather: WorldWeather
    let skyStops: [Color]
    let sunlight: Color
    let sunlightOpacity: Double
    let hazeOpacity: Double
    let cloudTint: Color
    let ambientReflection: Color

    static let afterSchool = WorldProfile(
        time: .afterSchool,
        weather: .sunny,
        skyStops: [
            Color(red: 111/255, green: 174/255, blue: 234/255),
            Color(red: 143/255, green: 196/255, blue: 238/255),
            Color(red: 173/255, green: 216/255, blue: 244/255),
            Color(red: 203/255, green: 230/255, blue: 247/255),
            Color(red: 228/255, green: 242/255, blue: 250/255)
        ],
        sunlight: Color(red: 1, green: 247/255, blue: 222/255),
        sunlightOpacity: 0.18,
        hazeOpacity: 0.045,
        cloudTint: Color(red: 245/255, green: 250/255, blue: 1),
        ambientReflection: Color(red: 169/255, green: 214/255, blue: 239/255)
    )
}

struct SummerSkyBackground: View {
    let profile: WorldProfile
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drifting = false
    @State private var breathing = false

    init(profile: WorldProfile = .afterSchool) { self.profile = profile }

    var body: some View {
        ZStack {
            WorldSkyBase(profile: profile)
            WorldCloudLayer(profile: profile, drifting: drifting)
            WorldSunlightLayer(profile: profile, breathing: breathing)
            WorldAtmosphericHaze(profile: profile, breathing: breathing)
            WorldAmbientReflection(profile: profile)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 52).repeatForever(autoreverses: true)) { drifting = true }
            withAnimation(.easeInOut(duration: 23).repeatForever(autoreverses: true)) { breathing = true }
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

private struct WorldSkyBase: View {
    let profile: WorldProfile
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(stops: [
                    .init(color: profile.skyStops[0], location: 0), .init(color: profile.skyStops[1], location: 0.28),
                    .init(color: profile.skyStops[2], location: 0.55), .init(color: profile.skyStops[3], location: 0.78),
                    .init(color: profile.skyStops[4], location: 1)
                ], startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [.white.opacity(0.085), profile.skyStops[3].opacity(0.035), .clear], center: UnitPoint(x: 0.5, y: 0.82), startRadius: 10, endRadius: proxy.size.width)
            }
        }
    }
}

private struct WorldCloudLayer: View {
    let profile: WorldProfile
    let drifting: Bool
    var body: some View {
        GeometryReader { p in
            ZStack {
                NaturalCloud().fill(profile.cloudTint.opacity(0.52)).frame(width: 260, height: 92)
                    .overlay(NaturalCloud().fill(Color(red: 187/255, green: 214/255, blue: 232/255).opacity(0.10)))
                    .blur(radius: 3.5).position(x: -14 + (drifting ? 19 : 0), y: p.size.height * 0.20)
                NaturalCloud().fill(.white.opacity(0.46)).frame(width: 190, height: 66).blur(radius: 4)
                    .scaleEffect(x: -1, y: 1).position(x: p.size.width + 12 + (drifting ? -14 : 0), y: p.size.height * 0.36)
                NaturalCloud().fill(profile.cloudTint.opacity(0.30)).frame(width: 145, height: 45).blur(radius: 5)
                    .position(x: p.size.width * 0.12 + (drifting ? 11 : 0), y: p.size.height * 0.74)
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

private struct NaturalCloud: Shape {
    func path(in r: CGRect) -> Path { Path { p in
        p.move(to: CGPoint(x: 0, y: r.height * 0.70))
        p.addCurve(to: CGPoint(x: r.width * 0.24, y: r.height * 0.42), control1: CGPoint(x: r.width * 0.07, y: r.height * 0.54), control2: CGPoint(x: r.width * 0.15, y: r.height * 0.56))
        p.addCurve(to: CGPoint(x: r.width * 0.55, y: r.height * 0.38), control1: CGPoint(x: r.width * 0.34, y: r.height * 0.05), control2: CGPoint(x: r.width * 0.47, y: r.height * 0.18))
        p.addCurve(to: CGPoint(x: r.width, y: r.height * 0.62), control1: CGPoint(x: r.width * 0.72, y: r.height * 0.20), control2: CGPoint(x: r.width * 0.85, y: r.height * 0.54))
        p.addCurve(to: CGPoint(x: 0, y: r.height * 0.70), control1: CGPoint(x: r.width * 0.72, y: r.height), control2: CGPoint(x: r.width * 0.23, y: r.height * 0.91)); p.closeSubpath()
    } }
}

private struct WorldSunlightLayer: View {
    let profile: WorldProfile; let breathing: Bool
    var body: some View { GeometryReader { p in
        RadialGradient(colors: [profile.sunlight.opacity(profile.sunlightOpacity), profile.sunlight.opacity(0.055), .clear], center: UnitPoint(x: 0.02, y: 0.02), startRadius: 4, endRadius: min(340, p.size.width * 0.9))
            .brightness(breathing ? 0.012 : 0).scaleEffect(breathing ? 1.02 : 1, anchor: .topLeading)
    }.allowsHitTesting(false) }
}

private struct WorldAtmosphericHaze: View {
    let profile: WorldProfile; let breathing: Bool
    var body: some View {
        LinearGradient(colors: [.white.opacity(0.01), Color(red: 225/255, green: 241/255, blue: 250/255).opacity(breathing ? profile.hazeOpacity + 0.01 : profile.hazeOpacity)], startPoint: .top, endPoint: .bottom)
            .blendMode(.screen).allowsHitTesting(false)
    }
}

private struct WorldAmbientReflection: View {
    let profile: WorldProfile
    var body: some View { LinearGradient(colors: [profile.ambientReflection.opacity(0.025), .clear], startPoint: .topLeading, endPoint: .center).blendMode(.screen).allowsHitTesting(false) }
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
