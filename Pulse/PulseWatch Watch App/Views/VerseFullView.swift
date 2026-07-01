import SwiftUI
import WatchKit

struct VerseFullView: View {
    @EnvironmentObject var session: WatchSessionManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let verse = session.currentVerse {
                    Text(verse.text)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                    Text(verse.displayLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let reflection = verse.reflection {
                        Divider()
                        Text(reflection)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                } else {
                    Text("Pulse is learning your rhythms.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .onTapGesture {
            WKInterfaceDevice.current().play(.click)
        }
    }
}
