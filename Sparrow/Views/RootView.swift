import SparrowDomain
import SwiftUI

struct RootView: View {
    @State private var navigator: Navigator
    @State private var notebooks: NotebookListViewModel
    @State private var notes: NoteListViewModel

    private let services: AppServices

    init(services: AppServices, navigator: Navigator = .shared) {
        self.services = services
        _navigator = State(initialValue: navigator)
        _notebooks = State(
            initialValue: NotebookListViewModel(services: services, navigator: navigator)
        )
        _notes = State(
            initialValue: NoteListViewModel(services: services, navigator: navigator)
        )
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(navigator: navigator, viewModel: notebooks)
        } detail: {
            NavigationStack(path: $navigator.path) {
                NoteListView(
                    navigator: navigator,
                    viewModel: notes,
                    title: notebooks.name(for: navigator.selectedNotebookID)
                )
                .navigationDestination(for: NoteID.self) { id in
                    if let note = notes.note(with: id) {
                        NoteDetailView(
                            note: note,
                            services: services,
                            navigator: navigator
                        )
                    }
                }
            }
        }
        .task { await notes.start() }
        .task { await notebooks.start() }
        .navigatorAlerts(navigator, notebooks: notebooks)
        .intentNavigation(notes: notes, navigator: navigator)
    }
}
