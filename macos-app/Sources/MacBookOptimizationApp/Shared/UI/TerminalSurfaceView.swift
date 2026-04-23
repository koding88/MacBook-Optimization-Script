import SwiftUI

enum TerminalRenderStrategy: Equatable {
    case replace(String)
    case animate(from: String, to: String)
}

enum TerminalRenderPlanner {
    static func strategy(current: String, incoming: String, keyChanged: Bool) -> TerminalRenderStrategy {
        if keyChanged {
            return incoming.isEmpty ? .replace("") : .animate(from: "", to: incoming)
        }

        if current.isEmpty {
            return incoming.isEmpty ? .replace("") : .animate(from: "", to: incoming)
        }

        if incoming.hasPrefix(current), incoming.count > current.count {
            return .animate(from: current, to: incoming)
        }

        return .replace(incoming)
    }
}

enum TerminalSurfaceRole {
    case liveOutput
    case commandPreview
}

private enum TerminalPalette {
    static let background = Color(red: 0.02, green: 0.03, blue: 0.055)
    static let chrome = Color(red: 0.055, green: 0.08, blue: 0.13)
    static let body = Color(red: 0.84, green: 0.93, blue: 0.98)
    static let muted = Color(red: 0.49, green: 0.61, blue: 0.72)
    static let section = Color(red: 0.45, green: 0.88, blue: 1.0)
    static let command = Color(red: 0.24, green: 0.79, blue: 1.0)
    static let keyword = Color(red: 0.66, green: 0.60, blue: 0.98)
    static let option = Color(red: 1.0, green: 0.73, blue: 0.28)
    static let string = Color(red: 0.42, green: 0.90, blue: 0.73)
    static let variable = Color(red: 1.0, green: 0.53, blue: 0.71)
    static let path = Color(red: 0.39, green: 0.74, blue: 1.0)
    static let value = Color(red: 0.79, green: 0.88, blue: 0.97)
    static let success = Color(red: 0.28, green: 0.90, blue: 0.60)
    static let warning = Color(red: 1.0, green: 0.76, blue: 0.34)
    static let danger = Color(red: 1.0, green: 0.45, blue: 0.47)
    static let operatorToken = Color(red: 0.53, green: 0.67, blue: 0.79)
    static let prompt = Color(red: 0.16, green: 0.86, blue: 1.0)
    static let ip = Color(red: 0.53, green: 0.82, blue: 1.0)
}

enum TerminalDisplayFormatter {
    static func displayText(for output: String, role: TerminalSurfaceRole) -> String {
        let normalized = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "" }

        switch role {
        case .commandPreview:
            return formatCommandPreview(normalized)
        case .liveOutput:
            return normalized
                .components(separatedBy: .newlines)
                .map(formatTranscriptLine)
                .joined(separator: "\n")
        }
    }

    static func formatCommandPreview(_ command: String) -> String {
        let structuralLines = splitStructuralLines(command)
        let indentedLines = indentShellLines(structuralLines)
        return indentedLines
            .flatMap { wrapLine($0, width: 76) }
            .joined(separator: "\n")
    }

    private static func formatTranscriptLine(_ line: String) -> String {
        guard line.hasPrefix("$ ") else { return line }

        let command = String(line.dropFirst(2))
        let formatted = formatCommandPreview(command).components(separatedBy: .newlines)

        return formatted.enumerated().map { index, fragment in
            index == 0 ? "$ " + fragment : "  " + fragment
        }.joined(separator: "\n")
    }

    private static func wrap(_ text: String, width: Int) -> String {
        text
            .components(separatedBy: .newlines)
            .flatMap { wrapLine($0, width: width) }
            .joined(separator: "\n")
    }

    private static func splitStructuralLines(_ command: String) -> [String] {
        var lines: [String] = []
        var current = ""
        let characters = Array(command)
        var index = 0
        var inSingleQuote = false
        var inDoubleQuote = false
        var isEscaped = false

        func flushCurrent() {
            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                lines.append(trimmed)
            }
            current = ""
        }

        func skipInlineWhitespace() {
            while index < characters.count, characters[index].isWhitespace {
                index += 1
            }
        }

        while index < characters.count {
            let character = characters[index]
            let previous = index > 0 ? characters[index - 1] : nil

            if isEscaped {
                current.append(character)
                isEscaped = false
                index += 1
                continue
            }

            if character == "\\" {
                current.append(character)
                isEscaped = true
                index += 1
                continue
            }

            if character == "'" && !inDoubleQuote {
                inSingleQuote.toggle()
                current.append(character)
                index += 1
                continue
            }

            if character == "\"" && !inSingleQuote {
                inDoubleQuote.toggle()
                current.append(character)
                index += 1
                continue
            }

            if !inSingleQuote && !inDoubleQuote {
                if character == "{" && previous != "$" {
                    current.append(character)
                    flushCurrent()
                    index += 1
                    skipInlineWhitespace()
                    continue
                }

                if character == "}" && previous != "$" {
                    flushCurrent()
                    current.append(character)
                    index += 1
                    if index < characters.count, characters[index] == ";" {
                        current.append(";")
                        index += 1
                    }
                    flushCurrent()
                    skipInlineWhitespace()
                    continue
                }

                if character == ";" {
                    current.append(character)
                    flushCurrent()
                    index += 1
                    skipInlineWhitespace()
                    continue
                }

                if character == "&" || character == "|" {
                    if index + 1 < characters.count, characters[index + 1] == character {
                        current.append(character)
                        current.append(character)
                        flushCurrent()
                        index += 2
                        skipInlineWhitespace()
                        continue
                    }

                    if character == "|" {
                        current.append(character)
                        flushCurrent()
                        index += 1
                        skipInlineWhitespace()
                        continue
                    }
                }
            }

            current.append(character)
            index += 1
        }

        flushCurrent()

        return lines.flatMap(expandShellStructure)
    }

    private static func expandShellStructure(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if trimmed.hasPrefix("then ") {
            let remainder = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
            return remainder.isEmpty ? ["then"] : ["then", remainder]
        }

        if trimmed.hasPrefix("else ") {
            let remainder = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
            return remainder.isEmpty ? ["else"] : ["else", remainder]
        }

        if trimmed.hasPrefix("do ") {
            let remainder = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
            return remainder.isEmpty ? ["do"] : ["do", remainder]
        }

        return [trimmed]
    }

    private static func indentShellLines(_ lines: [String]) -> [String] {
        var indented: [String] = []
        var indentationLevel = 0

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if shouldDedentBeforeLine(line) {
                indentationLevel = max(indentationLevel - 1, 0)
            }

            let prefix = String(repeating: "  ", count: indentationLevel)
            indented.append(prefix + line)

            if shouldIndentAfterLine(line) {
                indentationLevel += 1
            }
        }

        return indented
    }

    private static func shouldDedentBeforeLine(_ line: String) -> Bool {
        line == "else" || line.hasPrefix("else ")
            || line == "fi"
            || line == "done"
            || line == "}"
            || line == "};"
    }

    private static func shouldIndentAfterLine(_ line: String) -> Bool {
        line == "then"
            || line == "do"
            || line == "{"
            || line.hasSuffix("{")
            || line == "else"
    }

    private static func wrapLine(_ line: String, width: Int) -> [String] {
        guard line.count > width else { return [line] }

        let indentation = String(line.prefix { $0 == " " || $0 == "\t" })
        let baseContent = line.trimmingCharacters(in: .whitespaces)
        var remaining = baseContent
        var wrapped: [String] = []
        var firstLine = true

        while remaining.count > width {
            let limitIndex = remaining.index(remaining.startIndex, offsetBy: min(width, remaining.count))
            let prefix = String(remaining[..<limitIndex])
            let breakIndex = prefix.lastIndex(where: { $0 == " " || $0 == "|" || $0 == "&" || $0 == ";" }) ?? limitIndex
            let chunk = String(remaining[..<breakIndex]).trimmingCharacters(in: .whitespaces)
            wrapped.append((firstLine ? indentation : indentation + "  ") + chunk)

            remaining = String(remaining[breakIndex...]).trimmingCharacters(in: .whitespaces)
            firstLine = false
        }

        if !remaining.isEmpty {
            wrapped.append((firstLine ? indentation : indentation + "  ") + remaining)
        }

        return wrapped
    }
}

enum TerminalAttributedFormatter {
    static func attributedText(for text: String, role: TerminalSurfaceRole, emptyMessage: String) -> AttributedString {
        let content = text.isEmpty ? emptyMessage : text
        let lines = content.components(separatedBy: .newlines)
        var result = AttributedString()

        for (index, line) in lines.enumerated() {
            if text.isEmpty {
                result += segment(line, color: TerminalPalette.muted)
            } else {
                result += styledLine(line, role: role)
            }

            if index < lines.count - 1 {
                result += segment("\n", color: TerminalPalette.body)
            }
        }

        return result
    }

    private static func styledLine(_ line: String, role: TerminalSurfaceRole) -> AttributedString {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if line.hasPrefix("$ ") {
            return promptLine(line)
        }

        if looksLikeContinuationCommand(line) {
            return continuationCommandLine(line)
        }

        if trimmed.isEmpty {
            return segment(line, color: TerminalPalette.body)
        }

        if isSectionHeader(trimmed) {
            return segment(line, color: TerminalPalette.section)
        }

        if let attributed = hostEntryLine(line) {
            return attributed
        }

        if let attributed = colonValueLine(line) {
            return attributed
        }

        if let attributed = plistAssignmentLine(line) {
            return attributed
        }

        if role == .commandPreview {
            return commandTokenLine(line)
        }

        return segment(line, color: TerminalPalette.body)
    }

    private static func promptLine(_ line: String) -> AttributedString {
        var result = segment("$ ", color: TerminalPalette.prompt)
        result += commandTokenLine(String(line.dropFirst(2)))
        return result
    }

    private static func continuationCommandLine(_ line: String) -> AttributedString {
        let indentation = line.prefix { $0 == " " || $0 == "\t" }
        var result = segment(String(indentation), color: TerminalPalette.body)
        result += commandTokenLine(String(line.dropFirst(indentation.count)))
        return result
    }

    private static func commandTokenLine(_ line: String) -> AttributedString {
        var result = AttributedString()
        var hasSeenCommand = false

        for token in tokenizePreservingWhitespace(line) {
            if token.trimmingCharacters(in: .whitespaces).isEmpty {
                result += segment(token, color: TerminalPalette.body)
                continue
            }

            if isShellKeyword(token) {
                result += segment(token, color: TerminalPalette.keyword)
                continue
            }

            if isOperator(token) {
                result += segment(token, color: TerminalPalette.operatorToken)
                continue
            }

            if token.hasPrefix("-") {
                result += segment(token, color: TerminalPalette.option)
                continue
            }

            if token.first == "'" || token.first == "\"" {
                result += segment(token, color: TerminalPalette.string)
                continue
            }

            if token.contains("$(") || token.hasPrefix("$") || token.contains("=${") {
                result += segment(token, color: TerminalPalette.variable)
                continue
            }

            if let assignmentIndex = token.firstIndex(of: "="), !token.hasPrefix("="), !token.hasPrefix("=="), !token.contains(" = ") {
                let name = String(token[..<assignmentIndex])
                let value = String(token[token.index(after: assignmentIndex)...])
                result += segment(name, color: TerminalPalette.variable)
                result += segment("=", color: TerminalPalette.operatorToken)
                result += segment(value, color: valueColor(for: value))
                continue
            }

            if token.hasPrefix("/") || token.contains("/etc/") || token.contains("/var/") || token.contains(".apple.com") {
                result += segment(token, color: TerminalPalette.path)
                continue
            }

            if token.range(of: #"^\d+(\.\d+)?$"#, options: .regularExpression) != nil {
                result += segment(token, color: TerminalPalette.option)
                continue
            }

            if !hasSeenCommand {
                result += segment(token, color: TerminalPalette.command)
                hasSeenCommand = true
                continue
            }

            result += segment(token, color: valueColor(for: token))
        }

        return result
    }

    private static func colonValueLine(_ line: String) -> AttributedString? {
        guard let range = line.range(of: ":"), !line.trimmingCharacters(in: .whitespaces).hasPrefix("{") else {
            return nil
        }

        let leadingWhitespace = line.prefix { $0 == " " || $0 == "\t" }
        let label = String(line[..<range.lowerBound])
        let value = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)

        guard !label.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }

        var result = segment(String(leadingWhitespace), color: TerminalPalette.body)
        result += segment(label.trimmingCharacters(in: .whitespaces) + ":", color: TerminalPalette.muted)
        result += segment(" ", color: TerminalPalette.body)
        result += segment(value, color: valueColor(for: value))
        return result
    }

    private static func plistAssignmentLine(_ line: String) -> AttributedString? {
        guard let range = line.range(of: " = ") else { return nil }

        let leadingWhitespace = line.prefix { $0 == " " || $0 == "\t" }
        let key = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        var value = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        let suffix = value.hasSuffix(";") ? ";" : ""
        if !suffix.isEmpty {
            value.removeLast()
        }

        var result = segment(String(leadingWhitespace), color: TerminalPalette.body)
        result += segment(key, color: TerminalPalette.command)
        result += segment(" = ", color: TerminalPalette.operatorToken)
        result += segment(value, color: valueColor(for: value))
        if !suffix.isEmpty {
            result += segment(suffix, color: TerminalPalette.operatorToken)
        }
        return result
    }

    private static func hostEntryLine(_ line: String) -> AttributedString? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("0.0.0.0 ") else { return nil }

        let indentation = line.prefix { $0 == " " || $0 == "\t" }
        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return nil }

        var result = segment(String(indentation), color: TerminalPalette.body)
        result += segment(String(parts[0]), color: TerminalPalette.ip)
        result += segment(" ", color: TerminalPalette.body)
        result += segment(String(parts[1]), color: TerminalPalette.path)
        return result
    }

    private static func valueColor(for value: String) -> Color {
        let normalized = value.lowercased()

        if normalized == "yes" || normalized == "present" || normalized == "currently enrolled" || normalized == "likely yes" {
            return TerminalPalette.success
        }

        if normalized == "no" || normalized == "absent" || normalized == "not currently enrolled" {
            return TerminalPalette.body
        }

        if normalized.contains("warning") || normalized.contains("review") {
            return TerminalPalette.warning
        }

        if normalized.contains("unavailable") || normalized.contains("error") || normalized.contains("failed") {
            return TerminalPalette.danger
        }

        if normalized.hasPrefix("http://") || normalized.hasPrefix("https://") || normalized.contains(".apple.com") {
            return TerminalPalette.path
        }

        if value.first == "\"" || value.first == "'" {
            return TerminalPalette.string
        }

        return TerminalPalette.value
    }

    private static func tokenizePreservingWhitespace(_ line: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inWhitespace = false

        for character in line {
            let isWhitespace = character.isWhitespace
            if current.isEmpty {
                current.append(character)
                inWhitespace = isWhitespace
                continue
            }

            if isWhitespace == inWhitespace {
                current.append(character)
            } else {
                tokens.append(current)
                current = String(character)
                inWhitespace = isWhitespace
            }
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }

    private static func isShellKeyword(_ token: String) -> Bool {
        [
            "if", "then", "else", "fi", "do", "done", "for", "while", "in",
            "trap", "true", "false", "function"
        ].contains(token)
    }

    private static func isOperator(_ token: String) -> Bool {
        ["&&", "||", "|", ";", "(", ")", "{", "}", "[", "]"].contains(token)
    }

    private static func isSectionHeader(_ trimmed: String) -> Bool {
        trimmed.hasSuffix(":")
            && !trimmed.hasPrefix("$")
            && !trimmed.contains(" = ")
    }

    private static func looksLikeContinuationCommand(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard line.hasPrefix("  ") || line.hasPrefix("\t") else { return false }

        return trimmed.contains("&&")
            || trimmed.contains("||")
            || trimmed.contains("$(")
            || trimmed.hasPrefix("if ")
            || trimmed.hasPrefix("printf ")
            || trimmed.hasPrefix("profiles ")
            || trimmed.hasPrefix("awk ")
            || trimmed.hasPrefix("grep ")
            || trimmed.contains("/etc/hosts")
    }

    private static func segment(_ string: String, color: Color) -> AttributedString {
        var attributed = AttributedString(string)
        attributed.foregroundColor = color
        return attributed
    }
}

struct TerminalCommandPreview: View {
    let title: String
    let command: String

    private var previewHeight: CGFloat {
        let formatted = TerminalDisplayFormatter.displayText(for: command, role: .commandPreview)
        let lineCount = max(formatted.components(separatedBy: .newlines).count, 2)
        return min(max(CGFloat(lineCount) * 20 + 30, 96), 220)
    }

    var body: some View {
        TerminalSurfaceView(
            title: title,
            output: command,
            emptyMessage: "",
            animateKey: "command-preview-\(command)",
            minHeight: previewHeight,
            maxHeight: previewHeight,
            role: .commandPreview,
            animateChanges: false,
            showsCursor: false,
            followOutput: false
        )
    }
}

struct TerminalSurfaceView: View {
    let title: String?
    let output: String
    let emptyMessage: String
    let animateKey: String
    let minHeight: CGFloat
    let maxHeight: CGFloat?
    var role: TerminalSurfaceRole = .liveOutput
    var animateChanges: Bool = true
    var showsCursor: Bool = true
    var followOutput: Bool = true

    @State private var displayedOutput = ""
    @State private var cursorVisible = true
    @State private var renderTask: Task<Void, Never>?
    @State private var cursorTask: Task<Void, Never>?
    @State private var lastAnimateKey = ""
    @State private var scrollPulse = 0

    private let bottomAnchorID = "terminal-bottom-anchor"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(attributedBody)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)

                        if showsCursor {
                            Text(cursorVisible ? "▍" : " ")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundStyle(TerminalPalette.prompt)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(bottomAnchorID)
                    }
                    .padding(16)
                }
                .frame(minHeight: minHeight, maxHeight: maxHeight)
                .background(Color(red: 0.03, green: 0.04, blue: 0.06))
                .onAppear {
                    scrollToBottom(using: proxy)
                }
                .onChange(of: scrollPulse) { _ in
                    scrollToBottom(using: proxy)
                }
            }
        }
        .background(Color(red: 0.06, green: 0.07, blue: 0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 8)
        .onAppear {
            prepareRender(for: output, animateKey: animateKey)
            startCursorLoop()
        }
        .onDisappear {
            renderTask?.cancel()
            cursorTask?.cancel()
        }
        .onChange(of: output) { newOutput in
            prepareRender(for: newOutput, animateKey: animateKey)
        }
        .onChange(of: animateKey) { newKey in
            prepareRender(for: output, animateKey: newKey, forceReset: true)
        }
    }

    private var attributedBody: AttributedString {
        TerminalAttributedFormatter.attributedText(
            for: displayedOutput,
            role: role,
            emptyMessage: emptyMessage
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.36)).frame(width: 9, height: 9)
            Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.24)).frame(width: 9, height: 9)
            Circle().fill(Color(red: 0.39, green: 0.79, blue: 0.57)).frame(width: 9, height: 9)

            Spacer()

            Text(title ?? "terminal")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.58))
                .textCase(.uppercase)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(red: 0.08, green: 0.09, blue: 0.11))
    }

    private func prepareRender(for rawOutput: String, animateKey: String, forceReset: Bool = false) {
        let formatted = TerminalDisplayFormatter.displayText(for: rawOutput, role: role)
        let keyChanged = forceReset || lastAnimateKey != animateKey
        lastAnimateKey = animateKey

        if !animateChanges {
            apply(.replace(formatted))
            return
        }

        apply(
            TerminalRenderPlanner.strategy(
                current: displayedOutput,
                incoming: formatted,
                keyChanged: keyChanged
            )
        )
    }

    private func apply(_ strategy: TerminalRenderStrategy) {
        renderTask?.cancel()

        switch strategy {
        case .replace(let value):
            displayedOutput = value
            requestScroll()
        case .animate(let start, let target):
            displayedOutput = start

            guard target.count > start.count else { return }

            let suffix = Array(target.dropFirst(start.count))
            renderTask = Task { @MainActor in
                var index = 0
                var chunksSinceLastScroll = 0

                while index < suffix.count {
                    guard !Task.isCancelled else { return }

                    let remaining = suffix.count - index
                    let totalLength = target.count
                    let chunkSize: Int
                    let delayNanoseconds: UInt64
                    let newlinePauseNanoseconds: UInt64
                    let scrollBatchSize: Int

                    switch totalLength {
                    case 1_600...:
                        chunkSize = 48
                        delayNanoseconds = remaining < 120 ? 3_800_000 : 2_400_000
                        newlinePauseNanoseconds = 10_000_000
                        scrollBatchSize = 3
                    case 900...:
                        chunkSize = 30
                        delayNanoseconds = remaining < 90 ? 5_000_000 : 3_400_000
                        newlinePauseNanoseconds = 13_000_000
                        scrollBatchSize = 2
                    case 450...:
                        chunkSize = 18
                        delayNanoseconds = remaining < 56 ? 7_200_000 : 5_400_000
                        newlinePauseNanoseconds = 15_000_000
                        scrollBatchSize = 2
                    case 180...:
                        chunkSize = 8
                        delayNanoseconds = remaining < 28 ? 11_500_000 : 8_800_000
                        newlinePauseNanoseconds = 18_000_000
                        scrollBatchSize = 1
                    default:
                        chunkSize = 2
                        delayNanoseconds = 20_000_000
                        newlinePauseNanoseconds = 20_000_000
                        scrollBatchSize = 1
                    }

                    let nextIndex = min(index + chunkSize, suffix.count)
                    let appendedChunk = suffix[index..<nextIndex]
                    displayedOutput.append(contentsOf: appendedChunk)
                    index = nextIndex
                    chunksSinceLastScroll += 1

                    let appendedNewline = appendedChunk.contains("\n")
                    if appendedNewline || chunksSinceLastScroll >= scrollBatchSize || nextIndex == suffix.count {
                        requestScroll()
                        chunksSinceLastScroll = 0
                    }

                    let pause = appendedNewline ? delayNanoseconds + newlinePauseNanoseconds : delayNanoseconds
                    try? await Task.sleep(nanoseconds: pause)
                }
            }
        }
    }

    private func startCursorLoop() {
        cursorTask?.cancel()
        cursorVisible = true

        guard showsCursor else { return }

        cursorTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 530_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.14)) {
                    cursorVisible.toggle()
                }
            }
        }
    }

    private func scrollToBottom(using proxy: ScrollViewProxy) {
        guard followOutput else { return }
        DispatchQueue.main.async {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                proxy.scrollTo(bottomAnchorID, anchor: .bottom)
            }
        }
    }

    private func requestScroll() {
        guard followOutput else { return }
        scrollPulse += 1
    }
}
