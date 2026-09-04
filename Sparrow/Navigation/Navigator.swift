import Foundation
import Observation
import SparrowKit

/// Where the app is looking, and what it is asking.
///
/// Navigation and alerts are presentation state, so they live here rather than
/// in `SparrowKit` — a service has no opinion about which note is on screen.
///
/// The sidebar selection and the detail stack are separate on purpose. A note
/// is opened *within* a notebook, so collapsing both into one value pops the
/// sidebar selection to nil the moment a note opens, and the split view slides
/// back to the sidebar instead of showing the note.
@MainActor
@Observable
final class Navigator {
    /// One instance, registered as a dependency in `SparrowApp.init()`. An
    /// intent resolving a *different* Navigator than the views observe would
    /// set navigation state nobody is watching.
    static let shared = Navigator()

    /// The sidebar selection.
    var selectedNotebookID: NotebookID?
    /// The detail stack, bound to a `NavigationStack`.
    var path: [NoteID] = []
    var alert: AppAlert?

    init() {}

    // MARK: Navigation

    func go(to route: Route) {
        switch route {
        case .recents:
            path = []
        case .notebook(let id):
            selectedNotebookID = id
            path = []
        case .note(let id):
            path = [id]
        }
    }

    var selectedNoteID: NoteID? { path.last }

    // MARK: Alerts

    func present(_ alert: AppAlert) {
        self.alert = alert
    }

    func present(_ error: any Error) {
        present(.error(
            (error as? LocalizedError)?.errorDescription
                ?? "Something went wrong."
        ))
    }

    func dismissAlert() {
        alert = nil
    }
}
