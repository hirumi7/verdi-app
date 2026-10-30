# Verdi core (development only)

Original pure Dart domain primitives intended for the Flutter customer app.
No runtime package dependencies; package:test is development tooling only.
The locked dependency graph and SDK 3.13.7 are the tested baseline.

## Run

With Dart 3.13.7 (also bundled in the selected Flutter 3.47.8) on PATH:

```sh
dart pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test example
dart analyze
dart test
dart run example/care_walkthrough.dart
```

## Implemented subset

- Strict Gregorian dates, positive calendar intervals, anchored skip and overflow.
- Known/unknown routine seeds; completed care with date validation and today clamp.
- Historical additions and correction/void/explicit restore retain event identity,
  original recording context and audit while leaving the head/anchor unchanged.
- Checked-not-needed, snooze and skip retain their different meanings.

Methods return immutable snapshots. Callers cannot mutate an earlier snapshot or
its lists; rejection never changes it. This is the calculation layer, **not** the
CollectionStore, persisted DTOs or a database transaction. The future guarded
coordinator must check preview/target/session identity, command receipts and
entitlement before committing. Do not invoke these methods directly as UI saves.
Command IDs here are audit correlation, not an implemented retry guarantee.

The synthetic example deliberately keeps its state only in memory and injects a
clock. It does not persist user data, send requests or ask for OS permission.
No Flutter runner/UI, template source/assets, native SQLite, durable drafts,
purchase, reminder, backup, bulk or Undo implementation is included. Interval and
lifecycle edits, complete schema/audit mapping and native validation remain work.

Requirements and actual coverage are recorded in the
[delivery handoff](../../../../history/work/flutter-core-2026-10-30.md), bound
to the application's committed docs gitlink. Full requirements remain incomplete.
