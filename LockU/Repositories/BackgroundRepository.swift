import Combine
import Foundation
import UIKit

@MainActor
final class BackgroundRepository: ObservableObject {
    @Published private(set) var image: UIImage?
    private let imageURL: URL

    init(paths: LockUPaths) {
        imageURL = paths.backgrounds.appendingPathComponent("background-current.jpg")
    }

    func reload() {
        image = UIImage(contentsOfFile: imageURL.path)
    }

    func save(_ newImage: UIImage) throws {
        guard let data = newImage.jpegData(compressionQuality: 0.9) else {
            throw LockUStorageError.invalidImage
        }
        try data.write(to: imageURL, options: [.atomic])
        image = newImage
    }
}
