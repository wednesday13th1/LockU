import Combine
import UIKit

@MainActor
final class MemoryEditorViewModel: ObservableObject {
    @Published private(set) var originalImage: UIImage?
    @Published private(set) var cutoutImage: UIImage?
    @Published var selectedStyle: MemoryImageStyle = .original
    @Published private(set) var isExtracting = false
    @Published private(set) var cutoutErrorMessage: String?
    @Published private(set) var cutoutWasAttempted = false

    private let service = SubjectCutoutService()
    private var extractionTask: Task<Void, Never>?
    private var editID = UUID()

    var imageToSave: UIImage? {
        selectedStyle == .cutout
            ? cutoutImage ?? originalImage
            : originalImage
    }

    func reset(with image: UIImage) {
        extractionTask?.cancel()
        editID = UUID()
        originalImage = image.lockUNormalized().lockUDownsampled(maxDimension: 2400)
        cutoutImage = nil
        selectedStyle = .original
        isExtracting = false
        cutoutErrorMessage = nil
        cutoutWasAttempted = false
    }

    func extractSubject() {
        guard let originalImage, !isExtracting else { return }
        extractionTask?.cancel()
        let requestedEditID = editID
        isExtracting = true
        cutoutErrorMessage = nil
        extractionTask = Task {
            do {
                let result = try await service.extractForeground(
                    from: originalImage,
                    instanceSelection: .all
                )
                guard !Task.isCancelled, requestedEditID == editID else { return }
                cutoutImage = result.image
                selectedStyle = .cutout
                cutoutWasAttempted = true
                isExtracting = false
            } catch is CancellationError {
                if requestedEditID == editID { isExtracting = false }
            } catch {
                guard requestedEditID == editID else { return }
                cutoutImage = nil
                selectedStyle = .original
                cutoutWasAttempted = true
                cutoutErrorMessage = error.localizedDescription
                isExtracting = false
            }
        }
    }

    func clear() {
        extractionTask?.cancel()
        editID = UUID()
        originalImage = nil
        cutoutImage = nil
        selectedStyle = .original
        isExtracting = false
        cutoutErrorMessage = nil
        cutoutWasAttempted = false
    }
}
