import SwiftUI

struct SidebarView: View {
    @Bindable var navigator: Navigator
    let viewModel: NotebookListViewModel

    var body: some View {
        List(selection: $navigator.selectedNotebookID) {
            Section("Notebooks") {
                ForEach(viewModel.notebooks) { notebook in
                    Label(notebook.name, systemImage: "book.closed")
                        .tag(notebook.id)
                        .contextMenu {
                            Button("Rename…") {
                                navigator.present(
                                    .renameNotebook(notebook.id, currentName: notebook.name)
                                )
                            }
                            Button("Delete", role: .destructive) {
                                Task { await viewModel.delete(notebook.id) }
                            }
                        }
                }
            }
            SiriShortcutsSection()
        }
        .navigationTitle("Sparrow")
        .toolbar {
            Button("New Notebook", systemImage: "plus") {
                navigator.present(.newNotebook)
            }
        }
    }
}
