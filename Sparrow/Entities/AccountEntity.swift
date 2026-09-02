import AppIntents
import Foundation

/// The account a notebook belongs to.
///
/// ⚠️ **Sparrow has no accounts, and the schema requires one anyway.**
/// `.notes.folder` mandates an `account` property; the metadata processor
/// rejects the build without it, even though the compiler accepts the type.
///
/// So this exists to satisfy the vocabulary: one account, the device itself,
/// referenced by every notebook. That is the cost of adopting someone else's
/// schema — it brings concepts your app does not have, and you either model
/// them thinly or you do not get the schema.
@AppEntity(schema: .notes.account)
struct AccountEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Account"
    )

    static let defaultQuery = AccountEntityQuery()

    /// Fixed, like `DefaultNotebook.identifier` and for the same reason: a
    /// stable identity that two devices could agree on without coordinating.
    static let local = AccountEntity()

    let id = UUID(uuidString: "5A88E10B-0000-4000-A000-0000000000AC")!

    @Property(title: "Name") var name: String

    init() {
        name = "On This Device"
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct AccountEntityQuery: EntityQuery, EnumerableEntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [AccountEntity] {
        identifiers.contains(AccountEntity.local.id) ? [.local] : []
    }

    func allEntities() async throws -> [AccountEntity] { [.local] }
}
