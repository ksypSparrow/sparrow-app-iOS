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
        switch self {
        case .service(.emptyNote):
            "A note needs a title or some text."
        case .service(.noteNotFound):
            "That note no longer exists."
        case .service(.storageUnavailable):
            "Sparrow can't reach your notes right now."
        }
    }
}

extension NoteServicing {
    /// Runs a service call, translating anything it throws into the intent
    /// vocabulary. Every `perform()` goes through this.
    func translatingErrors<T>(
        _ body: () async throws -> T
    ) async throws -> T {
        do {
            return try await body()
        } catch let error as ServiceError {
            throw SparrowIntentError.service(error)
        }
    }
}
