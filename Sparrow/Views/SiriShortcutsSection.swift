import AppIntents
import SwiftUI

/// The Siri tip, a link to this app's shortcuts, and the user's own shortcuts.
///
/// ⚠️ iOS-only. `SiriTipView` is unavailable on macOS, where the Shortcuts app
/// is reached from its own menu. The whole section disappears there rather than
/// leaving an empty header behind.
struct SiriShortcutsSection: View {
    /// `@AppStorage` so dismissal survives a launch — `SiriTipView` writes
    /// `false` through the binding and that is the whole mechanism.
    @AppStorage("showSiriTip") private var showSiriTip = true
    @Environment(\.openURL) private var openURL

    var body: some View {
        #if os(iOS)
        Section("Siri & Shortcuts") {
            if showSiriTip {
                // ⚠️ Collapses to nothing if the row insets and background are
                // cleared. It draws its own card, so clearing them looks right
                // on paper; an ordinary row is the version that renders.
                SiriTipView(
                    intent: OpenTodaysEntryIntent(),
                    isVisible: $showSiriTip
                )
            }
            NavigationLink {
                UserShortcutsView()
            } label: {
                Label("Your Shortcuts", systemImage: "list.bullet.rectangle")
            }
            shortcutsAppRow
        }
        #endif
    }

    #if os(iOS)
    private var shortcutsAppRow: some View {
        Button {
            if let url = ShortcutsApp.url { openURL(url) }
        } label: {
            Label {
                Text("\(ShortcutsApp.appName) shortcuts")
            } icon: {
                ShortcutsApp.icon
            }
        }
        // Without this the row is drawn as a button — tinted label, no row
        // highlight — and stops matching the notebook rows above it.
        .buttonStyle(.plain)
    }
    #endif
}
