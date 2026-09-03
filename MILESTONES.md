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

## M11 — localization

Verified against domain 0.6.0, cold-storage 0.8.0, kit 0.9.0.

```
   ✓  the NL trainer logs phrase templates for BOTH locales    NFR-1.1
   ✓  no user-facing String literal outside a catalog
   ✓  INAlternativeAppNames with pronunciation hints
   ✓  en.lproj and fr.lproj both ship in the bundle
   ~  Shortcuts reads naturally in the second language
   ~  every response works on AirPods with the screen off
```

### NFR-1.1, in the build log

```
   Training 'New note in ${+applicationName}|…' for en
   Training 'Nouvelle note dans ${+applicationName}|…' for fr
   …
   Training Negative Phrases '' for en
   Training Negative Phrases '' for fr
```

Five phrase sets per locale. `appintentsnltrainingprocessor` has printed
`for en` on every build since M0; this is the first time it prints twice.

**`${applicationName}` survives translation.** It is a token the trainer
substitutes, not a word — a translator who localised it would break the
matching, and nothing would report it.

### Three catalogs, not one

| | |
|---|---|
| `AppShortcuts.xcstrings` | the phrases Siri matches |
| `AppIntents.xcstrings` | intent titles, parameter names, dialogs |
| `Localizable.xcstrings` | everything the UI says |

Kit carries its own for `ServiceError`. That is the wave-0 boundary showing up
in the localization work: the app maps `ServiceError` into `SparrowIntentError`,
so it owns those strings while kit owns the originals.

### The literal check found three

A grep over the APIs that show a string to a person — `Text`, `Button`,
`IntentDescription`, `dialog:`, `title:` and the rest — against the catalogs'
keys turned up `"Created"`, `"Modified"` and `"Here's today's entry."`. Added
rather than waved through; the gate says *no* literal, and eyeballing a
40-string catalog does not prove that.

### `INAlternativeAppNames` needs a real `Info.plist`

`INFOPLIST_KEY_INAlternativeAppNames` takes a comma list and **cannot express
a pronunciation hint** — the key is an array of dictionaries. So the app has an
`Info.plist` again, merged with the generated keys.

⚠️ It lives *outside* `Sparrow/`, because the synchronized folder group would
otherwise copy it as a resource *and* use it as the Info.plist:

> error: Multiple commands produce … /Sparrow.app/Info.plist

The hint matters more than it looks: a mis-heard app name means the phrase
never matches, and the person concludes the shortcut is broken rather than
mispronounced.

## M10 — navigation and UI

Verified against domain 0.6.0, cold-storage 0.8.0, kit 0.8.0 — **no package
changes**, the third and last app-only wave.

```
   ✓  no intent's perform() touches Navigator on iOS
   ✓  the app builds for macOS as well as iOS — first time
   ✓  handlesExternalEvents scene targeting
   ✓  SiriTipView and ShortcutsLink, dismissal persisted     FR-1.10
   ~  every open-style intent lands on the right screen, iOS AND macOS
   ~  two windows open: an intent does not navigate the edited one
```

### `Route`, not two optionals

"A note is open" and "a notebook is selected" are alternatives. Two optionals
can be both at once — a state the UI has no way to draw — so `Navigator` holds
one `Route`.

### Navigation left the intents

`OpenNoteIntent`, `OpenNotebookIntent` and `OpenTodaysEntryIntent` no longer
touch `Navigator` on iOS. `.onAppIntentExecution` fires on the **scene that ran
the intent**, which is what stops two open windows fighting over which one
moves: the one asked navigates, and the one being edited in stays put.

### 🧪 Four APIs are unavailable on macOS

The plan anticipated a `#if os(macOS)` branch. The reality is stronger — these
are not merely absent, they cannot be *named*:

```
   TargetContentProvidingIntent   'unavailable in macOS'
   .onAppIntentExecution          no such member
   SiriTipView                    'unavailable in macOS'
   ShortcutsLink                  no such member
```

`TargetContentProvidingIntent` is the sharp one: the **conformance** has to be
gated, not just the call site, so it moved to
`#if os(iOS) extension … {}`. A `#if` around the method would still have failed
to compile.

This is also the first time the app has been built for macOS at all. The
project has claimed `macosx` in `SUPPORTED_PLATFORMS` since M0, and nothing had
tested it.

### FR-1.10 needs no mechanism

`SiriTipView` writes through its `isVisible` binding when someone dismisses it.
Binding that to `@AppStorage` rather than `@State` is the entire
implementation — there is nothing to remember to persist.

## M9 — Apple schemas

Verified against domain 0.6.0, cold-storage 0.8.0, kit 0.8.0 — **no package
changes**, the second app-only wave.

```
   ✓  it compiles, and — more to the point — it extracts
   ✓  NoteEntity, NotebookEntity, AccountEntity, CreateNoteIntent,
      UpdateNoteIntent all carry domain: notes conformances
   ✓  attachments is present and empty; nothing breaks
   ⏸️ .journal.createEntry deferred — see below
   ~  Siri handles phrasings you never wrote a shortcut for
   ~  the journal action appears in Shortcuts but NOT in Siri
```

### Schema conformance is enforced at *extraction*, not compilation

Every requirement below came from `appintentsmetadataprocessor` **after a clean
compile**. A probe that only type-checks proves nothing about a schema.

| What the extractor demanded | |
|---|---|
| `.notes.folder` needs `account` | Sparrow has no accounts |
| `.notes.account` needs `name` | |
| `name` must index to `\.displayName` | not `\.title` |
| `.notes.createNote` wants `name: String` | while `.notes.note` wants `AttributedString` |
| `attachments` needs `supportedTypeIdentifiers` | |
| `attachments` optional on `updateNote`, not on `createNote` | |
| `folder`'s entity needs an `EntityStringQuery` | |

### The open question, answered

🧪 **Yes — a schema intent can add `& ProvidesDialog`.** Both note intents
return `some IntentResult & ReturnsValue<NoteEntity> & ProvidesDialog` and the
extractor accepts it, so FR-1.1 keeps its spoken confirmation.

### What adopting the schema cost

⚠️ **Filter-by-kind is gone from the Find action.** Extras on a
schema-conforming entity must be optional, so `kind` became
`NoteKindAppEnum?` — and `EntityPropertyQuery` rejects an optional enum with a
misleading *"no extractable localized title"*. M5 shipped that capability;
M9 removed it.

`kind`, `observedAt` and `tags` also left the intent signatures: a schema
intent cannot add parameters the schema does not have.

### `.journal.createEntry`, deferred

The extractor demands `entryDate`, `location`, `mediaItems`, `message` **and** a
`JournalEntity` return type — which needs its own `.journal.entry` conformance,
bringing location and media concepts Sparrow does not have.

The schema also never reaches Siri. So the whole cascade buys a Shortcuts-only
action that `OpenTodaysEntryIntent` (M7, custom, voice-capable) already covers.
Recorded in the plan rather than half-modelled.

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
