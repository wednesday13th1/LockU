import Foundation

struct LockerPlacementEngine {
    let policy: PlacementPolicy
    private let zIndex = LockerZIndexService()
    init(policy: PlacementPolicy = .locker) { self.policy = policy }
    func move(_ placement: LockerPlacement, by delta: CodablePoint) -> LockerPlacement {
        var result = placement; result.position.x += delta.x; result.position.y += delta.y; return clampToBounds(result)
    }
    func scale(_ placement: LockerPlacement, by factor: Double) -> LockerPlacement { var result = placement; result.scale = min(max(result.scale * factor, policy.minimumScale), policy.maximumScale); return result }
    func rotate(_ placement: LockerPlacement, by degrees: Double) -> LockerPlacement { var result = placement; result.rotationDegrees += degrees; return result }
    func flip(_ placement: LockerPlacement) -> LockerPlacement { var result = placement; result.isFlipped.toggle(); return result }
    func clampToBounds(_ placement: LockerPlacement) -> LockerPlacement { var result = placement; guard LockerPlacementValidator().isValid(result) else { return LockerPlacement(position: CodablePoint(x: 0.5, y: 0.5), scale: 1, rotationDegrees: 0, isFlipped: false, zIndex: placement.zIndex) }; result.position.x = min(max(result.position.x, policy.minimumCoordinate), policy.maximumCoordinate); result.position.y = min(max(result.position.y, policy.minimumCoordinate), policy.maximumCoordinate); result.scale = min(max(result.scale, policy.minimumScale), policy.maximumScale); return result }
    func bringToFront(_ placement: LockerPlacement, among placements: [LockerPlacement]) -> LockerPlacement { var result = placement; result.zIndex = zIndex.frontIndex(placements); return result }
    func sendToBack(_ placement: LockerPlacement, among placements: [LockerPlacement]) -> LockerPlacement { var result = placement; result.zIndex = zIndex.backIndex(placements); return result }
    func normalizeZIndexes(_ placements: [LockerPlacement]) -> [LockerPlacement] { placements.sorted { $0.zIndex < $1.zIndex }.enumerated().map { index, item in var value = item; value.zIndex = index; return value } }
}
