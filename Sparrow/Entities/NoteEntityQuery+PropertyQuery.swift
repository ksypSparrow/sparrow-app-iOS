// ⚠️ `@preconcurrency` is required, not stylistic. `EntityQueryProperties` and
// `EntityQuerySortingOptions` are not `Sendable`, so declaring them as `static
// let` fails Swift 6's global-state check. Apple's own Trails sample opens the
// same way, for the same reason.
@preconcurrency import AppIntents
import Foundation
import ServiceContracts
import SparrowDomain

/// The Shortcuts **Find Notes** action — FR-1.4.
///
/// ⚠️ **The comparator type is `NoteFilter`, not `Predicate<NoteEntity>`.**
/// Apple's own sample maps comparators to in-memory predicates and evaluates
/// them over every entity. That works for a few dozen trails; a field notebook
/// grows without bound, and it would mean loading every note to answer "kind
/// is observation".
///
/// `NoteFilter` is data that storage compiles into SQL, which is the whole
/// reason it exists. The Find action a person builds in Shortcuts becomes a
/// bound query with a `LIMIT`, and nothing above storage ever sees a row it
/// did not ask for.
extension NoteEntityQuery: EntityPropertyQuery {
    typealias ComparatorMappingType = NoteFilter

    static let properties = QueryProperties {
        Property(\NoteEntity.$title) {
            ContainsComparator { NoteFilter(text: $0) }
        }
        Property(\NoteEntity.$body) {
            ContainsComparator { NoteFilter(text: $0) }
        }
        Property(\NoteEntity.$kind) {
            EqualToComparator { NoteFilter(kinds: [$0.domainKind]) }
        }
        Property(\NoteEntity.$isPinned) {
            EqualToComparator { NoteFilter(isPinned: $0) }
        }
        Property(\NoteEntity.$updatedAt) {
            GreaterThanOrEqualToComparator { since in
                NoteFilter(updatedWithin: .from(since))
            }
            LessThanOrEqualToComparator { until in
                NoteFilter(updatedWithin: .until(until))
            }
        }
    }

    static let sortingOptions = SortingOptions {
        SortableBy(\NoteEntity.$title)
        SortableBy(\NoteEntity.$updatedAt)
        SortableBy(\NoteEntity.$observedAt)
    }

    static var findIntentDescription: IntentDescription? {
        IntentDescription(
            "Finds notes by their text, kind, pin or when they were edited.",
            categoryName: "Notes",
            searchKeywords: ["note", "find", "search", "filter"],
            resultValueName: "Notes"
        )
    }

    func entities(
        matching comparators: [NoteFilter],
        mode: ComparatorMode,
        sortedBy: [EntityQuerySort<NoteEntity>],
        limit: Int?
    ) async throws -> [NoteEntity] {
        let sort = Self.noteSort(from: sortedBy)
        let cap = limit ?? 100

        // One comparator is the common case, and it is one query.
        guard comparators.count > 1 else {
            let filter = comparators.first ?? .all
            return try await translatingServiceErrors {
                try await search.filter(filter, sort: sort, limit: cap)
            }
            .map(NoteEntity.init)
        }

        // ⚠️ Several comparators are run separately and combined, rather than
        // merged into one filter.
        //
        // `NoteFilter`'s own fields are already ANDed, so merging looks
        // tempting — but two comparators can target the *same* field
        // ("updated after X" and "updated before Y", or two `contains` on the
        // title), and one filter cannot hold both. Combining identifier sets
        // is correct for either mode; merging would silently drop a criterion
        // a person had typed.
        var combined: [Note]?
        for filter in comparators {
            let matched = try await translatingServiceErrors {
                try await search.filter(filter, sort: sort, limit: 1_000)
            }
            combined = switch (combined, mode) {
            case (nil, _): matched
            case (let running?, .and):
                running.filter { note in matched.contains { $0.id == note.id } }
            case (let running?, .or):
                running + matched.filter { note in
                    !running.contains { $0.id == note.id }
                }
            }
        }

        // Re-sorted with the domain's own ordering, because the union of two
        // sorted lists is not itself sorted.
        return (combined ?? [])
            .sorted(by: sort.orders)
            .prefix(cap)
            .map(NoteEntity.init)
    }

    /// Maps the sort a person chose in Shortcuts onto the domain's vocabulary.
    ///
    /// Only the first is used: storage takes one `NoteSort`, and a second
    /// criterion would only matter for exact ties — which the identifier
    /// tiebreak already resolves deterministically.
    private static func noteSort(
        from sorts: [EntityQuerySort<NoteEntity>]
    ) -> NoteSort {
        guard let first = sorts.first else { return .mostRecent }

        let field: NoteSort.Field = switch first.by {
        case \NoteEntity.$title: .title
        case \NoteEntity.$observedAt: .observed
        default: .updated
        }
        let order: NoteSort.Order =
            first.order == .ascending ? .ascending : .descending
        return NoteSort(field: field, order: order)
    }
}

extension DateInterval {
    /// Everything from `date` onward. `DateInterval` needs both ends, and
    /// "after 1 August" has no upper bound a person intended.
    static func from(_ date: Date) -> DateInterval {
        DateInterval(start: date, end: .distantFuture)
    }

    static func until(_ date: Date) -> DateInterval {
        DateInterval(start: .distantPast, end: date)
    }
}
