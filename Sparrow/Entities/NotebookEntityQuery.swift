import AppIntents
import Foundation
import ServiceContracts
import SparrowDomain

/// How Shortcuts and Siri find notebooks.
///
/// `EnumerableEntityQuery` is what makes the parameter a **picker** rather than
/// a text field: the system asks for every notebook and shows the list, so
/// FR-1.5 is satisfied with no typing at all. It is only appropriate because
/// the set is small and local — an enumerable query over ten thousand notes
/// would be a very different decision.
struct NotebookEntityQuery: EntityQuery, EnumerableEntityQuery {
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
        try await notebooks.all().map(NotebookEntity.init)
    }

    /// What the picker shows before anyone has typed or chosen anything.
    func suggestedEntities() async throws -> [NotebookEntity] {
        try await allEntities()
    }
}
