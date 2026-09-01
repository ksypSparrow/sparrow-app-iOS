import Foundation
import Observation
import SparrowDomain

/// Where the app is looking.
///
/// Navigation is presentation state, so it lives here rather than in
/// `SparrowKit` — a service has no opinion about which notebook is on screen.
/// An intent sets it; the views read it.
@MainActor
@Observable
final class Navigator {
    /// One instance, registered as a dependency in `SparrowApp.init()`. An
    /// intent resolving a *different* Navigator than the views observe would
    /// set navigation state nobody is watching.
    static let shared = Navigator()

    var selectedNotebookID: NotebookID?
    var selectedNoteID: NoteID?

    private init() {}

    func select(_ id: NotebookID?) {
        selectedNotebookID = id
    }

    func select(note id: NoteID?) {
        selectedNoteID = id
    }
}
