import AppIntents
import Foundation
import SparrowDomain

/// A notebook, as the system sees it.
///
/// A separate type from `Notebook` on purpose. `AppEntity` needs the
/// `AppIntents` framework, and no package below the app may depend on it — the
/// V2 server compiles `SparrowDomain` on Linux, where it does not exist. So the
/// domain stays clean and the mapping lives here.
struct NotebookEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Notebook",
        numericFormat: "\(placeholder: .int) notebooks"
    )

    static let defaultQuery = NotebookEntityQuery()

    let id: UUID
    @Property(title: "Name") var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            image: .init(systemName: "book.closed")
        )
    }

    init(_ notebook: Notebook) {
        id = notebook.id.value
        name = notebook.name
    }

    /// The identifier the service layer speaks.
    var notebookID: NotebookID { NotebookID(id) }
}
