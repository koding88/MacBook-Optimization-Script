import SwiftUI

struct ActionButtonStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(prominent ? Color.blue.opacity(configuration.isPressed ? 0.8 : 1.0) : Color.white.opacity(configuration.isPressed ? 0.7 : 0.92))
            )
            .foregroundStyle(prominent ? Color.white : Color.primary)
    }
}
