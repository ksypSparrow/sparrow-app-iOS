import SparrowKit

/// The services a view model needs, in one value.
///
/// Named `AppServices` and not `Services` because `Services` is the module the
/// concrete implementations come from.
struct AppServices: Sendable {
    let notes: any NoteServicing
    let notebooks: any NotebookServicing
    let search: any SearchServicing
    let tags: any TagServicing
}
