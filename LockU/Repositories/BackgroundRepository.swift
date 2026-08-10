import Combine
import Foundation
import UIKit

@MainActor
final class BackgroundRepository: ObservableObject {
    @Published private(set) var image: UIImage?
    private let storage: BackgroundImageStoring

    init(paths: LockUPaths, storage: BackgroundImageStoring? = nil) { self.storage = storage ?? BackgroundImageStorage(directory: paths.backgrounds) }

    func reload() {
        image = storage.load()
    }

    func save(_ newImage: UIImage) throws {
        try storage.save(newImage)
        image = newImage
    }

    func remove() throws { try storage.delete(); image = nil }
}
