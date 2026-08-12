import Foundation

enum StorageMode: Sendable { case persistent, recoveryTemporary }

@MainActor
final class LockUDependencyContainer {
    let paths: LockUPaths
    let storageMode: StorageMode
    let memoryRepository: MemoryRepository
    let decorationRepository: DecorationRepository
    let settingsRepository: LockerSettingsRepository
    let backgroundRepository: BackgroundRepository
    let reflectionRepository: MemoryReflectionRepository

    init(fileManager: FileManager = .default) {
        if let persistentPaths = try? LockUPaths(fileManager: fileManager) {
            paths = persistentPaths; storageMode = .persistent
        } else {
            let recoveryRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("LockU-Recovery", isDirectory: true)
            paths = LockUPaths(recoveryRoot: recoveryRoot, fileManager: fileManager); storageMode = .recoveryTemporary
        }
        memoryRepository = MemoryRepository(paths: paths)
        decorationRepository = DecorationRepository(paths: paths)
        settingsRepository = LockerSettingsRepository(paths: paths)
        backgroundRepository = BackgroundRepository(paths: paths)
        reflectionRepository = MemoryReflectionRepository(paths: paths)
    }
}

struct BootAvailability: Sendable {
    var memory = false; var decoration = false; var settings = false; var background = false
    var isUsable: Bool { memory || decoration || settings || background }
}

@MainActor
final class LockUBootCoordinator {
    private let dependencies: LockUDependencyContainer
    init(dependencies: LockUDependencyContainer) { self.dependencies = dependencies }

    func boot(state: (AppBootState) -> Void) -> (BootAvailability, Error?) {
        var availability = BootAvailability(); var firstError: Error?
        state(.preparingStorage)
        state(.loading)
        attempt({ try dependencies.settingsRepository.reload() }, success: { availability.settings = true }, onError: { firstError = firstError ?? $0 })
        attempt({ try dependencies.memoryRepository.reload() }, success: { availability.memory = true }, onError: { firstError = firstError ?? $0 })
        attempt({ try dependencies.decorationRepository.reload() }, success: { availability.decoration = true }, onError: { firstError = firstError ?? $0 })
        attempt({ try dependencies.reflectionRepository.reload() }, success: {}, onError: { LockULog.error(.metadata, "Reflection history could not be loaded: \($0.localizedDescription)") })
        dependencies.backgroundRepository.reload(); availability.background = true

        state(.migrating)
        attempt({ try MigrationCoordinator(legacy: LegacyMigrationService(memories: dependencies.memoryRepository, decorations: dependencies.decorationRepository, settings: dependencies.settingsRepository, backgrounds: dependencies.backgroundRepository)).migrateIfNeeded() }, success: {}, onError: { firstError = firstError ?? $0 })
        if availability.memory { attempt({ try dependencies.memoryRepository.reload() }, success: {}, onError: { firstError = firstError ?? $0 }) }
        if availability.decoration { attempt({ try dependencies.decorationRepository.reload() }, success: {}, onError: { firstError = firstError ?? $0 }) }

        state(.recovering)
        let report = StorageHealthInspector(paths: dependencies.paths).inspect(memories: dependencies.memoryRepository.memories, decorations: dependencies.decorationRepository.decorations)
        if report.hasIssues { LockULog.debug(.recovery, "health issues detected; no automatic deletion") }
        state(availability.isUsable ? .ready : .failed(firstError ?? BootFailure.noSubsystemAvailable))
        return (availability, firstError)
    }

    private func attempt(_ operation: () throws -> Void, success: () -> Void, onError: (Error) -> Void) { do { try operation(); success() } catch { onError(error) } }
}

enum BootFailure: Error { case noSubsystemAvailable, temporaryStorageMode }
