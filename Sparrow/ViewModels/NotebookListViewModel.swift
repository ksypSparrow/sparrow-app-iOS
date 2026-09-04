import Observation
import SparrowKit

@MainActor
@Observable
final class NotebookListViewModel {
    private(set) var notebooks: [Notebook] = []
    var draftName = ""

    private let services: AppServices
    private let navigator: Navigator

    init(services: AppServices, navigator: Navigator) {
        self.services = services
        self.navigator = navigator
    }

    /// Loads once, then follows the change stream for the rest of the session.
    /// Nothing here refreshes on appear, which is what makes a write from a
    /// Shortcut show up without the app being touched.
    func start() async {
        await load()
        for await _ in services.notebooks.changes {
            await load()
        }
    }

    func create() async {
        let name = draftName
        draftName = ""
        await run { try await self.services.notebooks.create(NotebookDraft(name: name)) }
    }

    func rename(_ id: NotebookID) async {
        let name = draftName
        draftName = ""
        await run { try await self.services.notebooks.rename(id, to: name) }
    }

    func delete(_ id: NotebookID) async {
        await run { try await self.services.notebooks.delete(id) }
    }

    func name(for id: NotebookID?) -> String {
        notebooks.first { $0.id == id }?.name ?? "Notes"
    }

    private func load() async {
        notebooks = (try? await services.notebooks.all()) ?? []

        // A selection can outlive the notebook it points at — deleted here, or
        // on another device once V2 exists.
        if let selected = navigator.selectedNotebookID,
           !notebooks.contains(where: { $0.id == selected }) {
            navigator.go(to: .recents)
        }
        if navigator.selectedNotebookID == nil,
           let fallback = try? await services.notebooks.defaultNotebook().id {
            navigator.go(to: .notebook(fallback))
        }
    }

    private func run(_ body: () async throws -> Void) async {
        do { try await body() } catch { navigator.present(error) }
    }
}
