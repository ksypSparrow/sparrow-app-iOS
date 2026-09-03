import SwiftUI

struct UserShortcutsView: View {
    @State private var viewModel = UserShortcutsViewModel()

    var body: some View {
        List {
            Section {
                content
            } header: {
                Text("Your Shortcuts")
            } footer: {
                Text("From INVoiceShortcutCenter — the only public API for "
                     + "this. It returns shortcuts built on this app's intents "
                     + "and added to Siri. The rest of the Shortcuts library is "
                     + "outside our sandbox and cannot be read.")
            }
        }
        .navigationTitle("Your Shortcuts")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            HStack { ProgressView(); Text("Loading…") }
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        case .loaded(let shortcuts) where shortcuts.isEmpty:
            Text("iOS returned no shortcuts for this app.")
                .foregroundStyle(.secondary)
        case .loaded(let shortcuts):
            ForEach(shortcuts) { shortcut in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\u{201C}\(shortcut.phrase)\u{201D}")
                    Text(shortcut.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
