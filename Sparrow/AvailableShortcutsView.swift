/*
Abstract:
Listing the shortcuts the *user* built in the Shortcuts app, from inside Sparrow.
*/

import Intents
import SwiftUI

/// The user's own shortcuts, as far as iOS will show them to us.
///
/// There is exactly one public API for this — `INVoiceShortcutCenter`, from the
/// SiriKit era — and Apple's header states its limits plainly:
///
/// > Get all of the shortcuts **associated with this app** that have been added
/// > to Siri. These could have either been added with
/// > `INUIAddVoiceShortcutViewController`, or separately by the user in the
/// > Shortcuts app.
///
/// So an app can see shortcuts built around *its own* intents, and nothing else.
/// There is no API that lists the Shortcuts library, and there cannot be: those
/// shortcuts live in the Shortcuts app's container, which is outside our sandbox.
///
/// ⚠️ It is a SiriKit API, and `INShortcut` wraps an `INIntent` or an
/// `NSUserActivity` — neither of which is an App Intent. Whether a shortcut
/// built on a modern `AppIntent` comes back here at all is the open question
/// this screen exists to answer, so it reports exactly what it got.
struct AvailableShortcutsView: View {
    @State private var model = UserShortcutsModel()

    var body: some View {
        List {
            Section {
                switch model.state {
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
                            Text("“\(shortcut.phrase)”")
                            Text(shortcut.detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Your Shortcuts")
            } footer: {
                Text("From INVoiceShortcutCenter — the only public API for this. "
                     + "It returns shortcuts built on this app's intents and "
                     + "added to Siri. The rest of the Shortcuts library is "
                     + "outside our sandbox and cannot be read.")
            }
        }
        .navigationTitle("Your Shortcuts")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await model.load() }
        .refreshable { await model.load() }
    }
}

/// One row's worth of an `INVoiceShortcut`.
struct UserShortcut: Identifiable, Sendable {
    let id: UUID
    let phrase: String
    /// What the shortcut is actually built on, reported rather than guessed at.
    let detail: String
}

@MainActor
@Observable
final class UserShortcutsModel {
    enum State {
        case loading
        case loaded([UserShortcut])
        case failed(String)
    }

    private(set) var state: State = .loading

    func load() async {
        state = .loading
        do {
            state = .loaded(try await Self.fetch())
        } catch let error as NSError {
            state = .failed(Self.explain(error))
        }
    }

    /// `getAllVoiceShortcuts` is a completion-handler API and can call back with
    /// neither a value nor an error, so the continuation resumes with an empty
    /// list rather than leaking a suspended task.
    ///
    /// ⚠️ `INVoiceShortcut` is not `Sendable`, so the mapping happens *inside*
    /// the callback and only our own value type crosses the continuation.
    nonisolated private static func fetch() async throws -> [UserShortcut] {
        try await withCheckedThrowingContinuation { continuation in
            INVoiceShortcutCenter.shared.getAllVoiceShortcuts { shortcuts, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let rows = (shortcuts ?? []).map { voice in
                    UserShortcut(
                        id: voice.identifier,
                        phrase: voice.invocationPhrase,
                        detail: describe(voice.shortcut)
                    )
                }
                continuation.resume(returning: rows)
            }
        }
    }

    /// 🧪 `INIntentErrorVoiceShortcutGetFailed` (7001) is what you get with no
    /// Siri entitlement. `siriactionsd` logs the real reason and it is blunt:
    ///
    /// > Rejecting connection … because it has insufficient privileges:
    /// > `<VCAccessSpecifier: entitlements=>`
    ///
    /// The entitlement cannot simply be added here. Signing ad-hoc with
    /// `com.apple.developer.siri` and no provisioning profile makes iOS refuse
    /// to launch the app at all — verified against a control that re-signed
    /// identically with an empty dictionary and launched fine.
    nonisolated private static func explain(_ error: NSError) -> String {
        guard error.domain == "IntentsErrorDomain", error.code == 7001 else {
            return error.localizedDescription
        }
        return "Needs the Siri capability. This build is unsigned, so "
            + "iOS refuses the request (error 7001)."
    }

    nonisolated private static func describe(_ shortcut: INShortcut) -> String {
        if let intent = shortcut.intent {
            return "INIntent · \(type(of: intent))"
        }
        if let activity = shortcut.userActivity {
            return "NSUserActivity · \(activity.activityType)"
        }
        return "neither an intent nor an activity"
    }
}
