import AppIntents
import Foundation
import SparrowKit

/// A tag, as the system sees it.
///
/// ⚠️ **The identifier is a `String`, not a `UUID`** — the only entity here
/// whose identity is not one. That is `TagID` showing through: a tag's identity
/// *is* its slug, so two devices that have never met agree on it without
/// coordination. A saved shortcut referring to `"wetlands"` resolves on a fresh
/// install for the same reason.
struct TagEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Tag",
        numericFormat: "\(placeholder: .int) tags"
    )

    static let defaultQuery = TagEntityQuery()

    let id: String
    @Property(title: "Name") var label: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(label)",
            subtitle: "\(id)",
            image: .init(systemName: "tag")
        )
    }

    init(_ tag: Tag) {
        id = tag.id.slug
        label = tag.label
    }

    /// The identifier the service layer speaks. Non-optional: the slug came
    /// from a `TagID`, so it is valid by construction.
    var tagID: TagID? { TagID(slug: id) }
}

/// How Shortcuts and Siri find tags.
///
/// Enumerable, like notebooks and unlike notes: tags are a small browsable set
/// that a person picks from, and the whole list is worth showing.
struct TagEntityQuery: EntityQuery, EnumerableEntityQuery {
    @Dependency var tags: any TagServicing

    func entities(for identifiers: [String]) async throws -> [TagEntity] {
        let ids = identifiers.compactMap(TagID.init(slug:))
        var found: [TagEntity] = []
        for id in ids {
            if let tag = try await tags.tag(id) { found.append(TagEntity(tag)) }
        }
        return found
    }

    func allEntities() async throws -> [TagEntity] {
        try await tags.all().map(TagEntity.init)
    }

    func suggestedEntities() async throws -> [TagEntity] {
        try await allEntities()
    }
}
