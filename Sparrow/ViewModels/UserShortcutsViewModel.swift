import Intents
import Observation

/// One row's worth of an `INVoiceShortcut`.
struct UserShortcut: Identifiable, Sendable {
    let id: UUID
    let phrase: String
    /// What the shortcut is built on, reported rather than guessed at.
    let detail: String
}

/// The user's own shortcuts, as far as iOS will show them.
///
/// `INVoiceShortcutCenter` is the only public API for this, and it returns
/// shortcuts built on *this app's* intents. The Shortcuts library lives in the
/// Shortcuts app's container, outside our sandbox.
@MainActor
@Observable
final class UserShortcutsViewModel {
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

    /// ⚠️ `INVoiceShortcut` is not `Sendable`, so the mapping happens *inside*
    /// the callback and only our own value type crosses the continuation.
    nonisolated private static func fetch() async throws -> [UserShortcut] {
        try await withCheckedThrowingContinuation { continuation in
            INVoiceShortcutCenter.shared.getAllVoiceShortcuts { shortcuts, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (shortcuts ?? []).map { voice in
                    UserShortcut(
                        id: voice.identifier,
                        phrase: voice.invocationPhrase,
                        detail: describe(voice.shortcut)
                    )
                })
            }
        }
    }

    /// 🧪 7001 is what you get with no Siri entitlement — `siriactionsd` logs
    /// "insufficient privileges" and refuses the XPC connection. The entitlement
    /// cannot simply be added: signing ad-hoc with `com.apple.developer.siri`
    /// and no provisioning profile makes iOS refuse to launch the app at all.
    nonisolated private static func explain(_ error: NSError) -> String {
        guard error.domain == "IntentsErrorDomain", error.code == 7001 else {
            return error.localizedDescription
        }
        return "Needs the Siri capability. This build is unsigned, so iOS "
            + "refuses the request (error 7001)."
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
