import Foundation
import Security

/// Global authorization service that authenticates once and caches credentials for the entire app session
/// Uses osascript with "with administrator privileges" which caches authorization in the same process
final class AuthorizationService: ObservableObject {
    static let shared = AuthorizationService()
    
    @Published private(set) var isAuthorized = false
    @Published private(set) var authorizationError: String?
    
    private init() {}
    
    /// Request authorization once at app startup
    /// This will prompt for Touch ID/password once
    func requestAuthorization() async throws {
        guard !isAuthorized else { return }
        
        // Simple test command to trigger authorization
        let script = """
        do shell script "echo 'Authorization granted'" with administrator privileges
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let error = String(data: data, encoding: .utf8) ?? "Authorization failed"
            authorizationError = error
            throw AuthorizationError.authorizationFailed
        }
        
        isAuthorized = true
        authorizationError = nil
    }
    
    /// Execute a command with administrator privileges
    /// Each command will use osascript which may prompt if authorization expired
    func executeWithPrivileges(command: String, arguments: [String]) async throws -> String {
        // Build the full command
        let fullCommand = command + " " + arguments.joined(separator: " ")
        return try await executeShellCommandWithPrivileges(fullCommand)
    }

    func executeShellCommandWithPrivileges(_ fullCommand: String) async throws -> String {
        let escapedCommand = fullCommand
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        do shell script "\(escapedCommand)" with administrator privileges
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        guard process.terminationStatus == 0 else {
            throw AuthorizationError.commandFailed(output: output)
        }
        
        return output
    }
    
    /// Reset authorization
    func resetAuthorization() {
        isAuthorized = false
        authorizationError = nil
    }
}

enum AuthorizationError: Error, LocalizedError {
    case notAuthorized
    case authorizationFailed
    case commandFailed(output: String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Not authorized. Please restart the app and grant authorization."
        case .authorizationFailed:
            return "Authorization failed. Please try again."
        case .commandFailed(let output):
            return "Command failed: \(output)"
        }
    }
}
