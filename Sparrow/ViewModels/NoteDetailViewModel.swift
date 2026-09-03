import Observation
import ServiceContracts
import SparrowDomain

@MainActor
@Observable
final class NoteDetailViewModel {
    var title = ""
    var text = ""
    var newTag = ""

    private let services: AppServices
    private let navigator: Navigator

    init(services: AppServices, navigator: Navigator) {
        self.services = services
        self.navigator = navigator
    }

    /// Seeds the fields once. The list itself never refreshes on appear.
    func load(_ note: Note) {
        title = note.plainTitle
        text = note.plainBody
    }

    /// Saves both fields as one edit. `NoteEdit` names only what changed, so a
    /// save that touched nothing writes nothing — the rule the Shortcuts action
    /// follows too.
    func save(_ id: NoteID) async {
        await run {
            try await self.services.notes.update(
                id,
                with: NoteEdit(
                    title: RichText(plain: self.title),
                    body: RichText(plain: self.text)
                )
            )
        }
    }

    func setPinned(_ id: NoteID, _ pinned: Bool) async {
        await run { try await self.services.notes.setPinned(id, pinned) }
    }

    /// Ensures the tag exists, then appends it. Two steps, and they cannot be
    /// one: `ensure` is find-or-create in storage, and appending is an edit to
    /// *this* note.
    func addTag(to id: NoteID) async {
        let label = newTag
        newTag = ""
        await run {
            let tag = try await self.services.tags.ensure(label)
            guard let current = try await self.services.notes.note(id),
                  !current.tagIDs.contains(tag.id)
            else { return }
            try await self.services.notes.update(
                id, with: NoteEdit(tagIDs: current.tagIDs + [tag.id])
            )
        }
    }

    func removeTag(_ tagID: TagID, from id: NoteID) async {
        await run {
            guard let current = try await self.services.notes.note(id) else { return }
            try await self.services.notes.update(
                id, with: NoteEdit(tagIDs: current.tagIDs.filter { $0 != tagID })
            )
        }
    }

    private func run(_ body: () async throws -> Void) async {
        do { try await body() } catch { navigator.present(error) }
    }
}
