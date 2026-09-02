import AppIntents
import CoreSpotlight
import Foundation
import SparrowDomain

/// A note, as the system sees it.
///
/// ⚠️ **NFR-1.4: names only, never image data.** Every property here is text or
/// a date. An entity is serialised into saved shortcuts, Siri suggestions and
/// the on-device index; putting a sketch's pixels in one would bloat all three
/// and copy the note's content somewhere it cannot be revoked.
struct NoteEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Note",
        numericFormat: "\(placeholder: .int) notes"
    )

    static let defaultQuery = NoteEntityQuery()

    /// A client-generated `UUID`, stable across installs.
    ///
    /// This is what makes NFR-1.3 work: a shortcut saved months ago still
    /// resolves after a delete and reinstall, because the identifier came from
    /// the note rather than from a database row number.
    let id: UUID

    /// ⚠️ **Computed, not stored, and that is what `indexingKey:` requires.**
    /// `@Property` has no `indexingKey` variant — only `@ComputedProperty` and
    /// `@DeferredProperty` do, and both refuse a stored property. So the
    /// entity wraps the note and derives its properties from it.
    ///
    /// `indexingKey:` maps each onto the attribute Spotlight already
    /// understands, so searching for a note's title matches the way searching
    /// for a document's title does — rather than only through keywords.
    @ComputedProperty(indexingKey: \.title) var title: String {
        note.plainTitle
    }

    @ComputedProperty(indexingKey: \.textContent) var body: String {
        note.plainBody
    }

    /// A `customIndexingKey` because there is no standard Spotlight attribute
    /// for "what kind of note this is". The string is what someone would type:
    /// "sketch", "voice".
    @ComputedProperty(
        title: "Kind",
        indexingKey: \.keywords
    ) var kind: NoteKindAppEnum {
        NoteKindAppEnum(note.kind)
    }

    @ComputedProperty(title: "Pinned") var isPinned: Bool { note.isPinned }

    /// ⚠️ **Optional, and it has to be.** Extra properties on an entity that
    /// conforms to an Apple schema must be optional, and `NoteEntity` adopts
    /// `.notes.note` at M9. Making it non-optional now would compile fine and
    /// fail three milestones later, after every intent had been written
    /// against it.
    @ComputedProperty(title: "Tags") var tags: [TagEntity]? {
        note.tagIDs.isEmpty
            ? nil
            : note.tagIDs.map { TagEntity(Tag(id: $0, label: $0.slug)) }
    }
    @ComputedProperty(
        title: "Observed",
        indexingKey: \.contentCreationDate
    ) var observedAt: Date? { note.observedAt }

    @ComputedProperty(
        title: "Last Edited",
        indexingKey: \.contentModificationDate
    ) var updatedAt: Date { note.updatedAt }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title.isEmpty ? "Untitled note" : title)",
            subtitle: "\(body.prefix(80))",
            image: .init(systemName: kind.symbolName)
        )
    }

    /// The note this entity describes.
    ///
    /// Private, and every exposed property is a **plain** projection of it.
    /// Attributes would not survive serialisation into a saved shortcut, and a
    /// person reading a suggestion wants the words. NFR-1.4 still holds: what
    /// crosses to the system is text and dates.
    private let note: Note

    init(_ note: Note) {
        self.id = note.id.value
        self.note = note
    }

    /// The identifier the service layer speaks.
    var noteID: NoteID { NoteID(id) }
}

// MARK: - Spotlight

extension NoteEntity {
    /// Extra attributes Spotlight can match on, beyond the display
    /// representation it derives automatically.
    ///
    /// ⚠️ **Text only.** An attribute set is copied into the on-device index,
    /// which is another place a note's content would live — so this carries
    /// what makes a note *findable* and nothing more, the same rule NFR-1.4
    /// applies to entities.
    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.title = title.isEmpty ? "Untitled note" : title
        attributes.contentDescription = body
        // What a person would type: "sketch", "voice note".
        attributes.keywords = [kind.rawValue] + (tags?.map(\.label) ?? [])
        attributes.contentModificationDate = updatedAt
        attributes.contentCreationDate = observedAt
        return attributes
    }
}

/// `NoteKind`, as the system sees it.
///
/// A separate type from the domain's, for the same reason `NoteEntity` is:
/// `AppEnum` needs the App Intents framework, and no package below the app may
/// depend on it.
enum NoteKindAppEnum: String, AppEnum {
    case observation
    case sketch
    case voice
    case daily

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Note Kind"
    )

    static let caseDisplayRepresentations: [NoteKindAppEnum: DisplayRepresentation] = [
        .observation: "Observation",
        .sketch: "Sketch",
        .voice: "Voice Note",
        .daily: "Daily Entry",
    ]

    var symbolName: String {
        switch self {
        case .observation: "binoculars"
        case .sketch: "pencil.and.outline"
        case .voice: "waveform"
        case .daily: "calendar.day.timeline.left"
        }
    }

    init(_ kind: NoteKind) {
        // The raw values match by construction; the switch is what makes the
        // compiler complain if the domain ever gains a case.
        switch kind {
        case .observation: self = .observation
        case .sketch: self = .sketch
        case .voice: self = .voice
        case .daily: self = .daily
        }
    }

    var domainKind: NoteKind {
        switch self {
        case .observation: .observation
        case .sketch: .sketch
        case .voice: .voice
        case .daily: .daily
        }
    }
}
