import SwiftUI

struct DailyFilmPreviewModifier: ViewModifier {
    let film: DailyFilm

    func body(content: Content) -> some View {
        content
            .brightness(film.exposure * 0.045 + film.fade * 0.018)
            .contrast(film.contrast)
            .saturation(film.saturation)
            .overlay(temperatureOverlay.blendMode(.softLight).allowsHitTesting(false))
            .overlay(vignette.allowsHitTesting(false))
    }

    private var temperatureOverlay: Color {
        if film.temperature >= 0 {
            return Color(red: 1, green: 0.72, blue: 0.42).opacity(min(film.temperature / 5_000, 0.07))
        }
        return Color(red: 0.35, green: 0.72, blue: 1).opacity(min(abs(film.temperature) / 5_000, 0.07))
    }

    private var vignette: some View {
        RadialGradient(colors: [.clear, .black.opacity(film.vignette * 0.45)], center: .center, startRadius: 80, endRadius: 430)
    }
}

extension View {
    func dailyFilmPreview(_ film: DailyFilm) -> some View { modifier(DailyFilmPreviewModifier(film: film)) }
}
