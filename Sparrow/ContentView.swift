import ServiceContracts
import SparrowDomain
import SwiftUI

struct ContentView: View {
    @State private var model = NoteListModel()
    @State private var navigator = Navigator.shared
    @State private var draftTitle = ""
    @State private var notebookName = ""
    @State private var creating = false
    @State private var renaming: Notebook?

    var body: some View {
        NavigationSplitView {
            List(selection: notebookSelection) {
                Section("Notebooks") {
                    ForEach(model.notebooks) { notebook in
                        Label(notebook.name, systemImage: "book.closed")
                            .tag(notebook.id)
                            .contextMenu {
                                Button("Rename…") { renaming = notebook }
                                Button("Delete", role: .destructive) {
                                    Task { await model.delete(notebook.id) }
                                }
                            }
                    }
                }
            }
            .navigationTitle("Sparrow")
            .toolbar {
                Button("New Notebook", systemImage: "plus") {
                    creating = true
                }
            }
            .alert("New Notebook", isPresented: $creating) {
                TextField("Name", text: $notebookName)
                Button("Cancel", role: .cancel) { notebookName = "" }
                Button("Create") {
                    let name = notebookName
                    notebookName = ""
                    Task { await model.createNotebook(named: name) }
                }
            }
            .alert("Rename Notebook", isPresented: renamingBinding) {
                TextField("Name", text: $notebookName)
                Button("Cancel", role: .cancel) {
                    notebookName = ""
                    renaming = nil
                }
                Button("Rename") {
                    let name = notebookName
                    let target = renaming
                    notebookName = ""
                    renaming = nil
                    if let target {
                        Task { await model.rename(target.id, to: name) }
                    }
                }
            }
        } detail: {
            noteList
        }
        .task { await model.start() }
    }

    private var renamingBinding: Binding<Bool> {
        Binding(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } }
        )
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
            "Couldn't do that",
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

    /// Loads once, then follows the change streams for the rest of the
    /// session.
    ///
    /// ⚠️ **Nothing here refreshes on appear.** Every later reload is driven by
    /// an announcement, which is what makes a write from a Shortcut — or from
    /// anything else — show up without the app being touched.
    func start() async {
        await loadNotebooks()
        await reload()

        await withTaskGroup(of: Void.self) { group in
            if let noteService {
                group.addTask { [weak self] in
                    // The event says *what happened*; the view re-reads rather
                    // than trusting a payload that may already be stale.
                    for await _ in noteService.changes {
                        await self?.reload()
                    }
                }
            }
            if let notebookService {
                group.addTask { [weak self] in
                    for await _ in notebookService.changes {
                        await self?.loadNotebooks()
                    }
                }
            }
        }
    }

    // MARK: Notebook commands

    func createNotebook(named name: String) async {
        guard let notebookService else { return }
        await reportingFailure {
            try await notebookService.create(NotebookDraft(name: name))
        }
    }

    func rename(_ id: NotebookID, to name: String) async {
        guard let notebookService else { return }
        await reportingFailure {
            try await notebookService.rename(id, to: name)
        }
    }

    func delete(_ id: NotebookID) async {
        guard let notebookService else { return }
        await reportingFailure {
            try await notebookService.delete(id)
        }
    }

    /// Surfaces whatever a service refused to do. `notebookNotEmpty` reaching a
    /// person as a sentence they can act on is the point of the milestone.
    private func reportingFailure(
        _ body: () async throws -> Void
    ) async {
        do {
            try await body()
        } catch let error as ServiceError {
            failure = error
        } catch {
            failure = .storageUnavailable
        }
    }

    func create(title: String) async {
        guard let noteService else { return }
        await reportingFailure {
            try await noteService.create(NoteDraft(title: title))
        }
    }

    func loadNotebooks() async {
        guard let notebookService else { return }
        notebooks = (try? await notebookService.all()) ?? []

        // A selection can outlive the notebook it points at — deleted here, or
        // on another device once V2 exists.
        if let selected = Navigator.shared.selectedNotebookID,
           !notebooks.contains(where: { $0.id == selected }) {
            Navigator.shared.select(nil)
        }
        if Navigator.shared.selectedNotebookID == nil {
            Navigator.shared.select(
                try? await notebookService.defaultNotebook().id
            )
        }
    }

    func reload() async {
        guard let noteService else { return }
        notes = (try? await noteService.recent(limit: 50)) ?? []
    }
}

#Preview {
    ContentView()
}
