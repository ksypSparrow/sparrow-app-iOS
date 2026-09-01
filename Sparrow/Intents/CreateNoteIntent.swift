import AppIntents
import ServiceContracts
import SparrowDomain

/// Captures a note without opening the app.
///
/// M9 replaces this with `@AppIntent(schema: .notes.createNote)`. Until then it
/// is hand-rolled, which is what makes the comparison in M9 worth anything.
struct CreateNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Note"

    static let description = IntentDescription(
        "Captures a note in Sparrow.",
        categoryName: "Notes",
        resultValueName: "New Note"
    )

    /// Runs in the background: no scene, no window, no view lifecycle.
    static let openAppWhenRun = false

    @Parameter(
        title: "Title",
        requestValueDialog: "What should the note be called?"
    )
    var noteTitle: String

    @Parameter(title: "Note")
    var content: String?

    @Parameter(title: "Kind", default: .observation)
    var kind: NoteKindAppEnum

    @Parameter(title: "Notebook")
    var notebook: NotebookEntity?

    /// When the observation happened, which may precede now by hours — a note
    /// written up in the evening about a bird seen at dawn.
    @Parameter(title: "Observed")
    var observedAt: Date?

    /// Resolved from `AppDependencyManager`, which `SparrowApp.init()` fills in.
    /// If that registration ever moves into a view's `.task`, this line is
    /// where a background launch crashes.
    @Dependency var notes: any NoteServicing

    static var parameterSummary: some ParameterSummary {
        Summary("Create a \(\.$kind) called \(\.$noteTitle)") {
            \.$content
            \.$notebook
            \.$observedAt
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<NoteEntity>
        & ProvidesDialog
    {
        let note = try await translatingServiceErrors {
            try await notes.create(
                NoteDraft(
                    title: RichText(plain: noteTitle),
                    body: RichText(plain: content ?? ""),
                    notebookID: notebook?.notebookID,
                    kind: kind.domainKind,
                    observedAt: observedAt
                )
            )
        }
        // Returning the entity is what lets a shortcut chain this into
        // OpenNote or UpdateNote without looking the note up again.
        return .result(
            value: NoteEntity(note),
            dialog: "Saved \(note.plainTitle)."
        )
    }
}
