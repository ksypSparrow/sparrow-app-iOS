import SwiftUI

struct NoteListView: View {
    let navigator: Navigator
    @Bindable var viewModel: NoteListViewModel
    let title: String

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("New note", text: $viewModel.draftTitle)
                        .onSubmit { Task { await viewModel.create() } }
                    Button("Save") { Task { await viewModel.create() } }
                        .disabled(viewModel.draftTitle.isEmpty)
                }
            }

            Section(viewModel.isSearching ? "Results" : "Recent") {
                if viewModel.visibleNotes.isEmpty {
                    Text(emptyMessage).foregroundStyle(.secondary)
                }
                ForEach(viewModel.visibleNotes) { note in
                    NoteRowView(note: note)
                        .contentShape(.rect)
                        .onTapGesture { navigator.go(to: .note(note.id)) }
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                Task { await viewModel.delete(note.id) }
                            }
                            Button(note.isPinned ? "Unpin" : "Pin") {
                                Task { await viewModel.setPinned(note.id, !note.isPinned) }
                            }
                            .tint(.orange)
                        }
                }
            }
        }
        .navigationTitle(title)
        .searchable(text: $viewModel.query, prompt: "Search notes")
        .task(id: viewModel.query) { await viewModel.runSearch() }
    }

    private var emptyMessage: String {
        viewModel.isSearching
            ? "Nothing matches \u{201C}\(viewModel.query)\u{201D}."
            : "No notes yet."
    }
}
