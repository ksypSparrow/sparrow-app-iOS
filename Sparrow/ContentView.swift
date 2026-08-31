import ServiceContracts
import SparrowDomain
import SwiftUI

struct ContentView: View {
    @State private var model = NoteListModel()
    @State private var navigator = Navigator.shared
    @State private var draftTitle = ""

    var body: some View {
        NavigationSplitView {
            List(selection: notebookSelection) {
                Section("Notebooks") {
                    ForEach(model.notebooks) { notebook in
                        Label(notebook.name, systemImage: "book.closed")
                            .tag(notebook.id)
                    }
                }
            }
            .navigationTitle("Sparrow")
        } detail: {
            noteList
        }
        .task { await model.start() }
    }

    private var notebookSelection: Binding<NotebookID?> {
        Binding(
            get: { navigator.selectedNotebookID },
            set: { navigator.select($0) }
        )
    }

    private var noteList: some View {
        List {
            Section {
                HStack {
                    TextField("New note", text: $draftTitle)
                        .onSubmit(save)
                    Button("Save", action: save)
                        .disabled(draftTitle.isEmpty)
                }
            }

            Section("Recent") {
                if model.notes.isEmpty {
                    Text("No notes yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.notes) { note in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.title)
                        Text(note.createdAt, format: .dateTime.hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(selectedNotebookName)
        .alert(
            "Couldn't save",
            isPresented: .constant(model.failure != nil),
            presenting: model.failure
        ) { _ in
            Button("OK") { model.failure = nil }
        } message: { failure in
            Text(failure.errorDescription ?? "Something went wrong.")
        }
    }

    private var selectedNotebookName: String {
        model.notebooks
            .first { $0.id == navigator.selectedNotebookID }?
            .name ?? "Notes"
    }

    private func save() {
        let title = draftTitle
        draftTitle = ""
        Task { await model.create(title: title) }
    }
}

@MainActor
@Observable
final class NoteListModel {
    private(set) var notes: [Note] = []
    private(set) var notebooks: [Notebook] = []
    var failure: ServiceError?

    private var noteService: (any NoteServicing)? { AppDependencies.noteService }
    private var notebookService: (any NotebookServicing)? {
        AppDependencies.notebookService
    }

    func start() async {
        await loadNotebooks()
        await reload()
        guard let noteService else { return }
        // The service announces what happened; the view re-reads rather than
        // trusting a payload that may already be stale.
        for await _ in noteService.changes {
            await reload()
        }
    }

    func create(title: String) async {
        guard let noteService else { return }
        do {
            try await noteService.create(NoteDraft(title: title))
        } catch let error as ServiceError {
            failure = error
        } catch {
            failure = .storageUnavailable
        }
    }

    private func loadNotebooks() async {
        guard let notebookService else { return }
        notebooks = (try? await notebookService.all()) ?? []
        if Navigator.shared.selectedNotebookID == nil {
            Navigator.shared.select(
                try? await notebookService.defaultNotebook().id
            )
        }
    }

    private func reload() async {
        guard let noteService else { return }
        notes = (try? await noteService.recent(limit: 50)) ?? []
    }
}

#Preview {
    ContentView()
}
