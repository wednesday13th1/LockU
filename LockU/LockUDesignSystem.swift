import SwiftUI

enum LockUSceneTokens {
    enum Layer {
        static let environment = 0.0
        static let physical = 10.0
        static let memory = 20.0
        static let interface = 30.0
    }

    enum Weight {
        static let personalMemory = 100.0
        static let heroMemory = 90.0
        static let locker = 80.0
        static let object = 55.0
        static let environment = 45.0
        static let themeDecoration = 25.0
        static let interface = 20.0

        // Compatibility aliases. Layout and navigation remain permanent.
        static let tabBar = interface
        static let header = interface
    }

    enum Home {
        static let referenceWidth: CGFloat = 414
        static let lockerHorizontalMargin: CGFloat = 12
        static let lockerAspectRatio: CGFloat = 1.80
        static let headerHorizontalMargin: CGFloat = 20
        static let headerHeight: CGFloat = 44
        static let themeButtonTapTarget: CGFloat = 44
        static let headerToLocker: CGFloat = 18
        static let lockerToTabBar: CGFloat = 24
        static let frameThickness: ClosedRange<CGFloat> = 12...14
        static let sideWallFraction: CGFloat = 0.075
        static let memoryZoneX: ClosedRange<CGFloat> = 0.15...0.85
        static let memoryZoneY: ClosedRange<CGFloat> = 0.24...0.76
    }

    enum Material {
        static let backWall = Color(red: 151/255, green: 166/255, blue: 170/255)
        static let leftWall = Color(red: 160/255, green: 175/255, blue: 179/255)
        static let rightWall = Color(red: 140/255, green: 154/255, blue: 158/255)
        static let shelfTop = Color(red: 170/255, green: 183/255, blue: 186/255)
        static let shelfFront = Color(red: 139/255, green: 152/255, blue: 156/255)
        static let recess = Color(red: 113/255, green: 128/255, blue: 135/255)
        static let paperBase = Color(red: 247/255, green: 244/255, blue: 236/255)
        static let paperHighlight = Color(red: 1, green: 253/255, blue: 247/255)
        static let paperShadow = Color(red: 216/255, green: 211/255, blue: 201/255)
    }

    enum Shadow {
        static let structural = Color.black.opacity(0.18)
        static let object = Color.black.opacity(0.20)
        static let paper = Color.black.opacity(0.14)
        static let contact = Color.black.opacity(0.26)
    }
}

// MARK: - Design system responsibility layers

enum LockUDesignLayer: Sendable {
    case permanent
    case personal
    case emotional
    case temporal
}

enum LockUTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case aoharu, sweet, dreamy, quiet, chaotic
    var id: String { rawValue }
}

struct LockUThemeSelection: Codable, Equatable, Sendable {
    var preferredTheme: LockUTheme
    var todayTheme: LockUTheme?
    var todayIdentifier: String?

    init(preferredTheme: LockUTheme = .aoharu, todayTheme: LockUTheme? = nil, todayIdentifier: String? = nil) {
        self.preferredTheme = preferredTheme
        self.todayTheme = todayTheme
        self.todayIdentifier = todayIdentifier
    }

    func resolvedTheme(for dayIdentifier: String) -> LockUTheme {
        todayIdentifier == dayIdentifier ? todayTheme ?? preferredTheme : preferredTheme
    }
}

enum LockUMicroDecoration: String, Codable, CaseIterable, Sendable {
    case dateStamp, tapeAccent, tinyHandwriting, tinyRibbon, tinyFlower, handwrittenHeart, tinyStar, dust, softGlow
    case scribble, rec, pixelMark, tinyPixelHeart, roughUnderline, smallArrow, handwrittenLOL
}

struct LockUDecorationProfile: Equatable, Sendable {
    let maximumCount: Int
    let allowsStars: Bool
    let allowsRibbon: Bool
    let allowsFlower: Bool
    let allowsHandwrittenHeart: Bool
    let allowsDust: Bool
    let allowsTimestamp: Bool
    let allowsREC: Bool
    let allowsScribble: Bool
    let rotationRange: ClosedRange<Double>
}

struct LockUAtmosphereMotionProfile: Equatable, Sendable {
    let largeCloudDuration: Double
    let mediumCloudDuration: Double
    let distantCloudDuration: Double
    let glowDuration: Double
    let driftDistance: CGFloat
}

struct LockUMemoryAccentProfile: Equatable, Sendable {
    let paper: Color
    let tape: Color
    let borderOpacity: Double
    let livingMemoryBloom: Double
    let maximumDecorationCount: Int
}

struct LockULightingProfile: Equatable, Sendable {
    let ambientReflection: Color
    let directionalLight: Color
    let directionalOpacity: Double
    let rightShadeOpacity: Double
    let isDiffuse: Bool
}

struct LockUThemeProfile: Equatable, Sendable {
    let theme: LockUTheme
    let title: String
    let reflectionCopy: String
    let skyStops: [Color]
    let cloudTint: Color
    let interfaceTint: Color
    let glassTint: Color
    let lighting: LockULightingProfile
    let memoryAccent: LockUMemoryAccentProfile
    let microDecorations: [LockUMicroDecoration]
    let motion: LockUAtmosphereMotionProfile
    let sunlightOpacity: Double
    let hazeOpacity: Double

    var largeCloudOpacity: Double {
        switch theme { case .aoharu: 0.52; case .sweet: 0.48; case .dreamy: 0.30; case .quiet: 0.56; case .chaotic: 0.42 }
    }
    var mediumCloudOpacity: Double {
        switch theme { case .aoharu: 0.46; case .sweet: 0.40; case .dreamy: 0.26; case .quiet: 0.48; case .chaotic: 0.36 }
    }
    var distantCloudOpacity: Double {
        switch theme { case .aoharu: 0.30; case .sweet: 0.24; case .dreamy: 0.18; case .quiet: 0.34; case .chaotic: 0.22 }
    }
    var sunlightColor: Color { lighting.directionalLight }
    var hazeColor: Color {
        switch theme {
        case .aoharu: Color(red: 225/255, green: 241/255, blue: 250/255)
        case .sweet: Color(red: 248/255, green: 221/255, blue: 210/255)
        case .dreamy: Color(red: 202/255, green: 206/255, blue: 227/255)
        case .quiet: Color(red: 225/255, green: 229/255, blue: 229/255)
        case .chaotic: Color(red: 237/255, green: 240/255, blue: 232/255)
        }
    }
    var lockerReflectionColor: Color { lighting.ambientReflection }
    var lockerReflectionOpacity: Double {
        switch theme { case .aoharu: 0.06; case .sweet: 0.065; case .dreamy: 0.07; case .quiet: 0.035; case .chaotic: 0.045 }
    }
    var interfacePressedTint: Color {
        switch theme {
        case .aoharu: Color(red: 86/255, green: 143/255, blue: 175/255)
        case .sweet: Color(red: 191/255, green: 131/255, blue: 149/255)
        case .dreamy: Color(red: 127/255, green: 130/255, blue: 170/255)
        case .quiet: Color(red: 104/255, green: 125/255, blue: 134/255)
        case .chaotic: Color(red: 86/255, green: 118/255, blue: 137/255)
        }
    }
    var interfaceGlassTint: Color { glassTint.opacity(1) }
    var interfaceGlassTintOpacity: Double {
        switch theme { case .aoharu: 0.04; case .sweet: 0.08; case .dreamy: 0.06; case .quiet: 0.025; case .chaotic: 0.035 }
    }
    var paperColor: Color { memoryAccent.paper }
    var tapePrimary: Color { memoryAccent.tape }
    var tapeSecondary: Color {
        switch theme {
        case .aoharu: Color(red: 231/255, green: 241/255, blue: 245/255)
        case .sweet: Color(red: 232/255, green: 214/255, blue: 223/255)
        case .dreamy: Color(red: 221/255, green: 217/255, blue: 231/255)
        case .quiet: Color(red: 233/255, green: 231/255, blue: 226/255)
        case .chaotic: Color(red: 197/255, green: 219/255, blue: 226/255)
        }
    }
    var annotationColor: Color {
        switch theme {
        case .aoharu: Color(red: 99/255, green: 135/255, blue: 160/255)
        case .sweet: Color(red: 173/255, green: 121/255, blue: 134/255)
        case .dreamy: Color(red: 118/255, green: 122/255, blue: 152/255)
        case .quiet: Color(red: 123/255, green: 133/255, blue: 137/255)
        case .chaotic: Color(red: 47/255, green: 53/255, blue: 55/255)
        }
    }
    var decorationProfile: LockUDecorationProfile {
        switch theme {
        case .aoharu: .init(maximumCount: 5, allowsStars: true, allowsRibbon: false, allowsFlower: false, allowsHandwrittenHeart: false, allowsDust: false, allowsTimestamp: true, allowsREC: false, allowsScribble: false, rotationRange: 0...0)
        case .sweet: .init(maximumCount: 4, allowsStars: true, allowsRibbon: true, allowsFlower: true, allowsHandwrittenHeart: true, allowsDust: false, allowsTimestamp: false, allowsREC: false, allowsScribble: false, rotationRange: 0...0)
        case .dreamy: .init(maximumCount: 6, allowsStars: true, allowsRibbon: false, allowsFlower: false, allowsHandwrittenHeart: false, allowsDust: true, allowsTimestamp: false, allowsREC: false, allowsScribble: false, rotationRange: 0...0)
        case .quiet: .init(maximumCount: 1, allowsStars: false, allowsRibbon: false, allowsFlower: false, allowsHandwrittenHeart: false, allowsDust: false, allowsTimestamp: false, allowsREC: false, allowsScribble: false, rotationRange: 0...0)
        case .chaotic: .init(maximumCount: 4, allowsStars: true, allowsRibbon: false, allowsFlower: false, allowsHandwrittenHeart: true, allowsDust: false, allowsTimestamp: true, allowsREC: true, allowsScribble: true, rotationRange: -3...3)
        }
    }
    var largeCloudDuration: Double { motion.largeCloudDuration }
    var mediumCloudDuration: Double { motion.mediumCloudDuration }
    var distantCloudDuration: Double { motion.distantCloudDuration }
    var ambientBreathingDuration: Double? { motion.glowDuration > 0 ? motion.glowDuration : nil }
}

enum LockUThemeTransitionTokens {
    static let sky = (delay: 0.0, duration: 0.38)
    static let ambient = (delay: 0.08, duration: 0.40)
    static let interface = (delay: 0.14, duration: 0.28)
    static let memoryMaterial = (delay: 0.20, duration: 0.32)
    static let oldDecoration = (delay: 0.30, duration: 0.28, endScale: 0.96)
    static let newDecoration = (delay: 0.38, duration: 0.34, startScale: 0.96)
    static let totalDuration = 0.72
    static let reduceMotionCrossfadeDuration = 0.22
}

enum LockUThemePickerTokens {
    static let buttonTapSize: CGFloat = 44
    static let buttonVisualSize: CGFloat = 20
    static let sheetHeightFraction: CGFloat = 0.46
    static let sheetCornerRadius: CGFloat = 28
    static let sheetHorizontalPadding: CGFloat = 18
    static let sheetTopPadding: CGFloat = 16
    static let cardGap: CGFloat = 12
    static let cardCornerRadius: CGFloat = 20
    static let cardHeight: CGFloat = 142
    static let cardPreviewHeight: CGFloat = 96
    static let selectedOutlineWidth: CGFloat = 1
    static let selectedOutlineOpacity = 0.85
    static let selectedShadowOpacity = 0.10
    static let unselectedOpacity = 0.82
    static let checkmarkMaximumSize: CGFloat = 16
    static let segmentedHeight: CGFloat = 36
    static let segmentedBackgroundOpacity = 0.34
    static let segmentedSelectedBackgroundOpacity = 0.72
}

enum LockUThemeApplicationScope: String, Codable, CaseIterable, Sendable {
    case today, preferredDefault
    static let initial: Self = .today
}

enum LockUChaoticAccentTokens {
    static let markerBlue = Color(red: 82/255, green: 127/255, blue: 154/255)
    static let markerRed = Color(red: 185/255, green: 100/255, blue: 100/255)
    static let timestampCream = Color(red: 231/255, green: 215/255, blue: 183/255)
}

enum LockUThemeCatalog {
    static let pickerPrompt = "How do you want today to feel?"

    static func profile(for theme: LockUTheme) -> LockUThemeProfile {
        switch theme {
        case .aoharu:
            return LockUThemeProfile(
                theme: theme, title: "Aoharu", reflectionCopy: "keep the air of today",
                skyStops: WorldProfile.afterSchool.skyStops,
                cloudTint: LockUDesign.Color.cloudWhite,
                interfaceTint: Color(red: 105/255, green: 183/255, blue: 217/255),
                glassTint: .white,
                lighting: LockULightingProfile(ambientReflection: LockUDesign.Color.worldSkyReflection, directionalLight: LockUDesign.Color.sunlight, directionalOpacity: 0.18, rightShadeOpacity: 0.06, isDiffuse: false),
                memoryAccent: LockUMemoryAccentProfile(paper: LockUSceneTokens.Material.paperBase, tape: Color(red: 216/255, green: 234/255, blue: 244/255), borderOpacity: 0.62, livingMemoryBloom: 0, maximumDecorationCount: 5),
                microDecorations: [.tinyStar, .tapeAccent, .tinyHandwriting],
                motion: LockUAtmosphereMotionProfile(largeCloudDuration: 58, mediumCloudDuration: 48, distantCloudDuration: 82, glowDuration: 23, driftDistance: 18),
                sunlightOpacity: 0.18, hazeOpacity: 0.045
            )
        case .sweet:
            return LockUThemeProfile(
                theme: theme, title: "Sweet", reflectionCopy: "keep it softly",
                skyStops: [Color(red: 215/255, green: 199/255, blue: 213/255), Color(red: 229/255, green: 213/255, blue: 222/255), Color(red: 242/255, green: 223/255, blue: 223/255), Color(red: 247/255, green: 231/255, blue: 219/255), Color(red: 250/255, green: 241/255, blue: 230/255)],
                cloudTint: Color(red: 1, green: 249/255, blue: 243/255),
                interfaceTint: Color(red: 213/255, green: 154/255, blue: 170/255),
                glassTint: Color(red: 247/255, green: 216/255, blue: 223/255),
                lighting: LockULightingProfile(ambientReflection: Color(red: 244/255, green: 189/255, blue: 170/255), directionalLight: Color(red: 1, green: 215/255, blue: 186/255), directionalOpacity: 0.15, rightShadeOpacity: 0.045, isDiffuse: false),
                memoryAccent: LockUMemoryAccentProfile(paper: Color(red: 250/255, green: 243/255, blue: 233/255), tape: Color(red: 243/255, green: 206/255, blue: 212/255), borderOpacity: 0.55, livingMemoryBloom: 0.01, maximumDecorationCount: 4),
                microDecorations: [.tinyRibbon, .tinyFlower, .handwrittenHeart],
                motion: LockUAtmosphereMotionProfile(largeCloudDuration: 66, mediumCloudDuration: 54, distantCloudDuration: 88, glowDuration: 25, driftDistance: 14),
                sunlightOpacity: 0.15, hazeOpacity: 0.06
            )
        case .dreamy:
            return LockUThemeProfile(
                theme: theme, title: "Dreamy", reflectionCopy: "let it feel a little distant",
                skyStops: [Color(red: 102/255, green: 115/255, blue: 142/255), Color(red: 120/255, green: 135/255, blue: 165/255), Color(red: 150/255, green: 163/255, blue: 190/255), Color(red: 183/255, green: 189/255, blue: 209/255), Color(red: 216/255, green: 214/255, blue: 223/255)],
                cloudTint: Color(red: 220/255, green: 226/255, blue: 236/255),
                interfaceTint: Color(red: 151/255, green: 153/255, blue: 190/255),
                glassTint: Color(red: 169/255, green: 174/255, blue: 208/255),
                lighting: LockULightingProfile(ambientReflection: Color(red: 167/255, green: 169/255, blue: 210/255), directionalLight: Color(red: 199/255, green: 209/255, blue: 229/255), directionalOpacity: 0.05, rightShadeOpacity: 0.08, isDiffuse: true),
                memoryAccent: LockUMemoryAccentProfile(paper: Color(red: 242/255, green: 240/255, blue: 237/255), tape: Color(red: 200/255, green: 200/255, blue: 219/255), borderOpacity: 0.52, livingMemoryBloom: 0.08, maximumDecorationCount: 6),
                microDecorations: [.tinyStar, .dust, .softGlow],
                motion: LockUAtmosphereMotionProfile(largeCloudDuration: 76, mediumCloudDuration: 66, distantCloudDuration: 92, glowDuration: 26, driftDistance: 10),
                sunlightOpacity: 0.05, hazeOpacity: 0.065
            )
        case .quiet:
            return LockUThemeProfile(
                theme: theme, title: "Quiet", reflectionCopy: "just keep it as it was",
                skyStops: [Color(red: 174/255, green: 187/255, blue: 195/255), Color(red: 190/255, green: 200/255, blue: 206/255), Color(red: 206/255, green: 213/255, blue: 217/255), Color(red: 219/255, green: 223/255, blue: 223/255), Color(red: 230/255, green: 231/255, blue: 228/255)],
                cloudTint: Color(red: 233/255, green: 236/255, blue: 236/255),
                interfaceTint: Color(red: 127/255, green: 150/255, blue: 159/255),
                glassTint: .white,
                lighting: LockULightingProfile(ambientReflection: Color(red: 243/255, green: 244/255, blue: 242/255), directionalLight: Color(red: 242/255, green: 243/255, blue: 241/255), directionalOpacity: 0.025, rightShadeOpacity: 0.035, isDiffuse: true),
                memoryAccent: LockUMemoryAccentProfile(paper: Color(red: 244/255, green: 242/255, blue: 237/255), tape: Color(red: 221/255, green: 220/255, blue: 215/255), borderOpacity: 0.34, livingMemoryBloom: 0, maximumDecorationCount: 1),
                microDecorations: [],
                motion: LockUAtmosphereMotionProfile(largeCloudDuration: 94, mediumCloudDuration: 84, distantCloudDuration: 110, glowDuration: 0, driftDistance: 6),
                sunlightOpacity: 0.025, hazeOpacity: 0.035
            )
        case .chaotic:
            return LockUThemeProfile(
                theme: theme, title: "Chaotic", reflectionCopy: "keep the mess too",
                skyStops: [Color(red: 129/255, green: 180/255, blue: 215/255), Color(red: 161/255, green: 200/255, blue: 224/255), Color(red: 192/255, green: 217/255, blue: 232/255), Color(red: 219/255, green: 232/255, blue: 237/255), Color(red: 238/255, green: 236/255, blue: 230/255)],
                cloudTint: Color(red: 247/255, green: 245/255, blue: 238/255),
                interfaceTint: Color(red: 104/255, green: 141/255, blue: 162/255),
                glassTint: .white,
                lighting: LockULightingProfile(ambientReflection: Color(red: 169/255, green: 209/255, blue: 224/255), directionalLight: Color(red: 1, green: 241/255, blue: 215/255), directionalOpacity: 0.12, rightShadeOpacity: 0.065, isDiffuse: false),
                memoryAccent: LockUMemoryAccentProfile(paper: Color(red: 244/255, green: 240/255, blue: 230/255), tape: Color(red: 214/255, green: 210/255, blue: 199/255), borderOpacity: 0.58, livingMemoryBloom: 0.01, maximumDecorationCount: 4),
                microDecorations: [.rec, .dateStamp, .tinyPixelHeart, .scribble, .roughUnderline, .smallArrow, .tinyStar, .handwrittenLOL],
                motion: LockUAtmosphereMotionProfile(largeCloudDuration: 49, mediumCloudDuration: 43, distantCloudDuration: 72, glowDuration: 20, driftDistance: 16),
                sunlightOpacity: 0.14, hazeOpacity: 0.04
            )
        }
    }
}

struct LockUThemeAtmospherePreview: View {
    let theme: LockUTheme

    var body: some View {
        let profile = LockUThemeCatalog.profile(for: theme)
        ZStack {
            LinearGradient(colors: profile.skyStops, startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(profile.cloudTint.opacity(theme == .quiet ? 0.32 : 0.48))
                .frame(width: 46, height: 18)
                .blur(radius: 5)
                .offset(x: -24, y: -12)
            LinearGradient(colors: [profile.lighting.ambientReflection.opacity(0.16), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .clipShape(RoundedRectangle(cornerRadius: LockUDesign.Radius.small))
        .accessibilityLabel("\(profile.title): \(profile.reflectionCopy)")
    }
}

struct LockerAmbientReflection: View {
    let theme: LockUTheme

    var body: some View {
        let profile = LockUThemeCatalog.profile(for: theme)
        ZStack {
            LinearGradient(
                colors: [profile.lockerReflectionColor.opacity(profile.lockerReflectionOpacity), .clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            LinearGradient(
                colors: [.clear, .black.opacity(profile.lighting.rightShadeOpacity)],
                startPoint: .center,
                endPoint: .trailing
            )
        }
        .blendMode(.softLight)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

typealias LockerThemeLightingOverlay = LockerAmbientReflection

enum LockUMemoryStyle: String, Codable, CaseIterable, Sendable {
    case rawPhoto, polaroid, cutout, tinyMemory, livingMemory
}

struct LockUMemoryStyleTokens: Equatable, Sendable {
    let edgeWidth: CGFloat
    let sizeMultiplier: CGFloat
    let topPadding: CGFloat
    let sidePadding: CGFloat
    let bottomPadding: CGFloat
    let contactShadowOpacity: Double
    let stillDuration: ClosedRange<Double>?
    let motionDuration: ClosedRange<Double>?

    static func tokens(for style: LockUMemoryStyle) -> Self {
        switch style {
        case .rawPhoto: return .init(edgeWidth: 1, sizeMultiplier: 1, topPadding: 0, sidePadding: 0, bottomPadding: 0, contactShadowOpacity: 0.18, stillDuration: nil, motionDuration: nil)
        case .polaroid: return .init(edgeWidth: 0, sizeMultiplier: 1, topPadding: 8, sidePadding: 8, bottomPadding: 26, contactShadowOpacity: 0.16, stillDuration: nil, motionDuration: nil)
        case .cutout: return .init(edgeWidth: 0, sizeMultiplier: 1, topPadding: 0, sidePadding: 0, bottomPadding: 0, contactShadowOpacity: 0.24, stillDuration: nil, motionDuration: nil)
        case .tinyMemory: return .init(edgeWidth: 1, sizeMultiplier: 0.62, topPadding: 0, sidePadding: 0, bottomPadding: 0, contactShadowOpacity: 0.14, stillDuration: nil, motionDuration: nil)
        case .livingMemory: return .init(edgeWidth: 1, sizeMultiplier: 1.7, topPadding: 0, sidePadding: 0, bottomPadding: 0, contactShadowOpacity: 0.23, stillDuration: 3...7, motionDuration: 1...3)
        }
    }
}

struct LockUSurfaceAgingProfile: Equatable, Sendable {
    let scratchIntensity: Double
    let edgeWearIntensity: Double
    let touchWearIntensity: Double
    let stickerGhostIntensity: Double
    let oxidationIntensity: Double
}

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

        var agingProfile: LockUSurfaceAgingProfile {
            switch self {
            case .initial: return .init(scratchIntensity: 0.01, edgeWearIntensity: 0.01, touchWearIntensity: 0, stickerGhostIntensity: 0, oxidationIntensity: 0)
            case .oneMonth: return .init(scratchIntensity: 0.025, edgeWearIntensity: 0.02, touchWearIntensity: 0.015, stickerGhostIntensity: 0, oxidationIntensity: 0)
            case .threeMonths: return .init(scratchIntensity: 0.03, edgeWearIntensity: 0.035, touchWearIntensity: 0.02, stickerGhostIntensity: 0, oxidationIntensity: 0.003)
            case .sixMonths: return .init(scratchIntensity: 0.055, edgeWearIntensity: 0.065, touchWearIntensity: 0.05, stickerGhostIntensity: 0.025, oxidationIntensity: 0.01)
            case .oneYear: return .init(scratchIntensity: 0.07, edgeWearIntensity: 0.085, touchWearIntensity: 0.065, stickerGhostIntensity: 0.04, oxidationIntensity: 0.02)
            }
        }
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
        static let structuralShadow = SwiftUI.Color.black.opacity(0.18)
        static let contactShadow = SwiftUI.Color.black.opacity(0.22)
        static let paperShadow = SwiftUI.Color.black.opacity(0.14)
        static let floatingUIShadow = SwiftUI.Color.black.opacity(0.12)
        static let innerCavityShadow = SwiftUI.Color.black.opacity(0.30)

        // Compatibility aliases.
        static let soft = SwiftUI.Color.black.opacity(0.14)
        static let floating = SwiftUI.Color.black.opacity(0.24)
        static let inner = SwiftUI.Color.black.opacity(0.3)
        static let deep = SwiftUI.Color.black.opacity(0.28)
    }

    enum Motion {
        enum Interaction {
            static let quick = Animation.easeOut(duration: 0.22)
            static let soft = Animation.easeOut(duration: 0.28)
            static let spring = Animation.spring(response: 0.45, dampingFraction: 0.86)
            static let door = Animation.interactiveSpring(response: 0.55, dampingFraction: 0.86, blendDuration: 0.15)
        }

        enum Memory {
            static let settle = Animation.easeOut(duration: 0.35)
            static let livingTransition = Animation.easeInOut(duration: 1.2)
        }

        // Compatibility aliases for existing views.
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

struct LockUWorldThemeCompositor {
    func compose(theme: LockUThemeProfile, world: WorldProfile) -> WorldProfile {
        let reference = WorldProfile.afterSchool
        let sunlightFactor = reference.sunlightOpacity > 0 ? world.sunlightOpacity / reference.sunlightOpacity : 1
        let hazeDelta = world.hazeOpacity - reference.hazeOpacity
        return WorldProfile(
            time: world.time,
            weather: world.weather,
            skyStops: theme.skyStops,
            sunlight: theme.sunlightColor,
            sunlightOpacity: max(0, min(0.24, theme.sunlightOpacity * sunlightFactor)),
            hazeOpacity: max(0, min(0.12, theme.hazeOpacity + hazeDelta)),
            cloudTint: theme.cloudTint,
            ambientReflection: theme.lockerReflectionColor
        )
    }
}

struct SummerSkyBackground: View {
    let profile: WorldProfile
    let themeProfile: LockUThemeProfile
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var largeCloudDrifting = false
    @State private var mediumCloudDrifting = false
    @State private var distantCloudDrifting = false
    @State private var breathing = false

    init(profile: WorldProfile = .afterSchool, theme: LockUTheme = .aoharu) {
        let themeProfile = LockUThemeCatalog.profile(for: theme)
        self.themeProfile = themeProfile
        self.profile = LockUWorldThemeCompositor().compose(theme: themeProfile, world: profile)
    }

    var body: some View {
        ZStack {
            WorldSkyBase(profile: profile)
            WorldCloudLayer(
                profile: profile,
                largeDrifting: largeCloudDrifting,
                mediumDrifting: mediumCloudDrifting,
                distantDrifting: distantCloudDrifting,
                driftDistance: themeProfile.motion.driftDistance,
                largeOpacity: themeProfile.largeCloudOpacity,
                mediumOpacity: themeProfile.mediumCloudOpacity,
                distantOpacity: themeProfile.distantCloudOpacity
            )
            WorldSunlightLayer(profile: profile, breathing: breathing)
            WorldAtmosphericHaze(profile: profile, hazeColor: themeProfile.hazeColor, breathing: breathing)
            WorldAmbientReflection(profile: profile)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: themeProfile.motion.largeCloudDuration).repeatForever(autoreverses: true)) { largeCloudDrifting = true }
            withAnimation(.linear(duration: themeProfile.motion.mediumCloudDuration).repeatForever(autoreverses: true)) { mediumCloudDrifting = true }
            withAnimation(.linear(duration: themeProfile.motion.distantCloudDuration).repeatForever(autoreverses: true)) { distantCloudDrifting = true }
            if themeProfile.motion.glowDuration > 0 {
                withAnimation(.easeInOut(duration: themeProfile.motion.glowDuration).repeatForever(autoreverses: true)) { breathing = true }
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
    let largeDrifting: Bool
    let mediumDrifting: Bool
    let distantDrifting: Bool
    let driftDistance: CGFloat
    let largeOpacity: Double
    let mediumOpacity: Double
    let distantOpacity: Double
    var body: some View {
        GeometryReader { p in
            ZStack {
                NaturalCloud().fill(profile.cloudTint.opacity(largeOpacity)).frame(width: 260, height: 92)
                    .overlay(NaturalCloud().fill(Color(red: 187/255, green: 214/255, blue: 232/255).opacity(0.10)))
                    .blur(radius: 3.5).position(x: -14 + (largeDrifting ? driftDistance : 0), y: p.size.height * 0.20)
                NaturalCloud().fill(profile.cloudTint.opacity(mediumOpacity)).frame(width: 190, height: 66).blur(radius: 4)
                    .scaleEffect(x: -1, y: 1).position(x: p.size.width + 12 + (mediumDrifting ? -driftDistance * 0.78 : 0), y: p.size.height * 0.36)
                NaturalCloud().fill(profile.cloudTint.opacity(distantOpacity)).frame(width: 145, height: 45).blur(radius: 5)
                    .position(x: p.size.width * 0.12 + (distantDrifting ? driftDistance * 0.60 : 0), y: p.size.height * 0.74)
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
    let profile: WorldProfile
    let hazeColor: Color
    let breathing: Bool
    var body: some View {
        LinearGradient(colors: [.white.opacity(0.01), hazeColor.opacity(breathing ? profile.hazeOpacity + 0.01 : profile.hazeOpacity)], startPoint: .top, endPoint: .bottom)
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
