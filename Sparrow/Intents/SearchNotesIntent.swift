import AppIntents
import Foundation
import ServiceContracts
import SparrowDomain

/// Searches notes without opening the app.
///
/// Returns the matches as entities, so a shortcut can feed them straight into
/// another action rather than reading them out and stopping.
struct SearchNotesIntent: AppIntent {
    static let title: LocalizedStringResource = "Search Notes"

    static let description = IntentDescription(
        "Finds notes matching some text.",
        categoryName: "Notes",
        resultValueName: "Matching Notes"
    )

    static let openAppWhenRun = false

    @Parameter(
        title: "Text",
        requestValueDialog: "What should I look for?"
    )
    var query: String

    @Parameter(title: "Limit", default: 20, inclusiveRange: (1, 100))
    var limit: Int

    @Dependency var search: any SearchServicing

    static var parameterSummary: some ParameterSummary {
        Summary("Search notes for \(\.$query)") {
            \.$limit
        }
    }

    func perform() async throws -> some IntentResult
        & ReturnsValue<[NoteEntity]> & ProvidesDialog
    {
        let found = try await translatingServiceErrors {
            try await search.search(query, limit: limit)
        }

        let dialog: IntentDialog = switch found.count {
        case 0: "No notes match \(query)."
        case 1: "Found one note."
        default: "Found \(found.count) notes."
        }

        return .result(value: found.map(NoteEntity.init), dialog: dialog)
    }
}
