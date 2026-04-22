import Foundation

enum RestoreBaselineStoreError: LocalizedError {
    case unreadable(URL)
    case unwritable(URL)

    var errorDescription: String? {
        switch self {
        case .unreadable(let url):
            return "Unable to read restore baselines at \(url.path)."
        case .unwritable(let url):
            return "Unable to write restore baselines at \(url.path)."
        }
    }
}

final class RestoreBaselineStore: RestoreBaselineStoreProtocol {
    private let fileManager = FileManager.default
    private let customURL: URL?

    init(fileURL: URL? = nil) {
        self.customURL = fileURL
    }

    func loadBaseline(for actionID: String) throws -> RestoreBaseline? {
        try loadAll()[actionID]
    }

    func saveBaseline(_ baseline: RestoreBaseline, for actionID: String) throws {
        var baselines = try loadAll()
        baselines[actionID] = baseline
        try writeAll(baselines)
    }

    func removeBaseline(for actionID: String) throws {
        var baselines = try loadAll()
        baselines[actionID] = nil
        try writeAll(baselines)
    }

    func removeBaselines(for actionIDs: [String]) throws {
        guard !actionIDs.isEmpty else { return }
        var baselines = try loadAll()
        for actionID in actionIDs {
            baselines[actionID] = nil
        }
        try writeAll(baselines)
    }

    private func loadAll() throws -> [String: RestoreBaseline] {
        let url = fileURL()
        guard fileManager.fileExists(atPath: url.path) else {
            return [:]
        }

        do {
            let data = try Data(contentsOf: url)
            guard !data.isEmpty else { return [:] }
            return try JSONDecoder().decode([String: RestoreBaseline].self, from: data)
        } catch {
            throw RestoreBaselineStoreError.unreadable(url)
        }
    }

    private func writeAll(_ baselines: [String: RestoreBaseline]) throws {
        let url = fileURL()
        let directory = url.deletingLastPathComponent()
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        do {
            let data = try JSONEncoder().encode(baselines)
            try data.write(to: url, options: .atomic)
        } catch {
            throw RestoreBaselineStoreError.unwritable(url)
        }
    }

    private func fileURL() -> URL {
        customURL ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".macbook_optimizer_restore_baselines.json")
    }
}
