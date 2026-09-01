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
