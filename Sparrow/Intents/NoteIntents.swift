import AppIntents
import Foundation
import ServiceContracts
import SparrowDomain

/// Opens the app on a note.
struct OpenNoteIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Note"

    static let description = IntentDescription(
        "Opens Sparrow on a note.",
        categoryName: "Notes"
    )

    @Parameter(title: "Note")
    var target: NoteEntity

    @Dependency var navigator: Navigator

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$target)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        navigator.select(note: target.noteID)
        return .result()
    }
}

/// Edits a note in place.
///
/// Every parameter is optional, and one left blank means *leave it alone* —
/// the same three-way distinction `NoteEdit` makes, surfaced to Shortcuts.
struct UpdateNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Update Note"

    static let description = IntentDescription(
        "Changes a note's title, text, kind or pin.",
        categoryName: "Notes",
        resultValueName: "Updated Note"
    )

    static let openAppWhenRun = false

    @Parameter(title: "Note")
    var note: NoteEntity

    @Parameter(title: "New Title")
    var newTitle: String?

    @Parameter(title: "New Text")
    var newBody: String?

    @Parameter(title: "Kind")
    var kind: NoteKindAppEnum?

    @Parameter(title: "Pinned")
    var isPinned: Bool?

    @Dependency var notes: any NoteServicing

    static var parameterSummary: some ParameterSummary {
        Summary("Update \(\.$note)") {
            \.$newTitle
            \.$newBody
            \.$kind
            \.$isPinned
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<NoteEntity>
        & ProvidesDialog
    {
        let edit = NoteEdit(
            title: newTitle.map { RichText(plain: $0) },
            body: newBody.map { RichText(plain: $0) },
            kind: kind?.domainKind,
            isPinned: isPinned
        )

        let updated = try await translatingServiceErrors {
            try await notes.update(note.noteID, with: edit)
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
            dialog: "Delete \(note.title)? This can't be undone."
        )

        try await translatingServiceErrors {
            try await notes.delete(note.noteID)
        }
        return .result(dialog: "Deleted \(note.title).")
    }
}
