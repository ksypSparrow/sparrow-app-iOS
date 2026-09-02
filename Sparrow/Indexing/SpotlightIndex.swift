import CoreSpotlight
import Foundation

/// The index Sparrow owns.
///
/// ⚠️ **Named, not `CSSearchableIndex.default()`.** The default index is
/// shared with everything else the app might index — and, more importantly,
/// `deleteAllSearchableItems()` on it would clear entries this app did not
/// create. A named index makes "throw it away and rebuild" a safe operation,
/// which is what a reconcile after a restore needs to be.
enum SpotlightIndex {
    static let name = "com.sparrow.fieldnotes.notes"

    static var searchable: CSSearchableIndex {
        CSSearchableIndex(name: name)
    }
}
