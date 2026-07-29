import CoreImage
import UIKit
import Vision

enum SubjectInstanceSelection: Sendable {
    case all
    case largest
    case indices(Set<Int>)
}

struct SubjectCutoutResult: @unchecked Sendable {
    let image: UIImage
    let subjectCount: Int
    let cropRect: CGRect
}

enum SubjectCutoutError: LocalizedError {
    case invalidInputImage
    case noSubjectFound
    case maskGenerationFailed
    case outputGenerationFailed
    case unsupportedDevice

    var errorDescription: String? {
        switch self {
        case .invalidInputImage:
            return "画像を解析できませんでした。"
        case .noSubjectFound:
            return "切り抜ける被写体を見つけられませんでした。"
        case .maskGenerationFailed:
            return "被写体のマスクを作成できませんでした。"
        case .outputGenerationFailed:
            return "切り抜き画像を作成できませんでした。"
        case .unsupportedDevice:
            return "この端末では自動切り抜きを利用できません。"
        }
    }
}

actor SubjectCutoutService {
    private let ciContext = CIContext(options: [.cacheIntermediates: false])

    func extractForeground(
        from image: UIImage,
        instanceSelection: SubjectInstanceSelection = .all
    ) async throws -> SubjectCutoutResult {
        try Task.checkCancellation()
        guard #available(iOS 17.0, *) else {
            throw SubjectCutoutError.unsupportedDevice
        }

        let analysisImage = image
            .lockUNormalized()
            .lockUDownsampled(maxDimension: 2400)
        guard let cgImage = analysisImage.cgImage else {
            throw SubjectCutoutError.invalidInputImage
        }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: .up,
            options: [:]
        )
        do {
            try handler.perform([request])
        } catch {
            throw SubjectCutoutError.maskGenerationFailed
        }
        try Task.checkCancellation()

        guard let observation = request.results?.first else {
            throw SubjectCutoutError.noSubjectFound
        }
        let instances = selectedInstances(
            from: observation.allInstances,
            selection: instanceSelection
        )
        guard !instances.isEmpty else {
            throw SubjectCutoutError.noSubjectFound
        }

        let maskBuffer: CVPixelBuffer
        do {
            maskBuffer = try observation.generateScaledMaskForImage(
                forInstances: instances,
                from: handler
            )
        } catch {
            throw SubjectCutoutError.maskGenerationFailed
        }
        try Task.checkCancellation()

        let foreground = CIImage(cgImage: cgImage)
        var mask = CIImage(cvPixelBuffer: maskBuffer)
        if mask.extent.size != foreground.extent.size {
            let xScale = foreground.extent.width / max(mask.extent.width, 1)
            let yScale = foreground.extent.height / max(mask.extent.height, 1)
            mask = mask.transformed(by: CGAffineTransform(scaleX: xScale, y: yScale))
        }
        mask = mask
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.8])
            .cropped(to: foreground.extent)

        let transparent = CIImage(
            color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)
        )
        .cropped(to: foreground.extent)
        guard let blend = CIFilter(name: "CIBlendWithMask") else {
            throw SubjectCutoutError.outputGenerationFailed
        }
        blend.setValue(foreground, forKey: kCIInputImageKey)
        blend.setValue(transparent, forKey: kCIInputBackgroundImageKey)
        blend.setValue(mask, forKey: kCIInputMaskImageKey)
        guard let output = blend.outputImage,
              let outputCGImage = ciContext.createCGImage(output, from: foreground.extent) else {
            throw SubjectCutoutError.outputGenerationFailed
        }

        let transparentImage = UIImage(
            cgImage: outputCGImage,
            scale: analysisImage.scale,
            orientation: .up
        )
        let padding = max(12, min(24, min(
            CGFloat(outputCGImage.width),
            CGFloat(outputCGImage.height)
        ) * 0.02))
        let cropResult = transparentImage.lockUAlphaCropResult(padding: padding)
        let cropped = cropResult?.image ?? transparentImage
        let cropRect = cropResult?.rect ?? foreground.extent
        return SubjectCutoutResult(
            image: cropped,
            subjectCount: instances.count,
            cropRect: cropRect
        )
    }

    private func selectedInstances(
        from available: IndexSet,
        selection: SubjectInstanceSelection
    ) -> IndexSet {
        switch selection {
        case .all:
            return available
        case .largest:
            guard let first = available.first else { return [] }
            return IndexSet(integer: first)
        case .indices(let requested):
            return IndexSet(requested.filter { available.contains($0) })
        }
    }
}
