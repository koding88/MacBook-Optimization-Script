import Foundation

enum SystemCommandExecutorError: LocalizedError {
    case invalidCommand(String)
    case administratorExecutionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidCommand(let command):
            return "Khong the phan tich command: \(command)"
        case .administratorExecutionFailed(let message):
            return message
        }
    }
}

final class SystemCommandExecutor: SystemCommandExecuting {
    func execute(_ request: CommandRequest) async throws -> CommandExecutionResult {
        if request.requiresAdministrator {
            return try await executeWithAdministratorPrivileges(request.command)
        }
        return try await executeRegular(request.command)
    }

    private func executeRegular(_ command: String) async throws -> CommandExecutionResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self)
        return CommandExecutionResult(output: output, exitCode: process.terminationStatus)
    }

    private func executeWithAdministratorPrivileges(_ command: String) async throws -> CommandExecutionResult {
        let escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = "do shell script \"\(escapedCommand)\" with administrator privileges"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self)

        if process.terminationStatus != 0 {
            throw SystemCommandExecutorError.administratorExecutionFailed(output.isEmpty ? "Thuc thi administrator command that bai." : output)
        }

        return CommandExecutionResult(output: output, exitCode: process.terminationStatus)
    }
}
