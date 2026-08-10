import Foundation

struct DailyFilmService {
    let calendar: Calendar
    let catalog: [DailyFilm]

    init(calendar: Calendar = .autoupdatingCurrent, catalog: [DailyFilm] = DailyFilmCatalog.films) {
        self.calendar = calendar
        self.catalog = catalog
    }

    func film(for date: Date) -> DailyFilm {
        precondition(!catalog.isEmpty, "Daily Film catalog must not be empty")
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return catalog[positiveModulo(day, catalog.count)]
    }

    func dayIdentifier(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private func positiveModulo(_ value: Int, _ divisor: Int) -> Int {
        let remainder = value % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }
}

struct DailyFilmRevealStore {
    private let defaults: UserDefaults
    private let key = "lastDailyFilmRevealDate"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func shouldReveal(on date: Date, service: DailyFilmService) -> Bool {
        defaults.string(forKey: key) != service.dayIdentifier(for: date)
    }

    func markRevealed(on date: Date, service: DailyFilmService) {
        defaults.set(service.dayIdentifier(for: date), forKey: key)
    }
}
