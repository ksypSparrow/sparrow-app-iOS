import AppIntents
import Foundation
import ServiceContracts

/// The App Intents layer's own error type.
///
/// `ServiceError` deliberately conforms to `LocalizedError` and to nothing from
/// App Intents — conforming it to `CustomLocalizedStringResourceConvertible`
/// would make `SparrowKit` unbuildable anywhere App Intents is unavailable, and
/// the V2 server is exactly such a place. So the mapping happens here, in the
/// only layer that is allowed to know both vocabularies.
enum SparrowIntentError: Error, CustomLocalizedStringResourceConvertible {
    case service(ServiceError)

    var localizedStringResource: LocalizedStringResource {
        // ⚠️ This was exhaustive on purpose — a new `ServiceError` case used
        // to stop the build here, so nobody could ship a failure to a person
        // as silence. `ServiceContracts` is now consumed as a resilient
        // binary, which un-freezes the enum and forces the `@unknown default`
        // below, so that guarantee is gone.
        //
        // The fallback is deliberately a real sentence rather than silence,
        // which keeps the *product* behaviour the comment was protecting. What
        // is lost is the compile-time check. Freezing `ServiceError` in
        // ServiceContracts would restore it, at the cost of making every added
        // case a breaking change for the other team consuming the binaries.
        switch self {
        case .service(.emptyNote):
            "A note needs a title or some text."
        case .service(.noteNotFound):
            "That note no longer exists."
        case .service(.notebookNotFound):
            "That notebook no longer exists."
        case .service(.emptyNotebookName):
            "A notebook needs a name."
        case .service(.notebookNotEmpty):
            "That notebook still has things in it. Move or delete them first."
        case .service(.emptyTagLabel):
            "A tag needs a word or a number in it — try \u{201C}wetlands\u{201D}."
        case .service(.tagNotFound):
            "That tag no longer exists."
        case .service(.storageUnavailable):
            "Sparrow can't reach your notes right now."
        @unknown default:
            "Something went wrong."
        }
    }
}

/// Runs a service call, translating anything it throws into the intent
/// vocabulary. Every `perform()` goes through this.
///
/// A free function rather than an extension on one service protocol — every
/// intent needs it, and there are three services by M3.
func translatingServiceErrors<T>(
    isolation: isolated (any Actor)? = #isolation,
    _ body: () async throws -> T
) async throws -> T {
    do {
        return try await body()
    } catch let error as ServiceError {
        throw SparrowIntentError.service(error)
    }
}
