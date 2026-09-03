import SparrowDomain

/// Everything the app can put in front of someone.
enum AppAlert: Identifiable, Hashable {
    case error(String)
    case newNotebook
    case renameNotebook(NotebookID, currentName: String)

    var id: String {
        switch self {
        case .error(let message): "error-\(message)"
        case .newNotebook: "new-notebook"
        case .renameNotebook(let id, _): "rename-\(id)"
        }
    }
}
