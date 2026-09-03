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
/// ⚠️ **`@AppEntity(schema: .notes.note)`.** The schema dictates the property
/// names and types, and they are not the ones the requirements used:
///
/// ```
///    title  →  name      String → AttributedString
///    body   →  content   String → AttributedString?
///    +         attachments        required, even when always empty
///    +         folder             an entity reference, not an identifier
/// ```
///
/// This is why M9 was left late: adopting the schema reshapes the type, and
/// every intent written against the old names has to move with it.
@AppEntity(schema: .notes.note)
struct NoteEntity: IndexedEntity {
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
    /// `name`, not `title` — the schema's word.
    ///
    /// And `AttributedString`, not `String`. The plain projections this
    /// carried before M9 were the right call for a shortcut payload; the
    /// schema is not offering the choice. `RichText` has held both halves
    /// since domain 0.4.0, so the attributed form is here to give.
    ///
    /// ⚠️ The schema also dictates the **indexing key**: `\.displayName`, not
    /// `\.title`. The extractor rejects any other, which is a stricter
    /// contract than the compiler enforces.
    @ComputedProperty(
        title: "Name",
        indexingKey: \.displayName
    ) var name: AttributedString {
        note.title.attributedString()
    }

    @ComputedProperty(
        title: "Content",
        indexingKey: \.textContent
    ) var content: AttributedString? {
        note.plainBody.isEmpty ? nil : note.body.attributedString()
    }

    /// Mandated by the schema, and always empty.
    ///
    /// ⚠️ Sparrow has no attachments — FR-1.1 never asked for them. The schema
    /// requires the property, so it is here and it is `[]`. Leaving it out
    /// fails the build at *extraction*, not compilation.
    @Property(title: "Attachments") var attachments: [IntentFile]

    @Property(title: "Created") var creationDate: Date?
    @Property(title: "Modified") var modificationDate: Date?

    /// The schema wants an **entity**, not an identifier.
    ///
    /// Supplying it needs the notebook in hand. Callers that already have the
    /// notebooks — a query that just listed them — pass it; callers that would
    /// have to fetch one per note leave it `nil` rather than turning a page of
    /// results into an N+1.
    @Property(title: "Notebook") var folder: NotebookEntity?

    /// A `customIndexingKey` because there is no standard Spotlight attribute
    /// for "what kind of note this is". The string is what someone would type:
    /// "sketch", "voice".
    /// ⚠️ **Optional now.** Extra properties on a schema-conforming entity
    /// must be — the same rule that made `tags` optional in M6, arriving for
    /// `kind` as the schema lands.
    ///
    /// ⚠️ No `indexingKey:` — `\.keywords` is `[String]` and this is an enum,
    /// which the extractor rejects with a misleading "no extractable localized
    /// title". The kind still reaches Spotlight: `attributeSet` puts its raw
    /// value in `keywords` directly.
    @ComputedProperty(title: "Kind") var kind: NoteKindAppEnum? {
        NoteKindAppEnum(note.kind)
    }

    /// Mandated by the schema, and one Sparrow already had.
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
    /// Sparrow's own: when the observation happened, which is not the same as
    /// when the note was created. Optional, being an extra.
    @ComputedProperty(
        title: "Observed",
        indexingKey: \.contentCreationDate
    ) var observedAt: Date? { note.observedAt }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(note.plainTitle.isEmpty ? "Untitled note" : note.plainTitle)",
            subtitle: "\(note.plainBody.prefix(80))",
            image: .init(systemName: NoteKindAppEnum(note.kind).symbolName)
        )
    }

    /// The note this entity describes.
    ///
    /// Private, and every exposed property is a **plain** projection of it.
    /// Attributes would not survive serialisation into a saved shortcut, and a
    /// person reading a suggestion wants the words. NFR-1.4 still holds: what
    /// crosses to the system is text and dates.
    private let note: Note

    init(_ note: Note, in notebook: Notebook? = nil) {
        self.id = note.id.value
        self.note = note
        self.attachments = []
        self.creationDate = note.createdAt
        self.modificationDate = note.updatedAt
        self.folder = notebook.map { NotebookEntity($0) }
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
        attributes.title = note.plainTitle.isEmpty ? "Untitled note" : note.plainTitle
        attributes.contentDescription = note.plainBody
        // What a person would type: "sketch", "voice note".
        attributes.keywords = [note.kind.rawValue] + note.tagIDs.map(\.slug)
        attributes.contentModificationDate = note.updatedAt
        attributes.contentCreationDate = note.observedAt
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
        // ⚠️ This switch used to be a tripwire: add a case to `NoteKind` and the
        // compiler stopped you here. `SparrowDomain` now ships as a resilient
        // binary, so its enums are no longer frozen and the compiler asks for
        // `@unknown default` instead — which is the opposite of a tripwire. A
        // new domain kind will silently arrive as `.observation` rather than
        // failing the build.
        //
        // Marking `NoteKind` `@frozen` in the domain would bring the tripwire
        // back and make a new case an explicit major bump.
        switch kind {
        case .observation: self = .observation
        case .sketch: self = .sketch
        case .voice: self = .voice
        case .daily: self = .daily
        @unknown default: self = .observation
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
