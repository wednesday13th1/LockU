import Foundation

struct LockerDragSession: Sendable {
    let objectID: UUID
    let originalPlacement: LockerPlacement
    var currentPlacement: LockerPlacement
    mutating func update(to placement: LockerPlacement) { currentPlacement = placement }
    mutating func cancel() { currentPlacement = originalPlacement }
}

@MainActor
struct LockerPlacementCoordinator {
    let repository: DecorationRepository
    let engine: LockerPlacementEngine
    init(repository: DecorationRepository, engine: LockerPlacementEngine) {
        self.repository = repository
        self.engine = engine
    }
    init(repository: DecorationRepository) {
        self.init(repository: repository, engine: LockerPlacementEngine())
    }
    func move(_ item: LockerDecoration, by delta: CodablePoint) throws { var value = item; value.placement = engine.move(item.placement, by: delta); try repository.update(value) }
    func scale(_ item: LockerDecoration, by factor: Double) throws { var value = item; value.placement = engine.scale(item.placement, by: factor); try repository.update(value) }
    func rotate(_ item: LockerDecoration, by degrees: Double) throws { var value = item; value.placement = engine.rotate(item.placement, by: degrees); try repository.update(value) }
    func flip(_ item: LockerDecoration) throws { var value = item; value.placement = engine.flip(item.placement); try repository.update(value) }
    func bringToFront(_ item: LockerDecoration) throws { var value = item; value.placement = engine.bringToFront(item.placement, among: repository.decorations.map(\.placement)); try repository.update(value) }
}
