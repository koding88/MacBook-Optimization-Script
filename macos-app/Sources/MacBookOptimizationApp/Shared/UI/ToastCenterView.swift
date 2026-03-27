import SwiftUI

struct ToastCenterView: View {
    let toasts: [ToastMessage]
    let onDismiss: (ToastMessage.ID) -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            ForEach(toasts) { toast in
                ToastRowView(toast: toast) {
                    dismiss(toast)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: toast.id) {
                    guard let dismissAfter = toast.dismissAfter else { return }
                    try? await Task.sleep(nanoseconds: UInt64(dismissAfter * 1_000_000_000))
                    await MainActor.run {
                        dismiss(toast)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, 16)
        .padding(.trailing, 16)
        .allowsHitTesting(!toasts.isEmpty)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: toasts)
    }

    private func dismiss(_ toast: ToastMessage) {
        onDismiss(toast.id)
    }
}
