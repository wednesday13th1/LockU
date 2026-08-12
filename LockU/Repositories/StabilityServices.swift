import Foundation
import OSLog

enum LockUDataSchema { static let currentVersion = 2 }

@MainActor
struct MigrationCoordinator {
    let legacy: LegacyMigrationService
    @discardableResult
    func migrateIfNeeded() throws -> Bool {
        // Legacy adapter remains idempotent and marks completion only after every legacy step succeeds.
        try legacy.migrateIfNeeded()
    }
}

enum AppBootState {
    case launching, preparingStorage, migrating, recovering, loading, ready, failed(Error)
}

enum LockULogCategory: String { case boot = "BOOT", memory = "MEMORY", decoration = "DECORATION", storage = "STORAGE", metadata = "METADATA", workflow = "WORKFLOW", transaction = "TRANSACTION", placement = "PLACEMENT", migration = "MIGRATION", recovery = "RECOVERY", cache = "CACHE", error = "ERROR" }

enum LockULog {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LockU", category: "Stability")
    static func debug(_ category: LockULogCategory, _ message: String) { logger.debug("[\(category.rawValue, privacy: .public)] \(message, privacy: .public)") }
    static func error(_ category: LockULogCategory, _ message: String) { logger.error("[\(category.rawValue, privacy: .public)][ERROR] \(message, privacy: .public)") }
}

struct StorageRecoveryReport: Sendable {
    let missingMemoryMedia: [UUID]
    let missingDecorationMedia: [UUID]
    let orphanMemoryFiles: [String]
    let orphanDecorationFiles: [String]
    let duplicateMemoryIDs: Set<UUID>
    let duplicateDecorationIDs: Set<UUID>
    var hasIssues: Bool { !missingMemoryMedia.isEmpty || !missingDecorationMedia.isEmpty || !orphanMemoryFiles.isEmpty || !orphanDecorationFiles.isEmpty || !duplicateMemoryIDs.isEmpty || !duplicateDecorationIDs.isEmpty }
}

struct StorageHealthInspector {
    private let paths: LockUPaths
    private let fileManager: FileManager
    init(paths: LockUPaths, fileManager: FileManager = .default) { self.paths = paths; self.fileManager = fileManager }
    func inspect(memories: [MemoryRecord], decorations: [LockerDecoration]) -> StorageRecoveryReport {
        let memoryNames = Set(memories.flatMap { memory in
            [memory.imageFileName, memory.frontImageFileName, memory.backImageFileName, memory.videoThumbnailFileName]
                .compactMap { $0 }
        }); let decorationNames = Set(decorations.map(\.imageFileName))
        let missingMemoryIDs = memories.filter { memory in
            let posterMissing = !fileManager.fileExists(atPath: paths.memories.appendingPathComponent(memory.imageFileName).path)
            let videoMissing = memory.videoFileName.map {
                !fileManager.fileExists(atPath: paths.videos.appendingPathComponent($0).path)
            } ?? false
            let frontMissing = memory.frontImageFileName.map {
                !fileManager.fileExists(atPath: paths.memories.appendingPathComponent($0).path)
            } ?? false
            return posterMissing || videoMissing || frontMissing
        }.map(\.id)
        return StorageRecoveryReport(
            missingMemoryMedia: missingMemoryIDs,
            missingDecorationMedia: decorations.filter { !fileManager.fileExists(atPath: paths.decorations.appendingPathComponent($0.imageFileName).path) }.map(\.id),
            orphanMemoryFiles: mediaFiles(in: paths.memories).filter { !memoryNames.contains($0) },
            orphanDecorationFiles: mediaFiles(in: paths.decorations).filter { !decorationNames.contains($0) },
            duplicateMemoryIDs: duplicates(memories.map(\.id)), duplicateDecorationIDs: duplicates(decorations.map(\.id))
        )
    }
    private func mediaFiles(in directory: URL) -> [String] { ((try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []).map(\.lastPathComponent).filter { !$0.hasSuffix(".json") } }
    private func duplicates(_ ids: [UUID]) -> Set<UUID> { var seen = Set<UUID>(); return Set(ids.filter { !seen.insert($0).inserted }) }
}

enum RecoveryAction: Sendable { case reportMissingMemory(UUID), reportMissingDecoration(UUID), quarantineMemoryFile(String), quarantineDecorationFile(String), reportDuplicate(UUID) }

struct StorageRecoveryPlan: Sendable { let safeActions: [RecoveryAction]; let userAttention: [RecoveryAction] }

struct StorageRecoveryPlanner {
    func plan(for report: StorageRecoveryReport) -> StorageRecoveryPlan {
        StorageRecoveryPlan(
            safeActions: report.orphanMemoryFiles.map(RecoveryAction.quarantineMemoryFile) + report.orphanDecorationFiles.map(RecoveryAction.quarantineDecorationFile),
            userAttention: report.missingMemoryMedia.map(RecoveryAction.reportMissingMemory) + report.missingDecorationMedia.map(RecoveryAction.reportMissingDecoration) + report.duplicateMemoryIDs.map(RecoveryAction.reportDuplicate) + report.duplicateDecorationIDs.map(RecoveryAction.reportDuplicate)
        )
    }
}

struct QuarantineStorage {
    let root: URL
    init(paths: LockUPaths, fileManager: FileManager = .default) throws {
        root = paths.root.appendingPathComponent("Recovery", isDirectory: true)
        for name in ["OrphanMemories", "OrphanDecorations", "CorruptMetadata"] { try fileManager.createDirectory(at: root.appendingPathComponent(name, isDirectory: true), withIntermediateDirectories: true) }
    }
}

struct StorageRecoveryExecutor {
    // Explicit execution is intentionally opt-in. Boot only inspects and plans.
    func execute(_ plan: StorageRecoveryPlan) throws { guard plan.safeActions.isEmpty else { throw RecoveryFailure.unsafeRepairRequired } }
}
