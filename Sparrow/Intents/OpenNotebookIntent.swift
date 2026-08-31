import AppIntents
import Foundation

/// Opens the app on a notebook.
///
/// `OpenIntent` gives this `openAppWhenRun = true` for free, and gives the
/// parameter the name the system expects — which is what lets Siri say
/// "Open Wetlands in Sparrow" without the phrase being spelled out anywhere.
struct OpenNotebookIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Notebook"

    static let description = IntentDescription(
        "Opens Sparrow on a notebook.",
        categoryName: "Notebooks"
    )

    @Parameter(title: "Notebook")
    var target: NotebookEntity

    @Dependency var navigator: Navigator

    @MainActor
    func perform() async throws -> some IntentResult {
        navigator.select(target.notebookID)
        return .result()
    }
}
