import AppIntents

/// Phrases the system compiles at build time, into `nlu.appintents`.
///
/// Siri can match these with the app never having been launched, which is why
/// the dependency registration in `SparrowApp.init()` has to be correct.
struct SparrowShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateNoteIntent(),
            phrases: [
                "New note in \(.applicationName)",
                "Create a note in \(.applicationName)",
            ],
            shortTitle: "New Note",
            systemImageName: "square.and.pencil"
        )
    }
}
