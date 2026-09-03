/*
Abstract:
Three ways to show an app's own App Shortcuts inside the app, side by side, so
the trade-offs can be compared on a real device rather than argued about.
*/

import AppIntents
import SwiftUI

/// Three implementations of "show the available shortcuts", built together.
///
/// The obvious approach does not exist: `AppShortcut` is **write-only**. It has
/// four initializers and no readable properties, so `SparrowShortcuts.appShortcuts`
/// cannot be iterated for display, and nothing in AppIntents returns the phrases
/// the system resolved. Every approach below works around that.
///
/// | | source of the phrase | layout control | runs the intent |
/// |---|---|---|---|
/// | A | the system | none | tapping the tip |
/// | B | retyped in this file | total | yes, `Button(intent:)` |
/// | C | the build metadata | total | no — identifiers are strings |
struct AvailableShortcutsView: View {
    var body: some View {
        List {
            systemSection
            authoredSection
            metadataSection
        }
        .navigationTitle("Available Shortcuts")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - A. Apple's own view

    /// One `SiriTipView` per intent — the only supported way to show a phrase.
    ///
    /// The system resolves the phrase itself, so it is always the real one,
    /// already localized, with `${applicationName}` substituted and no second
    /// copy to drift. The cost is that the look is Apple's and not ours.
    ///
    /// ⚠️ Renders as a grey placeholder wherever the system cannot resolve the
    /// `AppShortcutsProvider` — which is every iOS 27 beta simulator, Apple's
    /// own sample included. On a device it fills in.
    private var systemSection: some View {
        Section {
            #if os(iOS)
            SiriTipView(intent: CreateNoteIntent())
            SiriTipView(intent: OpenTodaysEntryIntent())
            SiriTipView(intent: SearchNotesIntent())
            SiriTipView(intent: OpenNoteIntent())
            #endif
        } header: {
            Text("A · SiriTipView")
        } footer: {
            Text("Apple's own view, one per intent. Always the real phrase, "
                 + "already localized. No control over the look.")
        }
    }

    // MARK: - B. Written out by hand

    /// Rows we draw ourselves, from phrases retyped here.
    ///
    /// ⚠️ This is two definitions of one meaning — the failure mode this
    /// codebase has hit three times. It cannot be avoided by sharing a
    /// constant: `AppShortcutPhrase` does have `init(_ value: String)`, but the
    /// build-time extractor reads *source literals*, so a phrase behind a
    /// constant would vanish from `nlu.appintents` and Siri would stop matching
    /// it. The duplication is the price of this approach, not an oversight.
    private var authoredSection: some View {
        Section {
            #if os(iOS)
            Button(intent: CreateNoteIntent()) {
                AuthoredRow(
                    title: "New Note",
                    symbol: "square.and.pencil",
                    phrase: "New note in \(Self.appName)"
                )
            }
            Button(intent: OpenTodaysEntryIntent()) {
                AuthoredRow(
                    title: "Today's Entry",
                    symbol: "calendar.day.timeline.left",
                    phrase: "Open today's entry in \(Self.appName)"
                )
            }
            Button(intent: SearchNotesIntent()) {
                AuthoredRow(
                    title: "Search Notes",
                    symbol: "magnifyingglass",
                    phrase: "Search \(Self.appName) for notes"
                )
            }
            #endif
        } header: {
            Text("B · Written by hand")
        } footer: {
            Text("Total control, and the rows actually run the intent. "
                 + "The phrases are retyped here, so they can drift.")
        }
    }

    // MARK: - C. Read back out of the build

    /// Rows built from `Metadata.appintents/extract.actionsdata` in our own bundle.
    ///
    /// The App Intents compiler plugin writes this file from the very
    /// `SparrowShortcuts` declaration Siri uses, so the phrases cannot drift —
    /// there is exactly one source and this reads it rather than repeating it.
    ///
    /// ⚠️ The file's format is undocumented. Nothing here is private API — it is
    /// our own bundle, read with `JSONDecoder` — but Apple may change the shape
    /// in any release, so it fails soft to an empty section.
    ///
    /// ⚠️ Display only. The metadata identifies intents by *name*, and a String
    /// cannot be turned back into an `AppIntent`, so these rows cannot run.
    private var metadataSection: some View {
        Section {
            if ExtractedShortcut.all.isEmpty {
                Text("Nothing extracted.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(ExtractedShortcut.all) { shortcut in
                    AuthoredRow(
                        title: shortcut.title,
                        symbol: shortcut.systemImageName,
                        phrase: shortcut.phrases.first ?? ""
                    )
                }
            }
        } header: {
            Text("C · From the build metadata")
        } footer: {
            Text("Read from the file the compiler wrote, so it cannot drift. "
                 + "Undocumented format, and the rows cannot run the intent.")
        }
    }

    fileprivate static var appName: String {
        let info = Bundle.main.infoDictionary
        return info?["CFBundleDisplayName"] as? String
            ?? info?["CFBundleName"] as? String
            ?? "Sparrow"
    }
}

/// One row, shared by B and C so the comparison is about the data source and
/// not about two different row designs.
private struct AuthoredRow: View {
    let title: String
    let symbol: String
    let phrase: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text("“\(phrase)”")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol)
        }
    }
}

// MARK: - Reading the extracted metadata

/// One App Shortcut, as the App Intents compiler plugin recorded it.
struct ExtractedShortcut: Identifiable {
    let id: String
    let title: String
    let systemImageName: String
    let phrases: [String]

    /// Everything the plugin extracted, localized, with the app name filled in.
    ///
    /// Parsed once. The titles and phrases come back as the *keys* the plugin
    /// wrote, which are exactly the keys in `AppShortcuts.xcstrings`, so they
    /// localize through the same table Siri uses.
    static let all: [ExtractedShortcut] = load()

    private static func load() -> [ExtractedShortcut] {
        guard let url = Bundle.main.url(
            forResource: "extract",
            withExtension: "actionsdata",
            subdirectory: "Metadata.appintents"
        ), let data = try? Data(contentsOf: url) else { return [] }

        struct File: Decodable {
            struct Shortcut: Decodable {
                struct Key: Decodable { let key: String }
                let actionIdentifier: String
                let shortTitle: Key?
                let systemImageName: String?
                let phraseTemplates: [Key]?
            }
            let autoShortcuts: [Shortcut]?
        }

        guard let file = try? JSONDecoder().decode(File.self, from: data) else {
            return []
        }

        return (file.autoShortcuts ?? []).map { shortcut in
            ExtractedShortcut(
                id: shortcut.actionIdentifier,
                title: shortcut.shortTitle.map { localized($0.key) }
                    ?? shortcut.actionIdentifier,
                systemImageName: shortcut.systemImageName ?? "app",
                phrases: (shortcut.phraseTemplates ?? []).map { localized($0.key) }
            )
        }
    }

    /// Through `AppShortcuts.xcstrings` — the table Siri itself reads — then
    /// `${applicationName}`, which the metadata leaves as a token.
    private static func localized(_ key: String) -> String {
        let translated = String(
            localized: String.LocalizationValue(key),
            table: "AppShortcuts"
        )
        return translated.replacingOccurrences(
            of: "${applicationName}",
            with: AvailableShortcutsView.appName
        )
    }
}
