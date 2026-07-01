import WidgetKit
import SwiftUI

// MARK: - Complication views

/// Rectangular complication: two lines of verse text + reference below.
private struct RectangularView: View {
    let entry: VerseEntry

    var body: some View {
        if let verse = entry.verse {
            VStack(alignment: .leading, spacing: 2) {
                Text(verse.text)
                    .font(.system(size: 11, weight: .regular))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(verse.displayLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 4)
            .widgetAccentable()
        } else {
            Text("Pulse")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

/// Circular complication: a heart icon with the book abbreviation below.
private struct CircularView: View {
    let entry: VerseEntry

    /// Extracts the first word of the reference (e.g. "Psalm" → "Psa", "John" → "Jhn").
    private var shortRef: String {
        guard let verse = entry.verse else { return "✦" }
        // Take up to first 3 chars of each component to keep it tight on the circular face.
        let parts = verse.reference.split(separator: " ")
        if parts.count >= 2 {
            // e.g. "Ps" + " " + "23:4"
            let book = String(parts[0].prefix(3))
            let chapter = String(parts[1])
            return "\(book)\n\(chapter)"
        }
        return String(verse.reference.prefix(6))
    }

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if entry.verse != nil {
                VStack(spacing: 0) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(shortRef)
                        .font(.system(size: 8, weight: .medium))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .widgetAccentable()
            } else {
                Image(systemName: "heart")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Root widget view

struct VerseWidgetView: View {
    let entry: VerseEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            RectangularView(entry: entry)
        case .accessoryCircular:
            CircularView(entry: entry)
        default:
            // Fallback for any other family (should not occur given supportedFamilies).
            Text(entry.verse?.reference ?? "Pulse")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Widget declaration

struct VerseWidget: Widget {
    let kind: String = "PulseVerseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VerseTimelineProvider()) { entry in
            VerseWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Pulse")
        .description("Scripture delivered at the right moment.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
    }
}

// MARK: - Previews

#if DEBUG
#Preview(as: .accessoryRectangular) {
    VerseWidget()
} timeline: {
    VerseEntry(
        date: .now,
        verse: SharedVerse(
            reference: "Psalm 23:4",
            displayLabel: "Psalm 23:4 (NIV)",
            text: "Even though I walk through the darkest valley, I will fear no evil.",
            reflection: nil,
            deliveredAt: .now
        )
    )
    VerseEntry(date: .now, verse: nil)
}

#Preview(as: .accessoryCircular) {
    VerseWidget()
} timeline: {
    VerseEntry(
        date: .now,
        verse: SharedVerse(
            reference: "Psalm 23:4",
            displayLabel: "Psalm 23:4 (NIV)",
            text: "Even though I walk through the darkest valley, I will fear no evil.",
            reflection: nil,
            deliveredAt: .now
        )
    )
    VerseEntry(date: .now, verse: nil)
}
#endif
