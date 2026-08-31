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
            ContentView()
        }
    }
}
