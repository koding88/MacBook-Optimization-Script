import AppKit
import SwiftUI

struct WindowCloseGuard: NSViewRepresentable {
    @ObservedObject var model: OptimizationDashboardViewModel
    let localizer: AppLocalizer

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model, localizer: localizer)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            context.coordinator.attach(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.model = model
        context.coordinator.localizer = localizer
        DispatchQueue.main.async {
            context.coordinator.attach(to: nsView.window)
        }
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        var model: OptimizationDashboardViewModel
        var localizer: AppLocalizer
        private weak var observedWindow: NSWindow?

        init(model: OptimizationDashboardViewModel, localizer: AppLocalizer) {
            self.model = model
            self.localizer = localizer
        }

        func attach(to window: NSWindow?) {
            guard let window, observedWindow !== window else { return }
            observedWindow = window
            window.delegate = self
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            guard model.shouldConfirmQuit else { return true }

            let alert = NSAlert()
            alert.messageText = localizer.text(.quitConfirmTitle)
            alert.informativeText = model.quitConfirmationMessage()
            alert.alertStyle = .warning
            alert.addButton(withTitle: localizer.text(.quitConfirmClose))
            alert.addButton(withTitle: localizer.text(.cancel))
            return alert.runModal() == .alertFirstButtonReturn
        }
    }
}
