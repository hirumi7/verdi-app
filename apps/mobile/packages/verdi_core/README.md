# Verdi core (development only)

Original pure Dart domain primitives and a memory-only command harness intended
for the Flutter customer app. The locked dependency graph and SDK 3.13.7 are the
tested baseline. Runtime dependencies are Dart's
[characters](https://pub.dev/packages/characters) for grapheme-aware field bounds
and [crypto](https://pub.dev/packages/crypto) for SHA-256 command hashing;
package:test remains development tooling.

## Run

With Dart 3.13.7 (also bundled in the selected Flutter 3.47.8) on PATH:

```sh
dart pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test example
dart analyze
dart test
dart run example/care_walkthrough.dart
dart run example/guarded_save_walkthrough.dart
```

## Implemented subset

- Strict Gregorian dates, positive calendar intervals, anchored skip and overflow.
- Known/unknown routine seeds; completed care with date validation and today clamp.
- Historical additions and correction/void/explicit restore retain event identity,
  original recording context and audit while leaving the head/anchor unchanged.
- Checked-not-needed, snooze and skip retain their different meanings.
- A typed custom-plant editor with raw invalid text retained in one add draft and
  at most one edit draft per plant. Metadata/custom identity saves preserve care;
  custom species changes require explicit keep choices for every routine.
- Standard known/unknown care seeds commit with the new plant and consume its
  draft together. Text limits count graphemes, report all invalid fields and never
  truncate. New custom plants need no photo, network or Pro below the Free cap.
- Guarded plant/care commands with frozen IDs, canonical payload hashes, session
  previews, date/revision/access checks, atomic fake commits and receipt replay.
- Pending-command resolution after a simulated lost reply, before cancellation
  or retry. Replaying a committed command returns its original result even after
  the draft is consumed or later care changes its target revisions.
- Fake five-active-plant gating, capability changes and dataset-generation checks.
  Existing over-cap plants remain editable; simulated access is never a purchase.
- Interval changes and explicit override clearing follow effective last care or
  the chosen first check. Pause/resume/retire retain history; paused and archived
  interval editing cannot enable reminders. Retired routines are history-only.
- Archive/restore propagate atomically to every retained routine. Restore keeps
  paused/retired states, previews overdue-date clamps and checks active capacity.
- Schedule edits and lifecycle changes retain immutable before/after value audit.
- Typed Plants, detail, routine, event and combined care/schedule timeline reads;
  full-set counts and opaque keysets reject revision/date/query changes.
- Today separates overdue, today, next-seven-days and actual-care-only Done today.
  First-page summary includes the nearest eligible check beyond seven days.
  Reminder candidates are a consistent read, not scheduled OS notifications.
- Explicit same-kind bulk care validates 1–200 selected targets atomically and
  identifies invalid members. Retry reuses one group receipt and frozen IDs.
- Session-only eight-second Undo validates every routine revision, retains void
  corrections and schedule audit, restores values with current revisions and
  never renews a grant on replay/restart. Native deadline enforcement remains separate.
- Permanent deletion is available only after archive with a distinct preview.
  Content changes and acknowledged draft edits invalidate its confirmation.
  Owned records and frozen editor payloads are removed; minimal receipts still
  resolve retries. Unrelated plants/drafts remain intact.

## Harness usage and boundaries

`MemoryOperationCoordinator` exposes `getPlantEditor`, `readCollection`, `freeze`,
`prepare`, `execute` and receipt/pending-intent recovery. Commands are a closed,
typed Dart subset, not the full native CollectionStore DTOs or JSON decoder.
Freeze a `SaveDraft` before executing it; use the returned command ID again on
retry. Prepare a `SavePlant` or care command, display its effects, then execute
with the returned command ID and preview token. Changed inputs need a distinct
intent; re-previewing the same intent retains its allocated entity IDs.

`UnknownCommandOutcome` means the reply was lost, not that saving failed.
Resolve the original intent through `resolvePendingCommand`; a receipt read can
itself fail with `RecoveryUnavailable` and must be retried. Do not create a new
command merely because the outcome is unknown. An uncommitted operation needs
a fresh preview after coordinator recreation. Cancellation resolves receipts
before abandoning an uncommitted operation and keeps its draft; draft discard
is a separate confirmed command.

All reads are immutable snapshots. The store publishes a candidate collection
and its receipt through one synchronous state swap. Injected failures before
that swap leave everything unchanged; a lost reply after it leaves a recoverable
receipt. `reminderGeneration` models invalidation only. It neither schedules nor
acknowledges delivery of any notification. Calculation-only `RoutineCore` methods
remain available for tests; they do not by themselves enforce save guards.

**Memory only:** recreating the coordinator with the same live store simulates
reopening a session. Actual process termination loses everything. No SQLite,
disk durability, async native transaction serialization, Flutter runner/UI,
production entitlement, media, catalog reader or backup is included.
Catalog species/apply-suggestion choices, custom care, creation of replacement
routines, full event label/zone/schema mapping, journal timeline rows, custom-care
groups and native plan validation remain work. Those unimplemented fields cannot be
supplied through this typed editor; they are not silently accepted or dropped. Clock, UUID and
capability adapters are explicitly test inputs. No template source/assets copied.

Requirements and actual coverage are recorded in the
[current delivery handoff](../../../../history/work/app-readiness/README.md), bound
to the application's committed docs gitlink. Full requirements remain incomplete.
