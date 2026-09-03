import Foundation
import Observation
import ServiceContracts
import SparrowDomain

@MainActor
@Observable
final class NoteListViewModel {
    private(set) var notes: [Note] = []
    private(set) var results: [Note] = []
    var query = ""
    var draftTitle = ""

    private let services: AppServices
    private let navigator: Navigator

    init(services: AppServices, navigator: Navigator) {
        self.services = services
        self.navigator = navigator
    }

    var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// What the list shows: results while searching, recents otherwise.
    var visibleNotes: [Note] { isSearching ? results : notes }

    func note(with id: NoteID?) -> Note? {
        notes.first { $0.id == id }
    }

    func start() async {
        await reload()
        // The event says *what happened*; the view re-reads rather than
        // trusting a payload that may already be stale.
        for await _ in services.notes.changes {
            await reload()
        }
    }

    /// Searches, after a short pause. `.task(id:)` tears this down when the
    /// query changes, so only the last keystroke survives the sleep.
    func runSearch() async {
        guard isSearching else {
            results = []
            return
        }
        do {
            try await Task.sleep(for: .milliseconds(150))
        } catch {
            return   // superseded by the next keystroke
        }
        do {
            results = try await services.search.search(query, limit: 100)
        } catch {
            navigator.present(error)
        }
    }

    func create() async {
        let title = draftTitle
        draftTitle = ""
        await run {
            try await self.services.notes.create(
                NoteDraft(title: RichText(plain: title))
            )
        }
    }

    func delete(_ id: NoteID) async {
        await run { try await self.services.notes.delete(id) }
        if navigator.selectedNoteID == id {
            navigator.go(to: .recents)
        }
    }

    func setPinned(_ id: NoteID, _ pinned: Bool) async {
        await run { try await self.services.notes.setPinned(id, pinned) }
    }

    /// Opens today's entry and selects it.
    ///
    /// ⚠️ Safe to call after an intent already ran, only because
    /// `openOrCreateDailyNote` is idempotent — the second call returns the note
    /// the first one made. A create-then-open pair would produce two entries
    /// for one voice command.
    func openTodaysEntry() async {
        await run {
            let note = try await self.services.notes.openOrCreateDailyNote(on: Date())
            self.navigator.go(to: .note(note.id))
            await self.reload()
        }
    }

    private func reload() async {
        notes = (try? await services.notes.recent(limit: 50)) ?? []
    }

    private func run(_ body: () async throws -> Void) async {
        do { try await body() } catch { navigator.present(error) }
    }
}
