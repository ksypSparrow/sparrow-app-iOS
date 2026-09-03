import AppIntents
import SwiftUI

extension View {
    /// Maps every open-style intent to a destination.
    ///
    /// ⚠️ iOS only. `.onAppIntentExecution` does not exist on macOS, and
    /// neither does `TargetContentProvidingIntent` — so there the intents set
    /// `Navigator` themselves. Gathering the modifiers here keeps that one
    /// `#if` in one place instead of three.
    ///
    /// The modifier fires on the scene that ran the intent, which stops two
    /// open windows fighting over which one moves.
    @ViewBuilder
    func intentNavigation(
        notes: NoteListViewModel,
        navigator: Navigator
    ) -> some View {
        #if os(iOS)
        self
            .onAppIntentExecution(OpenTodaysEntryIntent.self) { _ in
                Task { await notes.openTodaysEntry() }
            }
            .onAppIntentExecution(OpenNoteIntent.self) { intent in
                navigator.go(to: .note(intent.target.noteID))
            }
            .onAppIntentExecution(OpenNotebookIntent.self) { intent in
                navigator.go(to: .notebook(intent.target.notebookID))
            }
        #else
        self
        #endif
    }
}
