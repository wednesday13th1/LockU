import CoreImage
import UIKit

final class DailyFilmRenderer: @unchecked Sendable {
    static let shared = DailyFilmRenderer()
    nonisolated private let context = CIContext(options: [.cacheIntermediates: true])

    private init() {}

    nonisolated func render(_ image: UIImage, film: DailyFilm) -> UIImage? {
        guard var output = CIImage(image: image) else { return nil }
        let extent = output.extent

        output = output.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: film.exposure])
        output = output.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: film.contrast,
            kCIInputSaturationKey: film.saturation,
            kCIInputBrightnessKey: film.fade * 0.025
        ])
        output = output.applyingFilter("CITemperatureAndTint", parameters: [
            "inputNeutral": CIVector(x: 6500, y: 0),
            "inputTargetNeutral": CIVector(x: 6500 + film.temperature, y: film.tint)
        ])
        output = output.applyingFilter("CIHighlightShadowAdjust", parameters: [
            "inputHighlightAmount": film.highlights,
            "inputShadowAmount": film.shadows
        ])
        if film.sharpness > 0 {
            output = output.applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: film.sharpness])
        }
        if film.bloom > 0 {
            output = output.applyingFilter("CIBloom", parameters: [kCIInputRadiusKey: 5, kCIInputIntensityKey: film.bloom])
        }
        if film.vignette > 0 {
            output = output.applyingFilter("CIVignette", parameters: [kCIInputIntensityKey: film.vignette, kCIInputRadiusKey: 1.4])
        }
        if film.grain > 0 {
            let noise = CIFilter(name: "CIRandomGenerator")!.outputImage!
                .cropped(to: extent)
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 0.55])
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: film.grain, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: film.grain, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: film.grain, w: 0),
                    "inputBiasVector": CIVector(x: 0.5 - film.grain / 2, y: 0.5 - film.grain / 2, z: 0.5 - film.grain / 2, w: 0)
                ])
            output = noise.applyingFilter("CISoftLightBlendMode", parameters: [kCIInputBackgroundImageKey: output])
        }

        output = output.cropped(to: extent)
        guard let cgImage = context.createCGImage(output, from: extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    func renderAsync(_ image: UIImage, film: DailyFilm) async -> UIImage? {
        await Task.detached(priority: .userInitiated) { [self] in render(image, film: film) }.value
    }
}
