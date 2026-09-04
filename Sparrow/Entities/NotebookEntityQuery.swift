import AppIntents
import Foundation
import SparrowKit

/// How Shortcuts and Siri find notebooks.
///
/// `EnumerableEntityQuery` is what makes the parameter a **picker** rather than
/// a text field: the system asks for every notebook and shows the list, so
/// FR-1.5 is satisfied with no typing at all. It is only appropriate because
/// the set is small and local — an enumerable query over ten thousand notes
/// would be a very different decision.
/// ⚠️ `EntityStringQuery` is required by `.notes.createNote`, not chosen.
///
/// The extractor refuses a schema intent whose entity parameter cannot be
/// resolved from a spoken name: *"requires 'NotebookEntity' to conform to
/// 'IndexedEntity', 'UniqueAppEntity', 'TransientAppEntity', provide a default
/// 'EntityStringQuery', or provide an 'IntentValueQuery'"*. That is the schema
/// insisting Siri can say "in my Wetlands notebook" and be understood.
struct NotebookEntityQuery: EntityQuery, EnumerableEntityQuery, EntityStringQuery {
    @Dependency var notebooks: any NotebookServicing

    /// Resolves identifiers the system already holds — from a saved shortcut,
    /// or a suggestion made weeks ago.
    func entities(for identifiers: [UUID]) async throws -> [NotebookEntity] {
        var found: [NotebookEntity] = []
        for id in identifiers {
            if let notebook = try await notebooks.notebook(NotebookID(id)) {
                found.append(NotebookEntity(notebook))
            }
        }
        return found
    }

    /// Every notebook, in the order storage returns them.
    func allEntities() async throws -> [NotebookEntity] {
        try await notebooks.all().map { NotebookEntity($0) }
    }

    /// Resolves a notebook from a spoken or typed name, case-insensitively —
    /// which is why `NotebookReading.notebook(named:)` has been
    /// case-insensitive since 0.2.0.
    func entities(matching string: String) async throws -> [NotebookEntity] {
        guard let found = try await notebooks.notebook(named: string) else {
            // Fall back to a contains match, so "wetland" finds "Wetlands".
            let all = try await notebooks.all()
            return all
                .filter { $0.name.localizedCaseInsensitiveContains(string) }
                .map { NotebookEntity($0) }
        }
        return [NotebookEntity(found)]
    }

    /// What the picker shows before anyone has typed or chosen anything.
    func suggestedEntities() async throws -> [NotebookEntity] {
        try await allEntities()
    }
}
