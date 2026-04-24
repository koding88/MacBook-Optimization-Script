import CoreGraphics
import Foundation

@MainActor
protocol GPUDisplayConfigurationObserving: AnyObject {
    func startObserving(_ handler: @escaping @MainActor () -> Void)
    func stopObserving()
}

final class GPUDisplayConfigurationObserver: GPUDisplayConfigurationObserving {
    private var handler: (@MainActor () -> Void)?
    private var isObserving = false

    func startObserving(_ handler: @escaping @MainActor () -> Void) {
        self.handler = handler

        guard !isObserving else { return }

        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CGDisplayRegisterReconfigurationCallback(Self.reconfigurationCallback, context)
        isObserving = true
    }

    func stopObserving() {
        guard isObserving else { return }

        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CGDisplayRemoveReconfigurationCallback(Self.reconfigurationCallback, context)
        isObserving = false
        handler = nil
    }

    private static let reconfigurationCallback: CGDisplayReconfigurationCallBack = { _, _, userInfo in
        guard let userInfo else { return }
        let observer = Unmanaged<GPUDisplayConfigurationObserver>.fromOpaque(userInfo).takeUnretainedValue()
        Task { @MainActor in
            observer.handler?()
        }
    }
}
