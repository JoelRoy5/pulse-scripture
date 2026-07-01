import SwiftUI
import WatchKit

struct MorningView: View {
    @EnvironmentObject var session: WatchSessionManager
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 6) {
            if let verse = session.currentVerse {
                Text(verse.text)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                Text(verse.displayLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(6)
        .onAppear {
            guard !appeared else { return }
            appeared = true
            // Morning is the only moment Pulse initiates a haptic
            WKInterfaceDevice.current().play(.notification)
        }
    }
}
