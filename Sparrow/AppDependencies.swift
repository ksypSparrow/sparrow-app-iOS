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

        let notes = NoteService(
            notes: storage.notes,
            transactions: storage.transactions
        )
        let notebooks = NotebookService(notebooks: storage.notebooks)
        noteService = notes
        notebookService = notebooks

        // Registered as protocols, not as the actors. An intent that could
        // name `NoteService` could reach past the contract it is meant to use.
        AppDependencyManager.shared.add(dependency: notes as any NoteServicing)
        AppDependencyManager.shared
            .add(dependency: notebooks as any NotebookServicing)
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
