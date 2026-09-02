import AppIntents
import Foundation
import ServiceContracts
import SparrowDomain

/// Opens today's journal entry, creating it if there is not one yet.
///
/// ⚠️ **Custom, not schema-based, and that is FR-1.7's whole constraint.**
/// Apple's journaling schemas surface in Shortcuts only — they never reach
/// Siri. FR-1.7 asks for a working *voice* phrase, so the intent has to be
/// one of ours ([architecture.md](../01-Sparrow-FieldNotes/architecture.md)
/// §2.4).
///
/// `TargetContentProvidingIntent` is what lets the app show the note it
/// opened: the intent does the work, and `ContentView` maps the execution to a
/// destination.
struct OpenTodaysEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Today's Entry"

    static let description = IntentDescription(
        "Opens today's journal entry, starting one if today has none.",
        categoryName: "Notes",
        resultValueName: "Today's Entry"
    )

    static let openAppWhenRun = true

    @Dependency var notes: any NoteServicing

    func perform() async throws -> some IntentResult & ReturnsValue<NoteEntity>
        & ProvidesDialog
    {
        let note = try await translatingServiceErrors {
            // One call, not a fetch and then a create. "Open today's entry"
            // has to work whether or not today has one.
            try await notes.openOrCreateDailyNote(on: Date())
        }
        return .result(
            value: NoteEntity(note),
            dialog: "Here's today's entry."
        )
    }
}

#if os(iOS)
extension OpenTodaysEntryIntent: TargetContentProvidingIntent {}
#endif
