import AppIntents
import UniformTypeIdentifiers
import Foundation
import SparrowKit

/// Opens the app on a note.
struct OpenNoteIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Note"

    static let description = IntentDescription(
        "Opens Sparrow on a note.",
        categoryName: "Notes"
    )

    @Parameter(title: "Note")
    var target: NoteEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$target)")
    }

    /// ⚠️ **`perform()` does not navigate on iOS.**
    ///
    /// `.onAppIntentExecution` in `ContentView` maps this intent to a
    /// destination, which is what keeps navigation a property of the *scene*
    /// that ran it. An intent that set `Navigator` directly would move
    /// whichever window happened to be frontmost — including one somebody was
    /// editing in.
    ///
    /// macOS has no such modifier, so there the intent does it itself.
    @MainActor
    func perform() async throws -> some IntentResult {
        #if os(macOS)
        Navigator.shared.go(to: .note(target.noteID))
        #endif
        return .result()
    }
}

/// Edits a note in place.
///
/// ⚠️ **`@AppIntent(schema: .notes.updateNote)` as of M9.** The schema takes
/// the parameters it knows — `name`, `content`, `isPinned`, `folder` — and the
/// ones that were ours are gone from the signature. `kind` and `tags` can no
/// longer be edited from Shortcuts through this action; that is the price of
/// the schema, paid deliberately.
@AppIntent(schema: .notes.updateNote)
struct UpdateNoteIntent {
    static let description = IntentDescription(
        "Changes a note's name, text or pin.",
        categoryName: "Notes",
        resultValueName: "Updated Note"
    )

    static let openAppWhenRun = false

    @Parameter(title: "Note") var target: NoteEntity
    @Parameter(title: "Name") var name: String?
    @Parameter(title: "Content") var content: AttributedString?
    @Parameter(title: "Pinned") var isPinned: Bool?
    @Parameter(title: "Notebook") var folder: NotebookEntity?

    /// Required by the schema even though Sparrow never attaches anything —
    /// and required to be **optional** here, unlike on `createNote`, where the
    /// same parameter must not be. The two schemas differ, and only the
    /// extractor says so.
    @Parameter(title: "Attachments", supportedContentTypes: [.item])
    var attachments: [IntentFile]?

    @Dependency var notes: any NoteServicing

    func perform() async throws -> some IntentResult & ReturnsValue<NoteEntity>
        & ProvidesDialog
    {
        // Each `nil` means *leave it alone* — the same three-way distinction
        // `NoteEdit` has made since domain 0.3.0, and the schema's parameters
        // map onto it without translation.
        let edit = NoteEdit(
            title: name.map { RichText(plain: $0) },
            body: content.map { RichText(plain: String($0.characters)) },
            notebookID: folder?.notebookID,
            isPinned: isPinned
        )

        let updated = try await translatingServiceErrors {
            try await notes.update(target.noteID, with: edit)
        }
        return .result(
            value: NoteEntity(updated),
            dialog: "Updated \(updated.plainTitle)."
        )
    }
}

/// Deletes a note, after asking.
struct DeleteNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Delete Note"

    static let description = IntentDescription(
        "Deletes a note.",
        categoryName: "Notes"
    )

    static let openAppWhenRun = false

    @Parameter(title: "Note")
    var note: NoteEntity

    @Dependency var notes: any NoteServicing

    static var parameterSummary: some ParameterSummary {
        Summary("Delete \(\.$note)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // There is no destructive case in `ConfirmationActionName`, so the
        // button says "Continue" and the sentence has to carry the weight.
        try await requestConfirmation(
            dialog: "Delete \(note.name)? This can't be undone."
        )

        try await translatingServiceErrors {
            try await notes.delete(note.noteID)
        }
        return .result(dialog: "Deleted \(note.name).")
    }
}

#if os(iOS)
/// ⚠️ **`TargetContentProvidingIntent` is unavailable on macOS**, and so is
/// `.onAppIntentExecution`. The conformance has to be gated, not just the call
/// site — which is the platform difference the design anticipated, arriving in
/// a stronger form than expected.
extension OpenNoteIntent: TargetContentProvidingIntent {}
#endif
