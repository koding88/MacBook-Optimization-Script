import SwiftUI

struct TerminalSurfaceView: View {
    let title: String?
    let output: String
    let emptyMessage: String
    let animateKey: String
    let minHeight: CGFloat
    let maxHeight: CGFloat?

    @State private var displayedOutput = ""
    @State private var cursorVisible = true
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                Text(displayedBody)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(red: 0.93, green: 0.96, blue: 1.0))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(16)
            }
            .frame(minHeight: minHeight, maxHeight: maxHeight)
            .background(Color(red: 0.03, green: 0.04, blue: 0.06))
        }
        .background(Color(red: 0.06, green: 0.07, blue: 0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 8)
        .onAppear {
            syncOutput(animated: false)
            startCursorBlink()
        }
        .onDisappear {
            animationTask?.cancel()
        }
        .onChange(of: output) { _ in
            syncOutput(animated: true)
        }
        .onChange(of: animateKey) { _ in
            syncOutput(animated: false)
        }
    }

    private var displayedBody: String {
        let value = displayedOutput.isEmpty ? emptyMessage : displayedOutput
        return cursorVisible ? value + "\n▍" : value + "\n "
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

    private func syncOutput(animated: Bool) {
        animationTask?.cancel()

        let normalized = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard animated,
              !displayedOutput.isEmpty,
              normalized.hasPrefix(displayedOutput),
              normalized.count > displayedOutput.count else {
            displayedOutput = normalized
            return
        }

        let suffix = String(normalized.dropFirst(displayedOutput.count))
        animationTask = Task { @MainActor in
            for character in suffix {
                guard !Task.isCancelled else { return }
                displayedOutput.append(character)
                try? await Task.sleep(nanoseconds: 9_000_000)
            }
        }
    }

    private func startCursorBlink() {
        cursorVisible = true
        withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
            cursorVisible.toggle()
        }
    }
}
