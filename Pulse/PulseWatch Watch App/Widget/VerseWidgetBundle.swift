import WidgetKit
import SwiftUI

/// Declares the widgets provided by the Pulse Watch app.
///
/// - Important: This struct intentionally does **not** carry `@main`.
///   The `@main` entry point lives in `PulseWatchApp.swift`. When Joel adds a
///   separate Widget Extension target in Xcode, move `@main` back here (or to
///   the new target's bundle file) and remove this note.
struct PulseWidgetBundle: WidgetBundle {
    var body: some Widget {
        VerseWidget()
    }
}
