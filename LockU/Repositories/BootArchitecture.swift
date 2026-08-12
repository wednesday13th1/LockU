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

struct EssentialBootResult {
    let availability: BootAvailability
    let error: Error?
}

struct DeferredBootResult {
    let didMigrate: Bool
    let error: Error?
}

@MainActor
final class LockUBootCoordinator {
    private let dependencies: LockUDependencyContainer
    init(dependencies: LockUDependencyContainer) { self.dependencies = dependencies }

    func performEssentialBoot(state: (AppBootState) -> Void) async -> EssentialBootResult {
        var availability = BootAvailability(); var firstError: Error?
        state(.preparingStorage)
        state(.loading)
        attempt({ try dependencies.settingsRepository.reload() }, success: { availability.settings = true }, onError: { firstError = firstError ?? $0 })
        await Task.yield()
        attempt({ try dependencies.memoryRepository.reload() }, success: { availability.memory = true }, onError: { firstError = firstError ?? $0 })
        await Task.yield()
        attempt({ try dependencies.decorationRepository.reload() }, success: { availability.decoration = true }, onError: { firstError = firstError ?? $0 })
        await Task.yield()
        dependencies.backgroundRepository.reload(); availability.background = true

        let finalState: AppBootState = availability.isUsable
            ? .ready
            : .failed(firstError ?? BootFailure.noSubsystemAvailable)
        state(finalState)
        return EssentialBootResult(availability: availability, error: firstError)
    }

    func performDeferredBoot(state: (AppBootState) -> Void) async -> DeferredBootResult {
        var firstError: Error?
        var didMigrate = false

        attempt(
            { try dependencies.reflectionRepository.reload() },
            success: {},
            onError: {
                firstError = firstError ?? $0
                LockULog.error(.metadata, "Reflection history could not be loaded: \($0.localizedDescription)")
            }
        )
        await Task.yield()

        state(.migrating)
        do {
            didMigrate = try MigrationCoordinator(
                legacy: LegacyMigrationService(
                    memories: dependencies.memoryRepository,
                    decorations: dependencies.decorationRepository,
                    settings: dependencies.settingsRepository,
                    backgrounds: dependencies.backgroundRepository
                )
            ).migrateIfNeeded()
        } catch {
            firstError = firstError ?? error
        }
        await Task.yield()

        if didMigrate {
            attempt({ try dependencies.memoryRepository.reload() }, success: {}, onError: { firstError = firstError ?? $0 })
            await Task.yield()
            attempt({ try dependencies.decorationRepository.reload() }, success: {}, onError: { firstError = firstError ?? $0 })
            dependencies.backgroundRepository.reload()
        }

        state(.recovering)
        let report = StorageHealthInspector(paths: dependencies.paths).inspect(memories: dependencies.memoryRepository.memories, decorations: dependencies.decorationRepository.decorations)
        if report.hasIssues { LockULog.debug(.recovery, "health issues detected; no automatic deletion") }
        state(.ready)
        return DeferredBootResult(didMigrate: didMigrate, error: firstError)
    }

    private func attempt(_ operation: () throws -> Void, success: () -> Void, onError: (Error) -> Void) { do { try operation(); success() } catch { onError(error) } }
}

enum BootFailure: Error { case noSubsystemAvailable, temporaryStorageMode }
