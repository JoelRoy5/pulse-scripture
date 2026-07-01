import WidgetKit

/// A single timeline entry carrying an optional verse for display on a Watch face complication.
struct VerseEntry: TimelineEntry {
    /// The date at which this entry should be rendered.
    let date: Date
    /// The verse to display, or `nil` when no verse has been cached yet.
    let verse: SharedVerse?
}
