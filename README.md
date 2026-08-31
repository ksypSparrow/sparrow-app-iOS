# Sparrow

Sparrow FieldNotes — the app, and the only repository that ships anything.

It also holds **every App Intents type in the project**. That is not an
accident of layout: an intent needs `AppIntents`, and no package below may
depend on it, or `SparrowKit` would stop building anywhere App Intents is
unavailable — the V2 server being exactly such a place.

## What links what

```
   Sparrow.app
     ├─► ServiceContracts   everywhere: views, intents, entities
     ├─► Services           composition root only
     ├─► ColdStorage        composition root only — one factory call
     └─► SparrowDomain      value types
```

`AppDependencies` is the composition root and the single place `ColdStorage` is
named. Everything it hands out is a protocol, so no view and no intent can
discover that storage exists.

## Milestones

| | Milestone | Waits for |
|---|---|---|
| **M0** | skeleton · metadata proven | kit 0.1.0 |
| M1 | notebook picker | kit 0.2.0 |
| M3 | notes · entities · intents | kit 0.4.0 |
| M9 | Apple `.notes` schemas | — |

Full plan: [`plans/sparrow-app.md`](../01-Sparrow-FieldNotes/plans/sparrow-app.md)

## The metadata gate

Building tells you nothing about whether the system *extracted* your intents.
Extraction failures are silent: the build succeeds and nothing appears in
Shortcuts. Run this on **every** milestone, on a clean build:

```bash
xcodebuild -scheme Sparrow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' \
  -derivedDataPath /tmp/dd CODE_SIGNING_ALLOWED=NO clean build 2>&1 \
  | grep -iE 'appintentsmetadataprocessor|appintentsnltrainingprocessor'
```

Both must print. `appintentsnltrainingprocessor` should name your phrases:

```
   Training 'New note in ${+applicationName}|Create a note in
   ${+applicationName}' for en
```

⚠️ Incremental builds skip both phases. Always `clean`.

## Build

```bash
xcodebuild -scheme Sparrow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' \
  CODE_SIGNING_ALLOWED=NO build
```

For day-to-day work open `../Sparrow.xcworkspace` instead — it contains all
four repositories, and a local package shadows its resolved remote version, so
you can edit across every layer and build once.

## Documents

Design lives with the lab, in
[`01-Sparrow-FieldNotes/`](../01-Sparrow-FieldNotes/) — until this repository
absorbs it.
