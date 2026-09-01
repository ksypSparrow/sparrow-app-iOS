import AppIntents
import ColdStorage
import Foundation
import ServiceContracts
import Services

/// The composition root, and the only place in the app that names `ColdStorage`.
///
/// Everything below is handed out as a protocol. A view or an intent that wants
/// notes receives `any NoteServicing` and cannot discover that storage exists,
/// let alone that it is a dictionary today and SQLite from M1.
enum AppDependencies {
    /// Set once, during `SparrowApp.init()`, before any scene or intent runs.
    private(set) nonisolated(unsafe) static var noteService: (any NoteServicing)?
    private(set) nonisolated(unsafe) static var notebookService: (any NotebookServicing)?
    private(set) nonisolated(unsafe) static var searchService: (any SearchServicing)?

    /// Where the database lives. Application Support, not Documents — this is
    /// app-managed state, not something a person files or opens themselves.
    static var storeURL: URL {
        URL.applicationSupportDirectory
            .appending(path: "Sparrow", directoryHint: .isDirectory)
            .appending(path: "sparrow.sqlite")
    }

    static func register() throws {
        // M0 called `.inMemory()` here. This is the whole diff: one line, and
        // nothing above it changed. That was the point of returning protocols.
        let storage = try ColdStorage.make(at: storeURL)

        // One relay for the whole app. Two would mean a view listening to the
        // wrong one, silently.
        let relay = ChangeRelay()

        let notes = NoteService(
            notes: storage.notes,
            notebooks: storage.notebooks,
            transactions: storage.transactions,
            relay: relay
        )
        let notebooks = NotebookService(
            notebooks: storage.notebooks,
            transactions: storage.transactions,
            relay: relay
        )
        // Holds a reader and an index, and nothing that can write — so
        // searching cannot change anything, structurally.
        let search = SearchService(notes: storage.notes, index: storage.search)

        noteService = notes
        notebookService = notebooks
        searchService = search

        // Every write that goes through *this process's* storage reaches the
        // UI through here, whoever made it — a view, an intent, or a widget
        // hosted in-process.
        //
        // ⚠️ Not cross-process. The broadcaster lives in this instance of
        // ColdStorage, so a separate extension writing the same file would go
        // unnoticed. That needs `DatabaseRegionObservation` or a Darwin
        // notification, and it is not in V1.
        Task { await relay.start(consuming: storage.observer.changes) }

        // Registered as protocols, not as the actors. An intent that could
        // name `NoteService` could reach past the contract it is meant to use.
        AppDependencyManager.shared.add(dependency: notes as any NoteServicing)
        AppDependencyManager.shared
            .add(dependency: notebooks as any NotebookServicing)
        AppDependencyManager.shared.add(dependency: search as any SearchServicing)
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
