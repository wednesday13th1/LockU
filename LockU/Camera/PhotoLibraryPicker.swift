import ImageIO
import PhotosUI
import SwiftUI
import UIKit

enum PhotoLibraryPickerStyle {
    case icon
    case labeled
}

struct PhotoLibraryPicker: View {
    let isDisabled: Bool
    var style: PhotoLibraryPickerStyle = .icon
    let onImage: (UIImage) -> Void
    let onError: (Error) -> Void
    @State private var item: PhotosPickerItem?
    @State private var isLoading = false

    var body: some View {
        PhotosPicker(selection: $item, matching: .images) {
            Group {
                if case .labeled = style {
                    HStack {
                        if isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "photo.on.rectangle")
                        }
                        Text(isLoading ? "読み込んでいます…" : "写真ライブラリから選ぶ")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(.white)
                    .background(LockUDesign.Color.dustBlue, in: RoundedRectangle(cornerRadius: 14))
                } else {
                    ZStack {
                        Circle()
                            .fill(.black.opacity(0.48))
                            .frame(width: 52, height: 52)
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
        .disabled(isDisabled || isLoading)
        .accessibilityLabel("写真ライブラリから選択")
        .onChange(of: item) { _, newItem in
            guard let newItem else { return }
            Task { await load(newItem) }
        }
    }

    private func load(_ item: PhotosPickerItem) async {
        isLoading = true
        defer {
            isLoading = false
            self.item = nil
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = await LockUImageDecoder.downsample(data: data, maxDimension: 2400) else {
                throw LockUStorageError.invalidImage
            }
            onImage(image)
        } catch {
            onError(error)
        }
    }
}

enum LockUImageDecoder {
    static func downsample(data: Data, maxDimension: CGFloat) async -> UIImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let options = [kCGImageSourceShouldCache: false] as CFDictionary
                guard let source = CGImageSourceCreateWithData(data as CFData, options) else {
                    continuation.resume(returning: nil)
                    return
                }
                let thumbnailOptions = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxDimension,
                    kCGImageSourceShouldCacheImmediately: true
                ] as CFDictionary
                guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: UIImage(cgImage: image))
            }
        }
    }
}
