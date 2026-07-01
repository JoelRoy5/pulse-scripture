import WatchConnectivity

// MARK: - WatchBridgeProtocol (enables mocking in tests)

protocol WatchBridgeProtocol: AnyObject {
    func sendVerse(_ verse: SharedVerse)
}

// MARK: - PhoneSessionManager

/// Manages the iOS side of the WatchConnectivity session.
/// Pushes verses to the paired Watch via `updateApplicationContext` so the Watch
/// always has the latest verse even after it re-connects.
final class PhoneSessionManager: NSObject, WCSessionDelegate, WatchBridgeProtocol {
    static let shared = PhoneSessionManager()

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    /// Push `verse` to the Watch via application context.
    /// Safe to call from any thread; returns silently if the session is not yet active
    /// or WatchConnectivity is unsupported on this device.
    func sendVerse(_ verse: SharedVerse) {
        guard WCSession.default.activationState == .activated else { return }
        try? WCSession.default.updateApplicationContext(verse.toDictionary())
    }

    // MARK: - WCSessionDelegate (required iOS-only callbacks)

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Apple recommends re-activating after deactivation so the session is ready
    /// for the next Watch pairing without restarting the app.
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
