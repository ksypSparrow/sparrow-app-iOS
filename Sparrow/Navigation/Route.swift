import SparrowKit

/// Every screen an intent or the UI can land on.
///
/// An enum rather than a pair of optionals: "a note is open" and "a notebook is
/// selected" are alternatives, and two optionals can be both at once.
enum Route: Hashable, Sendable {
    case recents
    case notebook(NotebookID)
    case note(NoteID)
}
