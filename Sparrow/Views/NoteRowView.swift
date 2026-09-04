import SparrowKit
import SwiftUI

/// One line of the note list.
///
/// Draws `plainTitle`, not the attributed form — which is why storage keeps the
/// plain copy in its own column.
struct NoteRowView: View {
    let note: Note

    var body: some View {
        HStack(spacing: 8) {
            if note.isPinned {
                Image(systemName: "pin.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(note.plainTitle.isEmpty ? "Untitled note" : note.plainTitle)
                if !note.plainBody.isEmpty {
                    Text(note.plainBody)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if !note.tagIDs.isEmpty {
                    TagChipsView(tagIDs: note.tagIDs)
                }
            }
            Spacer()
            Text(note.happenedAt, format: .dateTime.day().month().hour().minute())
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
