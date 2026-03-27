import SwiftUI

struct ToastRowView: View {
    let toast: ToastMessage
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 6) {
                Text(toast.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(toast.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !toast.summaryLines.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(toast.summaryLines.prefix(3).enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 8)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: 340, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
    }

    private var iconName: String {
        switch toast.type {
        case .info:
            return "info.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }

    private var iconColor: Color {
        switch toast.type {
        case .info:
            return .blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    private var borderColor: Color {
        iconColor.opacity(0.22)
    }
}
