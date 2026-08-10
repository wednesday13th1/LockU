import Foundation

enum DailyFilmCatalog {
    static let films: [DailyFilm] = [
        film("blue-hour", "BLUE HOUR", "after school blue", exposure: 0.05, contrast: 0.94, saturation: 0.86, temperature: -210, tint: 2, highlights: 0.90, shadows: 0.18, fade: 0.10, grain: 0.025, vignette: 0.08, bloom: 0.05, sharpness: 0.05),
        film("digicam-04", "DIGICAM 04", "compact digital", exposure: 0.10, contrast: 1.10, saturation: 0.93, temperature: -90, tint: 1, highlights: 1.02, shadows: 0.02, fade: 0.02, grain: 0.018, vignette: 0.04, bloom: 0.02, sharpness: 0.28),
        film("milk", "MILK", "soft daylight", exposure: 0.13, contrast: 0.90, saturation: 0.88, temperature: 120, tint: 2, highlights: 0.88, shadows: 0.20, fade: 0.13, grain: 0.012, vignette: 0.02, bloom: 0.08, sharpness: 0.02),
        film("flash", "FLASH", "night snapshot", exposure: 0.14, contrast: 1.14, saturation: 0.94, temperature: -75, tint: 0, highlights: 1.08, shadows: -0.06, fade: 0.01, grain: 0.015, vignette: 0.06, bloom: 0.03, sharpness: 0.34),
        film("golden", "GOLDEN", "late afternoon", exposure: 0.08, contrast: 0.98, saturation: 0.96, temperature: 280, tint: 3, highlights: 0.95, shadows: 0.13, fade: 0.08, grain: 0.018, vignette: 0.05, bloom: 0.06, sharpness: 0.08),
        film("ccd", "CCD", "cyan compact", exposure: 0.11, contrast: 1.12, saturation: 0.92, temperature: -130, tint: -5, highlights: 1.04, shadows: -0.02, fade: 0.025, grain: 0.028, vignette: 0.04, bloom: 0.015, sharpness: 0.32),
        film("disposable", "DISPOSABLE", "one day film", exposure: 0.04, contrast: 1.02, saturation: 0.91, temperature: 180, tint: 2, highlights: 0.96, shadows: 0.15, fade: 0.11, grain: 0.055, vignette: 0.13, bloom: 0.035, sharpness: 0.04)
    ]

    private static func film(_ id: String, _ name: String, _ subtitle: String, exposure: Double, contrast: Double, saturation: Double, temperature: Double, tint: Double, highlights: Double, shadows: Double, fade: Double, grain: Double, vignette: Double, bloom: Double, sharpness: Double) -> DailyFilm {
        DailyFilm(id: id, name: name, subtitle: subtitle, version: 1, exposure: exposure, contrast: contrast, saturation: saturation, temperature: temperature, tint: tint, highlights: highlights, shadows: shadows, fade: fade, grain: grain, vignette: vignette, bloom: bloom, sharpness: sharpness)
    }
}
