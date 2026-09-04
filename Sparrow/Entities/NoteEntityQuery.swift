import AppIntents
import CoreSpotlight
import Foundation
import SparrowKit

/// How Shortcuts and Siri find notes.
///
/// ⚠️ **Not `EnumerableEntityQuery`, unlike notebooks.** Enumerating means
/// handing the system every note, and a field notebook grows without bound —
/// the picker would be unusable and the payload large. Notebooks are a small
/// fixed set; notes are not.
struct NoteEntityQuery: EntityQuery, EntityStringQuery, IndexedEntityQuery {
    @Dependency var notes: any NoteServicing
    @Dependency var search: any SearchServicing

    /// Resolves identifiers the system already holds — from a saved shortcut,
    /// a suggestion made weeks ago, or **a tapped Spotlight result**.
    ///
    /// Spotlight hands back the same identifier the index stored, so the
    /// method that already resolved saved shortcuts resolves search hits too.
    /// That is what makes tapping a result open the note rather than the app
    /// root — FR-1.2.
    ///
    /// NFR-1.3 rests on it as well: `NoteID` is client-generated and stored,
    /// so a shortcut saved before a reinstall still finds its note.
    func entities(for identifiers: [UUID]) async throws -> [NoteEntity] {
        try await notes.notes(identifiers.map(NoteID.init)).map { NoteEntity($0) }
    }

    /// FR-1.6: what the picker shows before anyone has typed anything.
    func suggestedEntities() async throws -> [NoteEntity] {
        try await search.suggestions(limit: 6).map { NoteEntity($0) }
    }

    /// What lets Siri resolve a note by name — "open my heron note" — instead
    /// of showing a picker.
    ///
    /// It runs the same full-text search the app's own field does, so
    /// FR-1.3's diacritic folding applies to a spoken query too: someone who
    /// says "heron" finds a note titled "Herón".
    func entities(matching string: String) async throws -> [NoteEntity] {
        try await search.search(string, limit: 20).map { NoteEntity($0) }
    }

    // MARK: Reindexing, when the system asks

    /// ⚠️ **The other direction.** `SpotlightIndexer` pushes changes as they
    /// happen; these two are the system *pulling* — after a restore, or when
    /// it decides the index needs rebuilding. Both write to the same named
    /// index, and both go through `indexAppEntities`, so there is one
    /// definition of what a note looks like in Spotlight.
    func reindexEntities(
        for identifiers: [UUID],
        indexDescription: CSSearchableIndexDescription
    ) async throws {
        let entities = try await notes
            .notes(identifiers.map(NoteID.init))
            .map { NoteEntity($0) }
        try await CSSearchableIndex(name: SpotlightIndex.name)
            .indexAppEntities(entities)
    }

    func reindexAllEntities(
        indexDescription: CSSearchableIndexDescription
    ) async throws {
        let entities = try await notes.recent(limit: 10_000).map { NoteEntity($0) }
        let index = CSSearchableIndex(name: SpotlightIndex.name)
        try await index.deleteAllSearchableItems()
        try await index.indexAppEntities(entities)
    }
}
