import Foundation

nonisolated struct MemoryPresentationResolver {
    func resolve(_ record: MemoryRecord) -> MemoryPresentationStyle {
        record.presentationStyle ?? ((record.isSubjectCutout ?? false) ? .cutout : .digicam)
    }
}

nonisolated enum StoredImageFormat { case jpeg, png }
nonisolated struct ImageFormatPolicy { func format(for style: MemoryImageStyle) -> StoredImageFormat { style == .cutout ? .png : .jpeg } }
nonisolated struct DefaultMemoryPresentationPolicy {
    func presentation(for style: MemoryImageStyle, captureMode: CaptureMode) -> MemoryPresentationStyle {
        if style == .cutout { return .cutout }
        switch captureMode { case .camera, .photoLibrary: return .digicam; case .legacy: return .digicam }
    }
}

nonisolated struct PlacementPolicy {
    let minimumScale: Double; let maximumScale: Double; let minimumCoordinate: Double; let maximumCoordinate: Double
    static let locker = PlacementPolicy(minimumScale: 0.3, maximumScale: 3, minimumCoordinate: 0.04, maximumCoordinate: 0.96)
}

nonisolated struct LockerPlacementValidator {
    func isValid(_ value: LockerPlacement) -> Bool {
        value.position.x.isFinite && value.position.y.isFinite && value.scale.isFinite && value.rotationDegrees.isFinite && value.position.x >= 0 && value.position.x <= 1 && value.position.y >= 0 && value.position.y <= 1 && value.scale > 0
    }
}

nonisolated struct MemoryRecordValidator {
    func isValid(_ value: MemoryRecord) -> Bool {
        !value.imageFileName.isEmpty && ["jpg", "jpeg", "png"].contains((value.imageFileName as NSString).pathExtension.lowercased())
    }
}

nonisolated struct LockerDecorationValidator {
    private let placement = LockerPlacementValidator()
    func isValid(_ value: LockerDecoration) -> Bool { !value.imageFileName.isEmpty && placement.isValid(value.placement) }
}

nonisolated struct LockerZIndexService {
    func frontIndex(_ placements: [LockerPlacement]) -> Int { (placements.map(\.zIndex).max() ?? -1) + 1 }
    func backIndex(_ placements: [LockerPlacement]) -> Int { (placements.map(\.zIndex).min() ?? 1) - 1 }
    func needsNormalization(_ placements: [LockerPlacement]) -> Bool { placements.map { abs($0.zIndex) }.max() ?? 0 > 1_000 }
}
