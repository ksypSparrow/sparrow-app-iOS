import SparrowKit
import SwiftUI

struct NoteDetailView: View {
    let note: Note
    @State private var viewModel: NoteDetailViewModel

    init(note: Note, services: AppServices, navigator: Navigator) {
        self.note = note
        _viewModel = State(
            initialValue: NoteDetailViewModel(services: services, navigator: navigator)
        )
    }

    var body: some View {
        Form {
            Section("Title") {
                TextField("Title", text: $viewModel.title)
            }
            Section("Note") {
                TextField("Note", text: $viewModel.text, axis: .vertical)
                    .lineLimit(4...)
            }
            Section("Tags") {
                if !note.tagIDs.isEmpty {
                    TagChipsView(tagIDs: note.tagIDs)
                }
                HStack {
                    TextField("Add a tag", text: $viewModel.newTag)
                        .onSubmit { Task { await viewModel.addTag(to: note.id) } }
                    Button("Add") { Task { await viewModel.addTag(to: note.id) } }
                        .disabled(viewModel.newTag.isEmpty)
                }
                ForEach(note.tagIDs, id: \.slug) { id in
                    Button("Remove \(id.slug)", systemImage: "minus.circle") {
                        Task { await viewModel.removeTag(id, from: note.id) }
                    }
                }
            }
            Section {
                LabeledContent("Kind", value: note.kind.rawValue.capitalized)
                Toggle("Pinned", isOn: .init(
                    get: { note.isPinned },
                    set: { pinned in
                        Task { await viewModel.setPinned(note.id, pinned) }
                    }
                ))
            }
        }
        .navigationTitle(note.plainTitle.isEmpty ? "Untitled" : note.plainTitle)
        .toolbar {
            Button("Save") { Task { await viewModel.save(note.id) } }
        }
        .onAppear { viewModel.load(note) }
    }
}
