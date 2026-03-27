import Foundation

enum StateStoreError: LocalizedError {
    case unreadableConfig(URL)
    case unwritableConfig(URL)

    var errorDescription: String? {
        switch self {
        case .unreadableConfig(let url):
            return "Khong the doc file trang thai tai \(url.path)."
        case .unwritableConfig(let url):
            return "Khong the ghi file trang thai tai \(url.path)."
        }
    }
}

final class StateStore: StateStoreProtocol {
    private let fileManager = FileManager.default
    private let customConfigURL: URL?
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    init(configURL: URL? = nil) {
        self.customConfigURL = configURL
    }

    func loadStates() throws -> [String: FeatureState] {
        let url = configURL()
        guard fileManager.fileExists(atPath: url.path) else {
            return [:]
        }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            throw StateStoreError.unreadableConfig(url)
        }

        var states: [String: FeatureState] = [:]
        for line in content.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }

            let featureAndStatus = parts[0].split(separator: "=", maxSplits: 1).map(String.init)
            guard featureAndStatus.count == 2 else { continue }

            states[featureAndStatus[0]] = FeatureState(status: featureAndStatus[1], timestamp: parts[1])
        }

        return states
    }

    func updateState(featureID: String, status: ActionStatus, timestamp: Date) throws {
        let url = configURL()
        ensureConfigFileExists(at: url)

        let fileHandle: FileHandle
        do {
            fileHandle = try FileHandle(forWritingTo: url)
        } catch {
            throw StateStoreError.unwritableConfig(url)
        }

        defer { try? fileHandle.close() }
        try fileHandle.seekToEnd()

        let value = status == .enabled ? "enabled" : "failed"
        let line = "\(featureID)=\(value)|\(dateFormatter.string(from: timestamp))\n"

        guard let data = line.data(using: .utf8) else {
            throw StateStoreError.unwritableConfig(url)
        }

        try fileHandle.write(contentsOf: data)
    }

    private func configURL() -> URL {
        customConfigURL ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".macbook_optimizer_state.conf")
    }

    private func ensureConfigFileExists(at url: URL) {
        let directory = url.deletingLastPathComponent()
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(atPath: url.path, contents: nil)
        }
    }
}
