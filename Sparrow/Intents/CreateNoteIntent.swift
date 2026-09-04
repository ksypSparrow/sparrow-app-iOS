import AppIntents
import UniformTypeIdentifiers
import SparrowKit

/// Captures a note without opening the app.
///
/// ⚠️ **`@AppIntent(schema: .notes.createNote)` as of M9.** The hand-rolled
/// version shipped in M0 so this milestone would have something to compare
/// against, and the comparison is instructive: the schema dictates the
/// parameter names and types, and Siri then handles phrasings nobody wrote a
/// shortcut for.
///
/// What it costs is the parameters that were ours. `kind` and `observedAt` are
/// gone from the signature — the schema does not have them, and a schema
/// intent cannot add required parameters.
@AppIntent(schema: .notes.createNote)
struct CreateNoteIntent {
    static let description = IntentDescription(
        "Captures a note in Sparrow.",
        categoryName: "Notes",
        resultValueName: "New Note"
    )

    /// Runs in the background: no scene, no window, no view lifecycle.
    static let openAppWhenRun = false

    /// ⚠️ **`String` here, `AttributedString` on the entity.** The intent
    /// schema and the entity schema disagree about the type of the same
    /// concept, and both are enforced — by the extractor, not the compiler.
    @Parameter(title: "Name") var name: String

    @Parameter(title: "Content") var content: AttributedString?

    /// Declaring what it accepts is mandatory: the extractor refuses an
    /// attachment parameter that does not. `supportedTypeIdentifiers` was
    /// deprecated in iOS 18 in favour of `supportedContentTypes`.
    @Parameter(title: "Attachments", supportedContentTypes: [.item])
    var attachments: [IntentFile]

    @Parameter(title: "Pinned") var isPinned: Bool
    @Parameter(title: "Notebook") var folder: NotebookEntity?

    /// Resolved from `AppDependencyManager`, which `SparrowApp.init()` fills in.
    /// If that registration ever moves into a view's `.task`, this line is
    /// where a background launch crashes.
    @Dependency var notes: any NoteServicing

    func perform() async throws -> some IntentResult & ReturnsValue<NoteEntity>
        & ProvidesDialog
    {
        let note = try await translatingServiceErrors {
            try await notes.create(
                NoteDraft(
                    title: RichText(plain: name),
                    body: RichText(plain: content.map { String($0.characters) } ?? ""),
                    notebookID: folder?.notebookID
                )
            )
        }
        // 🔍 **The open question, answered: yes.** A schema intent *can* add
        // `& ProvidesDialog` to its return type — the macro accepts it, and
        // FR-1.1 gets its spoken confirmation without falling back to letting
        // the system compose one.
        return .result(
            value: NoteEntity(note),
            dialog: "Saved \(note.plainTitle)."
        )
    }
}
