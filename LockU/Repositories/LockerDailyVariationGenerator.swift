import Foundation

enum LockerVariationStrength: Equatable, Sendable {
    case subtle
    case normal
    case expressive

    var budget: Int {
        switch self {
        case .subtle: 2
        case .normal: 3
        case .expressive: 4
        }
    }
}

struct LockerItemPoseVariation: Equatable, Sendable {
    var rotationDelta: Double = 0
    var xOffset: Double = 0
    var yOffset: Double = 0

    static let zero = LockerItemPoseVariation()
}

struct LockerDailyVariation: Equatable, Sendable {
    var flowerStyle: LockerFlowerStyle?
    var framePhotoStyle: LockerPhotoStyle?
    var notebookDetail: String?
    var cameraAccentEnabled = false
    var perfumeLabel: String?
    var notebookPose = LockerItemPoseVariation.zero
    var cameraPose = LockerItemPoseVariation.zero
    var framePose = LockerItemPoseVariation.zero
    var variationPointCount = 0
    let dayIdentifier: String
    let period: LockerTimePeriod

    static func base(dayIdentifier: String = "", period: LockerTimePeriod = .day) -> LockerDailyVariation {
        LockerDailyVariation(dayIdentifier: dayIdentifier, period: period)
    }
}

struct LockerDailyVariationGenerator {
    private enum Category: UInt64, CaseIterable {
        case flower = 11
        case framePhoto = 23
        case notebook = 37
        case camera = 53
        case perfume = 71
        case pose = 89
    }

    private let calendar: Calendar
    private let periodService: LockerTimePeriodService

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
        periodService = LockerTimePeriodService(calendar: calendar)
    }

    func variation(
        for date: Date,
        theme: LockerItemTheme,
        strength: LockerVariationStrength = .subtle
    ) -> LockerDailyVariation {
        let day = calendar.startOfDay(for: date)
        let period = periodService.period(for: date)
        let dayIdentifier = identifier(for: day)
        let ordinal = calendar.ordinality(of: .day, in: .era, for: day) ?? 0
        let seed = stableSeed("\(dayIdentifier)|\(theme.rawValue)|\(period.rawValue)")
        let valueSeed = stableSeed("\(theme.rawValue)|\(period.rawValue)|micro-variation")
        let categoryCount = min(strength.budget, strength == .subtle ? 1 + Int(seed & 1) : strength.budget)
        let categories = Category.allCases
            .sorted { mixed(seed, $0.rawValue) < mixed(seed, $1.rawValue) }
            .prefix(categoryCount)

        var result = LockerDailyVariation.base(dayIdentifier: dayIdentifier, period: period)
        for category in categories {
            apply(category, ordinal: ordinal, seed: valueSeed, theme: theme, period: period, to: &result)
            result.variationPointCount += 1
        }
        return result
    }

    private func apply(
        _ category: Category,
        ordinal: Int,
        seed: UInt64,
        theme: LockerItemTheme,
        period: LockerTimePeriod,
        to result: inout LockerDailyVariation
    ) {
        switch category {
        case .flower:
            result.flowerStyle = pick(flowerPool(for: theme), seed: seedForBucket(ordinal / 3, seed, category.rawValue))
        case .framePhoto:
            result.framePhotoStyle = pick(photoPool(for: theme, period: period), seed: seedForBucket(ordinal / 2, seed, category.rawValue))
        case .notebook:
            result.notebookDetail = pick(notebookPool(for: theme), seed: seedForBucket(ordinal / 5, seed, category.rawValue))
        case .camera:
            result.cameraAccentEnabled = true
        case .perfume:
            result.perfumeLabel = pick(perfumePool(for: theme), seed: seedForBucket(ordinal / 4, seed, category.rawValue))
        case .pose:
            let poseSeed = seedForBucket(ordinal / 3, seed, category.rawValue)
            let pose = LockerItemPoseVariation(
                rotationDelta: signed(poseSeed, limit: 1.25),
                xOffset: signed(poseSeed >> 9, limit: 3.5),
                yOffset: signed(poseSeed >> 19, limit: 2.0)
            )
            switch poseSeed % 3 {
            case 0: result.notebookPose = pose
            case 1: result.cameraPose = pose
            default: result.framePose = pose
            }
        }
    }

    private func flowerPool(for theme: LockerItemTheme) -> [LockerFlowerStyle] {
        switch theme {
        case .blush: [.tulip, .whiteTulip]
        case .blue: [.daisy, .whiteTulip]
        case .sage: [.daisy, .paleYellowDaisy]
        case .aoharu: [.daisy, .paleTulip]
        }
    }

    private func photoPool(for theme: LockerItemTheme, period: LockerTimePeriod) -> [LockerPhotoStyle] {
        let timed: [LockerPhotoStyle]
        switch period {
        case .morning: timed = [.clearSky, .softCloud, .sunlight]
        case .day: timed = [.clearSky, .summerTree, .classroomWindow]
        case .afterSchool: timed = [.sunset, .warmCloud, .summerTree]
        case .night: timed = [.deepBlue, .cityLights, .moonGlow]
        }
        let themed: LockerPhotoStyle
        switch theme {
        case .blush: themed = .sunset
        case .blue: themed = .clearSky
        case .sage: themed = .greenField
        case .aoharu: themed = .summerSky
        }
        return [themed] + timed
    }

    private func notebookPool(for theme: LockerItemTheme) -> [String] {
        switch theme {
        case .blush: ["♡", "⌁"]
        case .blue: ["☁", "✦"]
        case .sage: ["⌁", "❀"]
        case .aoharu: ["✦", "☁", "TODAY"]
        }
    }

    private func perfumePool(for theme: LockerItemTheme) -> [String] {
        switch theme {
        case .blush: ["MOMENT", "BLOOM"]
        case .blue: ["BREEZE", "CLEAR"]
        case .sage: ["CALM", "MORNING"]
        case .aoharu: ["BREEZE", "DAYLIGHT", "MOMENT"]
        }
    }

    private func pick<T>(_ values: [T], seed: UInt64) -> T? {
        guard !values.isEmpty else { return nil }
        return values[Int(seed % UInt64(values.count))]
    }

    private func signed(_ seed: UInt64, limit: Double) -> Double {
        let unit = Double(seed % 10_001) / 5_000 - 1
        return max(-limit, min(limit, unit * limit))
    }

    private func seedForBucket(_ bucket: Int, _ seed: UInt64, _ salt: UInt64) -> UInt64 {
        mixed(seed ^ UInt64(truncatingIfNeeded: bucket), salt)
    }

    private func mixed(_ value: UInt64, _ salt: UInt64) -> UInt64 {
        var x = value &+ salt &* 0x9E3779B97F4A7C15
        x ^= x >> 30
        x &*= 0xBF58476D1CE4E5B9
        x ^= x >> 27
        x &*= 0x94D049BB133111EB
        return x ^ (x >> 31)
    }

    private func stableSeed(_ value: String) -> UInt64 {
        value.utf8.reduce(14_695_981_039_346_656_037) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }

    private func identifier(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
