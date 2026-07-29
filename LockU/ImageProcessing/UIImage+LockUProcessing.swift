import CoreGraphics
import UIKit

extension UIImage {
    nonisolated func lockUNormalized() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    nonisolated func lockUDownsampled(maxDimension: CGFloat) -> UIImage {
        let normalized = lockUNormalized()
        guard let cgImage = normalized.cgImage else { return normalized }
        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)
        let longest = max(pixelWidth, pixelHeight)
        guard longest > maxDimension, maxDimension > 0 else { return normalized }

        let ratio = maxDimension / longest
        let width = max(1, Int((pixelWidth * ratio).rounded()))
        let height = max(1, Int((pixelHeight * ratio).rounded()))
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return normalized
        }
        context.interpolationQuality = .high
        context.draw(
            cgImage,
            in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        )
        guard let resized = context.makeImage() else { return normalized }
        return UIImage(cgImage: resized, scale: normalized.scale, orientation: .up)
    }

    nonisolated func lockUCroppedToAlpha(padding: CGFloat) -> UIImage? {
        lockUAlphaCropResult(padding: padding)?.image
    }

    nonisolated func lockUAlphaCropResult(
        padding: CGFloat
    ) -> (image: UIImage, rect: CGRect)? {
        let normalized = lockUNormalized()
        guard let cgImage = normalized.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(
            cgImage,
            in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        )
        guard let rawData = context.data else { return nil }
        let pixels = rawData.assumingMemoryBound(to: UInt8.self)

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        for y in 0..<height {
            for x in 0..<width {
                let alpha = pixels[y * bytesPerRow + x * bytesPerPixel + 3]
                if alpha > 8 {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }

        let inset = max(0, Int(padding.rounded(.up)))
        let cropX = max(0, minX - inset)
        let cropY = max(0, minY - inset)
        let cropWidth = min(width - 1, maxX + inset) - cropX + 1
        let cropHeight = min(height - 1, maxY + inset) - cropY + 1
        let cropRect = CGRect(
            x: CGFloat(cropX),
            y: CGFloat(cropY),
            width: CGFloat(cropWidth),
            height: CGFloat(cropHeight)
        ).integral
        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
        return (
            UIImage(cgImage: cropped, scale: normalized.scale, orientation: .up),
            cropRect
        )
    }
}
