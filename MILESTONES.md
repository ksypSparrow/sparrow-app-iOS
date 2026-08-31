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
