# Milestones

This repository has no package versions. It has milestones, each verified
against **tagged** upstream releases rather than the workspace.

## The ritual

```
   1  bump kit and cold-storage in the Xcode project
   2  resolve · implement
   3  CLEAN build; check the metadata gate
   4  remove local packages from the workspace, rebuild against tags
   5  commit · tag the milestone (M3, M4 …)
```

Step 4 is the one people skip. Until it runs you have only built against
working copies, and the tag you are about to trust has never been compiled.

## M8 — Spotlight

Verified against domain 0.6.0, cold-storage 0.8.0, kit 0.8.0 — **no package
changes**, the first fully app-only wave.

```
   ✓  NoteEntity: IndexedEntity; NoteEntityQuery: IndexedEntityQuery
   ✓  capabilities 78 → 334 — bit 8 is IndexedEntityQuery
   ✓  a named CSSearchableIndex, not .default()
   ✓  the indexer subscribes to NoteServicing.changes — a contract from 0.1.0
   ⏳ every gate item below needs a physical device
```

### The gate needs hardware, not just the UI fix

⚠️ **Apple states Simulator indexing does not always match a device**, and the
plan flags M8 as the first milestone requiring one. So FR-1.8's "findable
within 60 s", "disappears within 60 s", FR-1.2's "tapping a result opens the
note", and the suggestion checks are **not** verifiable here — separately from
the `xcode-select` issue blocking the other milestones.

What is verified is everything reachable from the build: the conformances
extract, the query advertises indexing, and the app runs with the indexer
subscribed.

### Why Spotlight needed no package release

`SpotlightIndexer` consumes `NoteServicing.changes`, published in **kit 0.1.0**
and unchanged since. Spotlight is a *consumer* of an existing contract, not a
new capability — which is exactly what the plan predicted for waves 8–10.

### Two API facts worth keeping

**`indexingKey:` exists only on `@ComputedProperty` and `@DeferredProperty`**,
and both refuse a stored property. `@Property` has no such variant. So an
entity that wants its fields mapped onto Spotlight attributes has to *wrap* its
model and compute them — which is why `NoteEntity` now holds a private `Note`.

**`CSSearchableIndex` is not `Sendable`.** Holding one in an actor and using it
across an `await` is refused:

> error: sending 'index' risks causing data races

The indexer stores the index **name** and builds a handle inside `nonisolated`
helpers. A handle is per-call; the index is the file on disk.

### The bitfield, five conformances deep

```
   bit 0 (1)    EnumerableEntityQuery    notebooks · tags
   bit 1 (2)    EntityQuery base         all
   bit 2 (4)    EntityStringQuery        notes
   bit 3 (8)    EntityPropertyQuery      notes
   bit 6 (64)   common                   all
   bit 8 (256)  IndexedEntityQuery       notes — new this wave
```

## M7 — today's entry

Verified against domain 0.6.0, cold-storage 0.8.0, kit 0.8.0.

```
   ✓  OpenTodaysEntryIntent extracts, opens the app, returns a NoteEntity
   ✓  the Siri phrase compiles:
      Open today's entry in ${+applicationName}
   ✓  the daily-uniqueness index is on the device
   ~  Siri: "Open today's entry in Sparrow"                    FR-1.7
   ~  running it twice opens the same note
```

### Custom, not schema-based — and that is the requirement

Apple's journaling schemas surface in **Shortcuts only**; they never reach
Siri. FR-1.7 asks for a working *voice* phrase, so the intent has to be one of
ours. This is the first place a schema was rejected on purpose rather than
adopted, and the reason is in `architecture.md` §2.4.

### Idempotence is what makes the double call safe

The intent opens the entry, then `ContentView`'s `.onAppIntentExecution` asks
again — because the intent knows *that* a note was opened and the view needs to
know *which*.

That is only safe because `openOrCreateDailyNote` is idempotent. A
create-then-open pair here would produce two entries for one voice command, and
the second would win the display while the first sat orphaned.

### One compiler limit worth recording

The `NavigationSplitView` body stopped type-checking in reasonable time once
the alerts and the intent modifier were on it:

> error: the compiler is unable to type-check this expression in reasonable
> time

Extracting the sidebar into its own computed property fixed it. Worth knowing
that SwiftUI view bodies have a practical ceiling, and that the cure is the one
the compiler names.

## M6 — tags

Verified against domain 0.6.0, cold-storage 0.7.0, kit 0.7.0.

```
   ✓  TagEntity and TagEntityQuery reach the metadata
   ✓  TagEntityQuery is enumerable — capabilities 67, like notebooks
   ✓  NoteEntity.tags records as optional=True
   ✓  on-device schema reaches v4_tags with tag and note_tag
   ✓  tags are editable from Shortcuts, through UpdateNoteIntent
```

### `tags` is optional, and it had to be

Extra properties on an entity conforming to an Apple schema must be optional,
and `NoteEntity` adopts `.notes.note` at M9. Declaring it non-optional would
compile fine now and fail three milestones later — after every intent had been
written against it.

🧪 Confirmed in `extract.actionsdata`, where `tags` reads `optional=True` while
`title`, `body`, `kind` and `isPinned` read `optional=False`.

### The first entity whose identity is not a UUID

`TagEntity.ID` is a `String` — the slug. That is `TagID` showing through: a
tag's identity *is* its text, so two devices that have never met agree on it
without coordination, and a saved shortcut referring to `"wetlands"` resolves
on a fresh install.

### The bitfield, three queries deep

```
   NotebookEntityQuery   67   enumerable
   TagEntityQuery        67   enumerable — new this wave
   NoteEntityQuery       78   string + property queries, not enumerable
```

Small browsable sets enumerate; unbounded ones do not.

## M5 — Find action

Verified against domain 0.5.0, cold-storage 0.6.0, kit 0.6.0.

```
   ✓  a Find action exists in Shortcuts                       FR-1.4
   ✓  five properties and their comparators reach the metadata
   ✓  sortable by title · updatedAt · observedAt
   ✓  NoteEntityQuery adopts EntityPropertyQuery — 70 → 78
   ~  "kind is observation AND created after 1 Aug, sorted by
      updated descending" returns the right notes
   ~  the result chains into another app's action
```

### The comparator type is `NoteFilter`, not `Predicate<NoteEntity>`

Apple's Trails sample maps comparators to in-memory `Predicate`s and evaluates
them over every entity. That is fine for a few dozen trails and wrong for
notes: a field notebook grows without bound, and answering "kind is
observation" would mean loading every note first.

`NoteFilter` is data that storage compiles into bound SQL with a `LIMIT`. The
Find action a person builds in Shortcuts becomes a query, and nothing above
storage sees a row it did not ask for. This is what the type was created for
in domain 0.5.0.

### The extracted vocabulary

```
   title      → contains
   body       → contains
   kind       → equalTo, linked to NoteKindAppEnum
   isPinned   → equalTo
   updatedAt  → >= and <=
   sortable   → title · updatedAt · observedAt
```

🧪 Read out of `extract.actionsdata`, so this is what the system received —
not what the source says.

### `@preconcurrency import AppIntents` is required

`EntityQueryProperties` and `EntityQuerySortingOptions` are not `Sendable`, so
declaring them as `static let` fails Swift 6's global-state check. Apple's own
sample opens the same way, for the same reason.

### The bitfield, extended again

```
   bit 0 (1)   EnumerableEntityQuery    notebooks
   bit 1 (2)   EntityQuery base         both
   bit 2 (4)   EntityStringQuery        notes
   bit 3 (8)   EntityPropertyQuery      notes — new this wave
   bit 6 (64)  common
```

## M4 — text search

Verified against domain 0.4.0, cold-storage 0.5.0, kit 0.5.0.

```
   ✓  searching "heron" finds "Herón"                         FR-1.3
   ✓  NoteEntityQuery adopts EntityStringQuery
   ✓  the metadata gate prints both processors; 9 intents extracted
   ✓  on-device schema reaches v3_fts with remove_diacritics 2
   ~  Siri: "Search Sparrow for waders"
```

### The capabilities bitfield, now decoded

Three waves of evidence, each from building the same query two ways:

```
   bit 0 (1)   EnumerableEntityQuery    notebooks yes · notes no
   bit 1 (2)   EntityQuery base         both
   bit 2 (4)   EntityStringQuery        notes yes — new this wave
   bit 6 (64)  common to both
```

`NoteEntityQuery` went **66 → 70** when it adopted `EntityStringQuery`.
🧪 Verified, Xcode 27. This is now a cheap way to confirm a query conformance
actually reached the system, rather than trusting that it compiled.

### `entities(matching:)` runs the app's own search

Siri resolving "my heron note" goes through `SearchServicing.search`, the same
path the search field uses. So FR-1.3's diacritic folding applies to a spoken
query too — someone who says "heron" reaches a note titled "Herón" without the
intent layer knowing anything about tokenisers.

### The search field is debounced by cancellation, not by a timer

`.task(id: model.query)` tears down the previous search when the query changes,
so the 150 ms sleep is only survived by the last keystroke. There is no timer
to cancel and no state to reset — the structured-concurrency lifetime *is* the
debounce.

## M3 — notes, entities and intents

Verified against domain 0.4.0, cold-storage 0.4.0, kit 0.4.0.

```
   ✓  the picker offers the six most recently edited notes    FR-1.6
   ✓  no entity carries image data — names only               NFR-1.4
   ✓  a saved shortcut resolves after delete + reinstall      NFR-1.3
   ✓  CreateNote returns a NoteEntity, so it can chain into OpenNote
   ✓  the metadata gate prints both processors
   ~  parameter summaries read as sentences for EVERY kind
```

### The two queries differ on purpose, and the metadata proves it

```
   NotebookEntityQuery  capabilities 67  → enumerable bit 1
   NoteEntityQuery      capabilities 66  → enumerable bit 0
```

Notebooks enumerate: a small, fixed set, so Shortcuts shows a picker with no
typing. **Notes deliberately do not.** Enumerating means handing the system
every note, and a field notebook grows without bound — the picker would be
unusable and the payload large. Notes get `suggestedEntities()` returning the
six most recent instead, which is FR-1.6.

### NFR-1.3 is a property of the identifier

`NoteEntity.id` is `NoteID.value` — a **client-generated UUID**, stored in
SQLite. Not a row id, not an index. A shortcut saved months ago resolves after
a delete and reinstall because the identifier came from the note rather than
from the database's bookkeeping.

### NFR-1.4, checked in the extracted metadata

No `image`, `imageData`, `displayImage` or `data` key appears anywhere under
`entities` in `extract.actionsdata`. Entities are serialised into saved
shortcuts, Siri suggestions and the on-device index; pixels in one would bloat
all three and copy content somewhere it cannot be revoked.

## M2 — notebook CRUD

Verified against domain 0.3.0, cold-storage 0.3.0, kit 0.3.0.

```
   ✓  the sidebar updates with no explicit refresh call
   ✓  deleting a non-empty notebook shows an actionable message
   ✓  the metadata gate prints both processors
   ✓  extract.actionsdata names all five intents
   ~  the CRUD intents run from Shortcuts
```

### The refresh gate, structurally

`loadNotebooks()` has exactly two call sites: once at launch, and once from
`NotebookServicing.changes`. There is no `onAppear`, no `refreshable`, no
`onChange` anywhere in the app. A write from any source in this process shows
up because it was *announced*, not because a view happened to reappear.

⚠️ **In this process.** The change broadcaster lives inside one `ColdStorage`
instance, so a separate extension writing the same file would go unnoticed.
Cross-process observation needs `DatabaseRegionObservation` or a Darwin
notification, and is not in V1 — which will matter when a widget arrives.

### No `.delete` in ConfirmationActionName

🧪 `ConfirmationActionName` offers add · buy · create · open · send · set ·
share · start · toggle and about twenty more, and **nothing destructive**.
`DeleteNotebookIntent` therefore calls `requestConfirmation(dialog:)` without
an action name, and the dialog carries the weight: the button says "Continue",
so the sentence has to say what will happen.

## M1 — notebook picker

Verified against domain 0.2.0, cold-storage 0.2.0, kit 0.2.0.

```
   ✓  the sidebar lists notebooks from disk
   ✓  the composition root switched to ColdStorage.make(at:) —
      nothing above it changed                                ◄── the real test
   ✓  the metadata gate prints both processors
   ✓  extract.actionsdata names NotebookEntity, NotebookEntityQuery
      and OpenNotebookIntent
   ~  the picker populates in Shortcuts with NO typing
```

The composition-root swap was **one line** — `.inMemory()` became
`.make(at: storeURL)`. No view, no intent and no entity changed. That is the
whole argument for handing back protocols, and it is the milestone's real gate.

### Proving the picker without the UI

The last item needs the simulator, so the strongest available substitute is the
extracted metadata. `NotebookEntityQuery` is recorded with a `capabilities`
bitfield, and dropping the `EnumerableEntityQuery` conformance changes it:

```
   with    EnumerableEntityQuery →  capabilities: 67
   without EnumerableEntityQuery →  capabilities: 66
```

**Bit 0 is enumerability.** 🧪 Verified by building both ways, Xcode 27. So
`capabilities & 1 == 1` says the system will offer a picker rather than a text
field — which is FR-1.5. It is not a substitute for seeing the list appear, but
it is a check that can run on every build.

## M0 — skeleton and metadata proof

Verified against domain 0.1.0, cold-storage 0.1.0, kit 0.1.0.

```
   ✓  editing Note in sparrow-domain rebuilds the app immediately
   ✓  the metadata gate prints both processors
   ✓  extract.actionsdata names CreateNoteIntent
   ⏳ the intent appears in Shortcuts and runs
   ⏳ FORCE-QUIT the app, run the intent — it still works
```

The last two need the simulator UI. They are the point of the milestone, not
paperwork: the force-quit test catches the single most common App Intents
crash — dependencies registered in a view's `.task` instead of `App.init()`.
That bug works throughout development, because you keep launching from Xcode,
and fails for every user who never opens the app.

`AppDependencies.register()` is called from `SparrowApp.init()` precisely so
this passes. A background intent invocation has no scene, so no view lifecycle
callback is guaranteed to run.
