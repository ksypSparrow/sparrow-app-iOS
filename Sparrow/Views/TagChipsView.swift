import SparrowDomain
import SwiftUI

/// The tags on a note, drawn as chips.
///
/// Shows the slug rather than the label: the note carries `TagID`s, and
/// resolving each to its `Tag` would be a fetch per chip per row.
struct TagChipsView: View {
    let tagIDs: [TagID]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tagIDs, id: \.slug) { id in
                Text(id.slug)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.tint.opacity(0.15), in: .capsule)
            }
        }
    }
}
