import Foundation

protocol MemoryMetadataStoring {
    func load() throws -> [MemoryRecord]
    func save(_ records: [MemoryRecord]) throws
}

struct MemoryMetadataStore: MemoryMetadataStoring {
    private let store: SafeJSONStore<MemoryRecord>
    init(directory: URL) { store = SafeJSONStore(directory: directory, fileName: "memories.json") }
    func load() throws -> [MemoryRecord] { try store.load(validate: MemoryRecordValidator().isValid) }
    func save(_ records: [MemoryRecord]) throws { try store.save(records) }
}

protocol MemoryReflectionMetadataStoring {
    func load() throws -> [MemoryReflection]
    func save(_ records: [MemoryReflection]) throws
}

struct MemoryReflectionMetadataStore: MemoryReflectionMetadataStoring {
    private let store: SafeJSONStore<MemoryReflection>

    init(directory: URL) {
        store = SafeJSONStore(directory: directory, fileName: "memory-reflections.json")
    }

    func load() throws -> [MemoryReflection] {
        try store.load { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func save(_ records: [MemoryReflection]) throws {
        try store.save(records)
    }
}

protocol DecorationMetadataStoring {
    func load() throws -> [LockerDecoration]
    func save(_ records: [LockerDecoration]) throws
}

struct DecorationMetadataStore: DecorationMetadataStoring {
    private let store: SafeJSONStore<LockerDecoration>
    init(directory: URL) { store = SafeJSONStore(directory: directory, fileName: "decorations.json") }
    func load() throws -> [LockerDecoration] { try store.load(validate: LockerDecorationValidator().isValid) }
    func save(_ records: [LockerDecoration]) throws { try store.save(records) }
}
