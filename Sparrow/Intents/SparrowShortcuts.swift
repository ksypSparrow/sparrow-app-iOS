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
        AppShortcut(
            intent: OpenTodaysEntryIntent(),
            phrases: [
                "Open today's entry in \(.applicationName)",
                "Open my \(.applicationName) journal",
            ],
            shortTitle: "Today's Entry",
            systemImageName: "calendar.day.timeline.left"
        )
        AppShortcut(
            intent: SearchNotesIntent(),
            phrases: [
                "Search \(.applicationName) for notes",
                "Find a note in \(.applicationName)",
            ],
            shortTitle: "Search Notes",
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: OpenNoteIntent(),
            phrases: [
                "Open a note in \(.applicationName)",
                "Show me a note in \(.applicationName)",
            ],
            shortTitle: "Open Note",
            systemImageName: "doc.text"
        )
    }
}
