import AppIntents
import Foundation
import ServiceContracts
import SparrowDomain

/// How Shortcuts and Siri find notes.
///
/// ⚠️ **Not `EnumerableEntityQuery`, unlike notebooks.** Enumerating means
/// handing the system every note, and a field notebook grows without bound —
/// the picker would be unusable and the payload large. Notebooks are a small
/// fixed set; notes are not.
struct NoteEntityQuery: EntityQuery {
    @Dependency var notes: any NoteServicing

    /// Resolves identifiers the system already holds — from a saved shortcut,
    /// or a suggestion made weeks ago.
    ///
    /// NFR-1.3 rests on this: `NoteID` is client-generated and stored, so a
    /// shortcut saved before a reinstall still finds its note.
    func entities(for identifiers: [UUID]) async throws -> [NoteEntity] {
        try await notes.notes(identifiers.map(NoteID.init)).map(NoteEntity.init)
    }

    /// FR-1.6: what the picker shows before anyone has typed anything.
    func suggestedEntities() async throws -> [NoteEntity] {
        try await notes.recent(limit: 6).map(NoteEntity.init)
    }
}
