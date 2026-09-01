import AppIntents
import Foundation
import ServiceContracts
import SparrowDomain

/// Creates a notebook without opening the app.
struct CreateNotebookIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Notebook"

    static let description = IntentDescription(
        "Adds a notebook to Sparrow.",
        categoryName: "Notebooks",
        resultValueName: "New Notebook"
    )

    static let openAppWhenRun = false

    @Parameter(
        title: "Name",
        requestValueDialog: "What should the notebook be called?"
    )
    var name: String

    @Parameter(title: "Inside")
    var parent: NotebookEntity?

    @Dependency var notebooks: any NotebookServicing

    static var parameterSummary: some ParameterSummary {
        Summary("Create a notebook called \(\.$name)") {
            \.$parent
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<NotebookEntity>
        & ProvidesDialog
    {
        let notebook = try await translatingServiceErrors {
            try await notebooks.create(
                NotebookDraft(name: name, parentID: parent?.notebookID)
            )
        }
        return .result(
            value: NotebookEntity(notebook),
            dialog: "Created \(notebook.name)."
        )
    }
}

/// Renames a notebook.
struct RenameNotebookIntent: AppIntent {
    static let title: LocalizedStringResource = "Rename Notebook"

    static let description = IntentDescription(
        "Changes a notebook's name.",
        categoryName: "Notebooks"
    )

    static let openAppWhenRun = false

    @Parameter(title: "Notebook")
    var notebook: NotebookEntity

    @Parameter(title: "New Name", requestValueDialog: "What should it be called?")
    var name: String

    @Dependency var notebooks: any NotebookServicing

    static var parameterSummary: some ParameterSummary {
        Summary("Rename \(\.$notebook) to \(\.$name)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await translatingServiceErrors {
            try await notebooks.rename(notebook.notebookID, to: name)
        }
        return .result(dialog: "Renamed to \(name).")
    }
}

/// Deletes a notebook, after asking.
struct DeleteNotebookIntent: AppIntent {
    static let title: LocalizedStringResource = "Delete Notebook"

    static let description = IntentDescription(
        "Deletes a notebook. It must be empty.",
        categoryName: "Notebooks"
    )

    static let openAppWhenRun = false

    /// ⚠️ Deletion is not undoable from a Shortcut, and the person running one
    /// may not be looking at the screen. `UndoableIntent` arrives much later in
    /// the plan; a confirmation costs nothing now.
    static let isDiscoverable = true

    @Parameter(title: "Notebook")
    var notebook: NotebookEntity

    @Dependency var notebooks: any NotebookServicing

    static var parameterSummary: some ParameterSummary {
        Summary("Delete \(\.$notebook)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // ⚠️ There is no `.delete` in `ConfirmationActionName` — the set runs
        // add · buy · create · open · send · set · share · start · toggle and
        // similar, with nothing destructive in it. So the dialog carries the
        // weight, and the button says "Continue".
        try await requestConfirmation(
            dialog: "Delete \(notebook.name)? This can't be undone."
        )

        try await translatingServiceErrors {
            try await notebooks.delete(notebook.notebookID)
        }
        return .result(dialog: "Deleted \(notebook.name).")
    }
}
