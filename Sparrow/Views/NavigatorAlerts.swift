import SwiftUI

/// Renders whatever `Navigator` is asking. One place, so no view owns alert
/// state of its own.
private struct NavigatorAlerts: ViewModifier {
    @Bindable var navigator: Navigator
    @Bindable var notebooks: NotebookListViewModel

    func body(content: Content) -> some View {
        content
            .alert("New Notebook", isPresented: presenting { $0 == .newNotebook }) {
                TextField("Name", text: $notebooks.draftName)
                Button("Cancel", role: .cancel) { notebooks.draftName = "" }
                Button("Create") { Task { await notebooks.create() } }
            }
            .alert("Rename Notebook", isPresented: presenting(isRename)) {
                TextField("Name", text: $notebooks.draftName)
                Button("Cancel", role: .cancel) { notebooks.draftName = "" }
                Button("Rename") {
                    if case .renameNotebook(let id, _) = navigator.alert {
                        Task { await notebooks.rename(id) }
                    }
                }
            }
            .alert("Couldn't do that", isPresented: presenting(isError)) {
                Button("OK") { navigator.dismissAlert() }
            } message: {
                if case .error(let message) = navigator.alert { Text(message) }
            }
    }

    private func isRename(_ alert: AppAlert) -> Bool {
        if case .renameNotebook = alert { true } else { false }
    }

    private func isError(_ alert: AppAlert) -> Bool {
        if case .error = alert { true } else { false }
    }

    /// True while the current alert matches, and clears it on dismissal.
    private func presenting(
        _ matches: @escaping (AppAlert) -> Bool
    ) -> Binding<Bool> {
        Binding(
            get: { navigator.alert.map(matches) ?? false },
            set: { if !$0 { navigator.dismissAlert() } }
        )
    }
}

extension View {
    func navigatorAlerts(
        _ navigator: Navigator,
        notebooks: NotebookListViewModel
    ) -> some View {
        modifier(NavigatorAlerts(navigator: navigator, notebooks: notebooks))
    }
}
