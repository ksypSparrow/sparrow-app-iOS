import AppIntents
import Foundation
import SparrowDomain

/// A note, as the system sees it.
///
/// ⚠️ **NFR-1.4: names only, never image data.** Every property here is text or
/// a date. An entity is serialised into saved shortcuts, Siri suggestions and
/// the on-device index; putting a sketch's pixels in one would bloat all three
/// and copy the note's content somewhere it cannot be revoked.
struct NoteEntity: AppEntity {
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

    @Property(title: "Title") var title: String
    @Property(title: "Note") var body: String
    @Property(title: "Kind") var kind: NoteKindAppEnum
    @Property(title: "Pinned") var isPinned: Bool
    @Property(title: "Observed") var observedAt: Date?
    @Property(title: "Last Edited") var updatedAt: Date

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title.isEmpty ? "Untitled note" : title)",
            subtitle: "\(body.prefix(80))",
            image: .init(systemName: kind.symbolName)
        )
    }

    init(_ note: Note) {
        id = note.id.value
        // The plain projection, deliberately. Attributes would not survive
        // serialisation into a saved shortcut, and a person reading a
        // suggestion wants the words.
        title = note.plainTitle
        body = note.plainBody
        kind = NoteKindAppEnum(note.kind)
        isPinned = note.isPinned
        observedAt = note.observedAt
        updatedAt = note.updatedAt
    }

    /// The identifier the service layer speaks.
    var noteID: NoteID { NoteID(id) }
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
