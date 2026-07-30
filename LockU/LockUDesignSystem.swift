import SwiftUI

enum LockUDesign {
    enum Color {
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
    }

    enum Typography {
        static let largeTitle = Font.system(size: 28, weight: .bold)
        static let screenTitle = Font.system(size: 22, weight: .bold)
        static let sectionTitle = Font.system(size: 17, weight: .semibold)
        static let body = Font.system(size: 15)
        static let bodyEmphasized = Font.system(size: 15, weight: .semibold)
        static let caption = Font.system(size: 12)
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
    static let lockerMaxWidth: CGFloat = 560
    static let bottomBarHeight: CGFloat = 72
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

struct SkyBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    LockUDesign.Color.backgroundSecondary,
                    LockUDesign.Color.skyTop.opacity(0.72),
                    LockUDesign.Color.backgroundPrimary
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [.white.opacity(0.38), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 320
            )
            skyCloud(width: 210).offset(x: -105, y: -190)
            skyCloud(width: 170).offset(x: 125, y: -50)
            SkyNoiseOverlay().opacity(0.12)
        }
        .ignoresSafeArea()
    }

    private func skyCloud(width: CGFloat) -> some View {
        HStack(spacing: -28) {
            Circle().frame(width: width * 0.48)
            Circle().frame(width: width * 0.62)
            Circle().frame(width: width * 0.42)
        }
        .foregroundStyle(.white.opacity(0.2))
        .blur(radius: 22)
        .accessibilityHidden(true)
    }
}

struct LockerSceneBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                LockUDesign.Color.backgroundSecondary,
                LockUDesign.Color.skyTop.opacity(0.68),
                LockUDesign.Color.backgroundPrimary
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private struct SkyNoiseOverlay: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<90 {
                let x = CGFloat((index * 47) % 101) / 101 * size.width
                let y = CGFloat((index * 83) % 97) / 97 * size.height
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                    with: .color(.white.opacity(0.25))
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct LockUPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LockUDesign.Typography.bodyEmphasized)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 16)
            .background(
                configuration.isPressed
                    ? LockUDesign.Color.accentPressed
                    : LockUDesign.Color.accent,
                in: RoundedRectangle(cornerRadius: LockUDesign.Radius.medium)
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
            .foregroundStyle(LockUDesign.Color.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 16)
            .background(
                LockUDesign.Color.surface,
                in: RoundedRectangle(cornerRadius: LockUDesign.Radius.medium)
            )
            .overlay {
                RoundedRectangle(cornerRadius: LockUDesign.Radius.medium)
                    .stroke(.black.opacity(0.07))
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
