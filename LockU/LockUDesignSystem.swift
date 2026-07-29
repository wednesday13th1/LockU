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
    }

    enum Spacing {
        static let xSmall: CGFloat = 6
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 20
        static let large: CGFloat = 30
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

    static let contentMaxWidth: CGFloat = 560
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
        LinearGradient(
            colors: [LockUDesign.Color.skyTop, LockUDesign.Color.skyBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

struct LockerSceneBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                LockUDesign.Color.lockerBlueDark.opacity(0.92),
                LockUDesign.Color.skyBottom.opacity(0.72)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
