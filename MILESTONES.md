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
