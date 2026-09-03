import AppIntents
import SwiftUI

@main
struct SparrowApp: App {
    init() {
        do {
            try AppDependencies.register()
        } catch {
            // Storage could not be opened, so nothing the app does can work.
            // Fail loudly here rather than shipping an app whose every intent
            // silently does nothing.
            fatalError("Sparrow could not open storage: \(error)")
        }

        // App Shortcuts only register once this has run at least once.
        SparrowShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            if let services = AppDependencies.services {
                RootView(services: services)
            } else {
                ContentUnavailableView(
                    "Storage unavailable",
                    systemImage: "exclamationmark.triangle"
                )
            }
        }
        // ⚠️ Scene targeting, so an intent's navigation reaches a window that
        // is already open rather than spawning another.
        //
        // Without it, "open my heron note" on a Mac with Sparrow already
        // running opens a second window showing the note, and leaves the first
        // one where it was — two windows, one of them stale.
        .handlesExternalEvents(matching: [SparrowApp.noteActivity])
    }

    /// The activity name a scene answers to. One value, used by the scene and
    /// by anything that wants to route to it.
    static let noteActivity = "com.sparrow.fieldnotes.note"
}
