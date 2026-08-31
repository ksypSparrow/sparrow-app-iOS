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

    static func register() throws {
        // ColdStorage's only public entry point. `make(at:)` replaces this in
        // M1; nothing else about this function changes when it does.
        let storage = try ColdStorage.inMemory()

        let service = NoteService(
            notes: storage.notes,
            transactions: storage.transactions
        )
        noteService = service

        // Registered as the protocol, not the actor. An intent that could name
        // `NoteService` could reach past the contract it is supposed to use.
        AppDependencyManager.shared.add(dependency: service as any NoteServicing)
    }
}
