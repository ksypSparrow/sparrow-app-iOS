import AppIntents
import CoreSpotlight
import Foundation
import ServiceContracts
import SparrowDomain

/// Keeps Spotlight in step with the notes.
///
/// An actor rather than a free function: indexing is a stream of small writes
/// against one index, and letting two of them interleave is how a delete
/// arrives before the insert it was meant to undo.
///
/// ⚠️ **Subscribes to `NoteServicing.changes` — a contract that has existed
/// since kit 0.1.0.** That is why M8 needs no package release: Spotlight is a
/// consumer of something already published, not a new capability.
actor SpotlightIndexer {
    private let notes: any NoteServicing
    private let indexName: String
    private var subscription: Task<Void, Never>?

    /// ⚠️ The **name** is stored, not the index.
    ///
    /// `CSSearchableIndex` is not `Sendable`, so holding one in an actor and
    /// using it across an `await` is a data race the compiler refuses. Naming
    /// it and building one per call costs nothing — the object is a handle,
    /// and two handles to the same named index are the same index.


    init(
        notes: any NoteServicing,
        indexName: String = SpotlightIndex.name
    ) {
        self.notes = notes
        self.indexName = indexName
    }

    deinit { subscription?.cancel() }

    /// Indexes what is already there, then follows the change stream.
    func start() {
        subscription?.cancel()
        subscription = Task { [weak self] in
            await self?.reindexEverything()
            await self?.followChanges()
        }
    }

    private func followChanges() async {
        for await change in notes.changes {
            switch change {
            case .created(let id), .updated(let id):
                await index(id)
            case .deleted(let id):
                await remove(id)
            case .reloaded:
                // A bulk import or a restore. The relay only sends this past
                // its threshold, so rebuilding is the cheaper answer than
                // reconciling thousands of identifiers one at a time.
                await reindexEverything()
            // ⚠️ Required since ServiceContracts became a resilient binary.
            // Rebuilding is the correct answer, not a guess: an unrecognised
            // change means the index may be wrong in ways we cannot name, and
            // a stale Spotlight entry is the failure this class exists to
            // prevent.
            @unknown default:
                await reindexEverything()
            }
        }
    }

    // MARK: Writing

    private func index(_ id: NoteID) async {
        guard let note = try? await notes.note(id) else {
            // Created and deleted before this ran. Removing is the safe
            // reading of "it is not there".
            await remove(id)
            return
        }
        await Self.write([NoteEntity(note)], to: indexName)
    }

    private func remove(_ id: NoteID) async {
        await Self.delete([id.value], from: indexName)
    }

    /// Throws the index away and rebuilds it from the notes.
    ///
    /// Safe because the index is **named**: this clears only what Sparrow put
    /// there.
    private func reindexEverything() async {
        guard let all = try? await notes.recent(limit: 10_000) else { return }
        await Self.replaceAll(with: all.map { NoteEntity($0) }, in: indexName)
    }

    // MARK: The index itself

    /// ⚠️ These are `nonisolated` and take a **name**, not an index.
    ///
    /// `CSSearchableIndex` is not `Sendable`, so a handle held by the actor
    /// cannot cross an `await` — the compiler calls it "sending 'index' risks
    /// causing data races", and it is right. Building the handle inside a
    /// nonisolated function keeps it in its own isolation region, where it
    /// belongs: it is a per-call handle to a shared on-disk index, not shared
    /// state of the actor's own.
    private nonisolated static func write(
        _ entities: [NoteEntity],
        to name: String
    ) async {
        let index = CSSearchableIndex(name: name)
        try? await index.indexAppEntities(entities)
    }

    private nonisolated static func delete(
        _ ids: [UUID],
        from name: String
    ) async {
        let index = CSSearchableIndex(name: name)
        // The entity API, not `deleteSearchableItems(withIdentifiers:)` — it
        // knows how the identifier was formed, and the string API expects the
        // one Spotlight generated rather than the one we hold.
        try? await index.deleteAppEntities(
            identifiedBy: ids, ofType: NoteEntity.self
        )
    }

    private nonisolated static func replaceAll(
        with entities: [NoteEntity],
        in name: String
    ) async {
        let index = CSSearchableIndex(name: name)
        try? await index.deleteAllSearchableItems()
        try? await index.indexAppEntities(entities)
    }
}
