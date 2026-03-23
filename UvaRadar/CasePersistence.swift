import Foundation

protocol CasePersistence {
    func load() throws -> PersistedCasePayload?
    func save(input: CaseInput?, events: [CapitalAdvanceEvent]) throws
    func clear() throws
}

struct JSONCasePersistence: CasePersistence {
    private let fileURL: URL

    init() {
        let fileManager = FileManager.default
        let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = (appSupport ?? fileManager.temporaryDirectory).appendingPathComponent("UvaRadar", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("case-state-v1.json")
    }

    func load() throws -> PersistedCasePayload? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(PersistedCasePayload.self, from: data)
    }

    func save(input: CaseInput?, events: [CapitalAdvanceEvent]) throws {
        let payload = PersistedCasePayload(version: 1, input: input, events: events)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(payload)
        try data.write(to: fileURL, options: [.atomic])
    }

    func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}

struct iCloudKVCasePersistence: CasePersistence {
    private let store = NSUbiquitousKeyValueStore.default
    private let key = "case-state-v1"
    private let fallback = JSONCasePersistence()

    func load() throws -> PersistedCasePayload? {
        if let data = store.data(forKey: key) {
            return try JSONDecoder().decode(PersistedCasePayload.self, from: data)
        }
        // Migrar datos locales existentes a iCloud en el primer launch
        if let local = try fallback.load() {
            try save(input: local.input, events: local.events)
            return local
        }
        return nil
    }

    func save(input: CaseInput?, events: [CapitalAdvanceEvent]) throws {
        let payload = PersistedCasePayload(version: 1, input: input, events: events)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(payload)
        store.set(data, forKey: key)
        store.synchronize()
        try? fallback.save(input: input, events: events)
    }

    func clear() throws {
        store.removeObject(forKey: key)
        store.synchronize()
        try fallback.clear()
    }
}
