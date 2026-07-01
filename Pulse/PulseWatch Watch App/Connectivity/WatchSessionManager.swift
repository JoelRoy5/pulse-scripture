import WatchConnectivity
import Combine
import WidgetKit

// MARK: - WatchSessionManager

/// Manages the watchOS side of the WatchConnectivity session.
/// Receives `applicationContext` updates from the paired iPhone and exposes
/// the latest verse as a `@Published` property for SwiftUI views.
final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    @Published var currentVerse: SharedVerse?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 didReceiveApplicationContext context: [String: Any]) {
        if let verse = SharedVerse.from(dictionary: context) {
            DispatchQueue.main.async { self.currentVerse = verse }

            // Cache verse for the WidgetKit complication.
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(verse) {
                UserDefaults(suiteName: "group.com.YOURTEAM.pulse")?.set(data, forKey: SharedVerse.watchContextKey)
            }

            // Ask WidgetKit to refresh the complication immediately.
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {}
}
