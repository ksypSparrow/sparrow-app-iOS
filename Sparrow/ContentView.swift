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
            if let selected = model.notes.first(
                where: { $0.id == navigator.selectedNoteID }
            ) {
                NoteDetailView(note: selected, model: model)
            } else {
                noteList
            }
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

            Section(model.isSearching ? "Results" : "Recent") {
                if model.visibleNotes.isEmpty {
                    Text(
                        model.isSearching
                            ? "Nothing matches \u{201C}\(model.query)\u{201D}."
                            : "No notes yet."
                    )
                    .foregroundStyle(.secondary)
                }
                ForEach(model.visibleNotes) { note in
                    NoteRow(note: note)
                        .contentShape(.rect)
                        .onTapGesture { navigator.select(note: note.id) }
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                Task { await model.delete(note: note.id) }
                            }
                            Button(note.isPinned ? "Unpin" : "Pin") {
                                Task {
                                    await model.setPinned(
                                        note.id, !note.isPinned
                                    )
                                }
                            }
                            .tint(.orange)
                        }
                }
            }
        }
        .navigationTitle(selectedNotebookName)
        .searchable(text: $model.query, prompt: "Search notes")
        .task(id: model.query) {
            // Runs on every keystroke, and is cancelled by the next one —
            // `.task(id:)` tears the previous down before starting this. The
            // debounce is what keeps a fast typist from issuing a query per
            // character.
            await model.runSearch()
        }
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
    private(set) var results: [Note] = []
    var query = ""
    var failure: ServiceError?

    var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// What the list shows: results while searching, recents otherwise.
    var visibleNotes: [Note] { isSearching ? results : notes }

    private var noteService: (any NoteServicing)? { AppDependencies.noteService }
    private var searchService: (any SearchServicing)? {
        AppDependencies.searchService
    }
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

    /// Searches, after a short pause.
    ///
    /// Cancellation does the work here: `.task(id:)` tears this down when the
    /// query changes, so the sleep is only survived by the last keystroke.
    /// `FTSQuery` gives every term a `*`, so a note is findable before the
    /// word is finished.
    func runSearch() async {
        guard let searchService, isSearching else {
            results = []
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(150))
        } catch {
            return   // superseded by the next keystroke
        }

        do {
            results = try await searchService.search(query, limit: 100)
        } catch let error as ServiceError {
            failure = error
        } catch {
            failure = .storageUnavailable
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

    func delete(note id: NoteID) async {
        guard let noteService else { return }
        await reportingFailure { try await noteService.delete(id) }
        if Navigator.shared.selectedNoteID == id {
            Navigator.shared.select(note: nil)
        }
    }

    func setPinned(_ id: NoteID, _ pinned: Bool) async {
        guard let noteService else { return }
        await reportingFailure { try await noteService.setPinned(id, pinned) }
    }

    /// Saves both fields as one edit. `NoteEdit` names only what changed, so a
    /// save that touched nothing writes nothing — the same rule the Shortcuts
    /// action follows.
    func save(_ id: NoteID, title: String, body: String) async {
        guard let noteService else { return }
        await reportingFailure {
            try await noteService.update(
                id,
                with: NoteEdit(
                    title: RichText(plain: title),
                    body: RichText(plain: body)
                )
            )
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
            try await noteService.create(
                NoteDraft(title: RichText(plain: title))
            )
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

/// One line of the note list.
///
/// Draws `plainTitle`, not the attributed form. A list row does not need to
/// decode attributes to show a title, which is exactly why storage keeps the
/// plain copy in its own column.
struct NoteRow: View {
    let note: Note

    var body: some View {
        HStack(spacing: 8) {
            if note.isPinned {
                Image(systemName: "pin.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(note.plainTitle.isEmpty ? "Untitled note" : note.plainTitle)
                if !note.plainBody.isEmpty {
                    Text(note.plainBody)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(note.happenedAt, format: .dateTime.day().month().hour().minute())
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

/// The detail view for one note.
///
/// Edits go through `NoteServicing.update`, so the same `NoteEdit` semantics
/// the Shortcuts action uses apply here: a field left alone stays alone.
struct NoteDetailView: View {
    let note: Note
    let model: NoteListModel

    @State private var title = ""
    @State private var body_ = ""

    var body: some View {
        Form {
            Section("Title") {
                TextField("Title", text: $title)
            }
            Section("Note") {
                TextField("Note", text: $body_, axis: .vertical)
                    .lineLimit(4...)
            }
            Section {
                LabeledContent("Kind", value: note.kind.rawValue.capitalized)
                Toggle("Pinned", isOn: .init(
                    get: { note.isPinned },
                    set: { pinned in
                        Task { await model.setPinned(note.id, pinned) }
                    }
                ))
            }
        }
        .navigationTitle(note.plainTitle.isEmpty ? "Untitled" : note.plainTitle)
        .toolbar {
            Button("Save") {
                Task { await model.save(note.id, title: title, body: body_) }
            }
        }
        .onAppear {
            // Seeds the fields once. The list itself never refreshes on
            // appear — see `NoteListModel.start()`.
            title = note.plainTitle
            body_ = note.plainBody
        }
    }
}

#Preview {
    ContentView()
}
