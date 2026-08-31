import ServiceContracts
import SparrowDomain
import SwiftUI

struct ContentView: View {
    @State private var model = NoteListModel()
    @State private var draftTitle = ""

    var body: some View {
        NavigationStack {
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
            .navigationTitle("Sparrow")
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
        .task { await model.start() }
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
    var failure: ServiceError?

    private var service: (any NoteServicing)? { AppDependencies.noteService }

    func start() async {
        await reload()
        guard let service else { return }
        // The service announces what happened; the view re-reads rather than
        // trusting a payload that may already be stale.
        for await _ in service.changes {
            await reload()
        }
    }

    func create(title: String) async {
        guard let service else { return }
        do {
            try await service.create(NoteDraft(title: title))
        } catch let error as ServiceError {
            failure = error
        } catch {
            failure = .storageUnavailable
        }
    }

    private func reload() async {
        guard let service else { return }
        notes = (try? await service.recent(limit: 50)) ?? []
    }
}

#Preview {
    ContentView()
}
