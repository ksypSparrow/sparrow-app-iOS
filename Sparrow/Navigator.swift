import Foundation
import Observation
import SparrowDomain

/// Where the app is looking.
///
/// Navigation is presentation state, so it lives here rather than in
/// `SparrowKit` — a service has no opinion about which note is on screen.
/// `NavigationServicing` was removed from `ServiceContracts` during contract
/// design for exactly this reason: routing it through a protocol would have
/// satisfied a dependency that does not exist.
@MainActor
@Observable
final class Navigator {
    /// One instance, registered as a dependency in `SparrowApp.init()`. An
    /// intent resolving a *different* Navigator than the views observe would
    /// set navigation state nobody is watching.
    static let shared = Navigator()

    var route: Route = .recents

    private init() {}

    func go(to route: Route) {
        self.route = route
    }

    // MARK: Conveniences the views read

    var selectedNotebookID: NotebookID? {
        if case .notebook(let id) = route { id } else { nil }
    }

    var selectedNoteID: NoteID? {
        if case .note(let id) = route { id } else { nil }
    }
}

/// Every screen an intent can land on.
///
/// An enum rather than a pair of optionals: "a note is open" and "a notebook is
/// selected" are alternatives, and two optionals can be both at once — a state
/// the UI has no way to draw.
enum Route: Hashable, Sendable {
    case recents
    case notebook(NotebookID)
    case note(NoteID)
}
