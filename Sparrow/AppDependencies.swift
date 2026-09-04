import AppIntents
import Foundation
import SparrowKit

/// Where the app collects its dependencies and hands them to the system.
///
/// The wiring itself lives in `SparrowAssembly`. This app names no store, no
/// service implementation and no database — it asks kit for a set of protocols
/// and registers them. Nothing here can discover that SQLite exists.
enum AppDependencies {
    /// Set once, during `SparrowApp.init()`, before any scene or intent runs.
    private(set) nonisolated(unsafe) static var noteService: (any NoteServicing)?
    private(set) nonisolated(unsafe) static var notebookService: (any NotebookServicing)?
    private(set) nonisolated(unsafe) static var searchService: (any SearchServicing)?
    private(set) nonisolated(unsafe) static var tagService: (any TagServicing)?
    /// Held so the subscription outlives `register()`.
    private(set) nonisolated(unsafe) static var spotlightIndexer: SpotlightIndexer?

    /// The services a view model needs, once `register()` has run.
    @MainActor
    static var services: AppServices? {
        guard let noteService, let notebookService, let searchService, let tagService
        else { return nil }
        return AppServices(
            notes: noteService,
            notebooks: notebookService,
            search: searchService,
            tags: tagService
        )
    }

    /// Where the database lives. Application Support, not Documents — this is
    /// app-managed state, not something a person files or opens themselves.
    static var storeURL: URL {
        URL.applicationSupportDirectory
            .appending(path: "Sparrow", directoryHint: .isDirectory)
            .appending(path: "sparrow.sqlite")
    }

    static func register() throws {
        // The one line that used to be `ColdStorage.make(at:)` behind an
        // `import ColdStorage`. Swapping this for `.inMemory()` is still a
        // one-line change — it just no longer costs the app a dependency on
        // storage to make it.
        let services = try SparrowAssembly.onDisk(at: storeURL)

        let notes = services.notes
        noteService = notes
        notebookService = services.notebooks
        searchService = services.search
        tagService = services.tags

        // Spotlight follows the same change stream the UI does. It is a
        // consumer of `NoteServicing.changes`, published since kit 0.1.0 —
        // which is why Spotlight needed no package release.
        let indexer = SpotlightIndexer(notes: notes)
        spotlightIndexer = indexer
        Task { await indexer.start() }

        // Registered as protocols, which is now the only thing they can be —
        // the app never sees a concrete service type to register by mistake.
        AppDependencyManager.shared.add(dependency: services.notes)
        AppDependencyManager.shared.add(dependency: services.notebooks)
        AppDependencyManager.shared.add(dependency: services.search)
        AppDependencyManager.shared.add(dependency: services.tags)
        // ⚠️ Not `add(dependency: Navigator.shared)`. That overload takes a
        // `@Sendable` autoclosure, and `Navigator` is `@MainActor`, so the
        // reference cannot be made from inside one. The async provider
        // overload can hop to the main actor, and is the only form that
        // compiles for a `@MainActor` dependency under Swift 6.
        AppDependencyManager.shared.add {
            await MainActor.run { Navigator.shared }
        }
    }
}
