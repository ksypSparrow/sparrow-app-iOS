import AppIntents
import Foundation
import SparrowKit

/// A notebook, as the system sees it.
///
/// A separate type from `Notebook` on purpose. `AppEntity` needs the
/// `AppIntents` framework, and no package below the app may depend on it — the
/// V2 server compiles `SparrowDomain` on Linux, where it does not exist. So the
/// domain stays clean and the mapping lives here.
/// ⚠️ **`@AppEntity(schema: .notes.folder)`.** The schema mandates the property
/// names and types — `name: String`, `parentFolder: NotebookEntity?` — so this
/// type is shaped by Apple's vocabulary, not ours. That is the trade: Siri
/// handles phrasings nobody wrote a shortcut for, in exchange for the schema
/// choosing the nouns.
@AppEntity(schema: .notes.folder)
struct NotebookEntity {
    static let defaultQuery = NotebookEntityQuery()

    let id: UUID
    @Property(title: "Name") var name: String

    /// Mandated by the schema. Notebooks nest — `parentID` has been on the
    /// domain type since 0.2.0, put there for exactly this.
    @Property(title: "Inside") var parentFolder: NotebookEntity?

    /// Mandated by the schema. Sparrow stores notes on the device only, so
    /// this is always the same account — see `AccountEntity`.
    @Property(title: "Account") var account: AccountEntity?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            image: .init(systemName: "book.closed")
        )
    }

    init(_ notebook: Notebook, parent: Notebook? = nil) {
        id = notebook.id.value
        name = notebook.name
        // The schema wants an entity, not an identifier. Supplying it needs
        // the parent in hand, so callers that have it pass it and callers that
        // do not leave it nil rather than fetching per notebook.
        parentFolder = parent.map { NotebookEntity($0) }
        account = .local
    }

    /// The identifier the service layer speaks.
    var notebookID: NotebookID { NotebookID(id) }
}
