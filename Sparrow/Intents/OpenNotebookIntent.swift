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

    /// ⚠️ **Does not navigate on iOS.** `.onAppIntentExecution` in
    /// `ContentView` maps this to a destination, which keeps navigation a
    /// property of the scene that ran the intent rather than of whichever
    /// window is frontmost. macOS has no such modifier, so there the intent
    /// does it itself.
    @MainActor
    func perform() async throws -> some IntentResult {
        #if os(macOS)
        Navigator.shared.go(to: .notebook(target.notebookID))
        #endif
        return .result()
    }
}

#if os(iOS)
extension OpenNotebookIntent: TargetContentProvidingIntent {}
#endif
