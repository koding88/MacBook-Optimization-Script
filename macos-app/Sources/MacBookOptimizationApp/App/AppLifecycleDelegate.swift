import AppKit

final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    var onTerminate: (() -> Void)?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        onTerminate?()
    }
}
