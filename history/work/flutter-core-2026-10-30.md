# Flutter core delivery

**Author:** Codex (AI assistant).
**Date:** 2026-10-30 (Asia/Jakarta).

## Authority and preserved baseline

The user requested committing/pushing the reviewed docs, updating the app pin,
then starting the Flutter core while preserving all work and accepted decisions.
App baseline: a8546c50bf0fc2ddacb9da2849da4d4497217143, clean. Previous docs pin:
2b3256acf795abc757302713b7d98d2e93614a38. No reset, default-branch change or import
deletion is involved. Raw Claude imports remain ignored and untouched.

Published docs: **b6519e8a6946d4767b75467cd48925e0c8dcc046**, on
`codex/verdi-workflow-full-2026-10-27` in hirumi7/verdi-docs. Remote branch SHA
and fetch through the actual app submodule remote both verified. All 18 accepted
requirement digests matched; the prior 17 accepted files and original intakes
remain byte-identical. All preexisting documentation changes were included.
The [selected review](../../docs/history/reviews/customer-admin-2026-10-27.md)
permits only the synthetic-data/fake-adapter core, not native real-data/release use.

## First bounded implementation

Start an independently authored pure Dart package under `apps/mobile/packages/`.
Implement/test Gregorian LocalDate and interval arithmetic, a single routine's
care/history transitions and an explicit in-memory harness. Main criteria:
REQ-007 history identity/correction/unchanged head, REQ-008 calendar arithmetic,
known/unknown seeds, completion guard, check/snooze/skip and override behavior.
No whole requirement is declared delivered; drafts, collection UI, native SQLite,
durable commands/previews, bulk/Undo, payments, backup and notifications remain.
Template code/assets are not copied while their provenance remains unresolved.
This package is usable by Flutter later, not a completed Flutter runner/template.

## User-supplied design reference

On this turn the user supplied [Figma node 5:2](https://www.figma.com/design/j2I5k6LkRUkpvzDHNwpvdF/Verdi--Plant-Care-App--Claude-Design-Import-?node-id=5-2).
Retain it for the future screen phase. No canvas/asset inspection, visual fidelity
or artwork-rights claim is made here; accepted requirements govern conflicts.
Before UI implementation use the Figma design-to-code skill and real node context.

## Verification

Docs aggregate: 8/8 passed, 268 tooling tests (252.740 seconds). Input manifest
matched immediately before staging; independent preservation audit passed.
Staged app gitlink and full consumer handoff checks passed at the published pin.
Post-commit consumer handoff passed after pin commit
`ad7ac5a` on `codex/flutter-core-2026-10-30`.

An isolated official Dart 3.13.7 macos_arm64 SDK was downloaded and verified
against its official SHA-256 sidecar before extraction:
`9f972ee1e1139cb4f845f35c7c77bef269dd2ec727b239fb17a2ebcb66d0fb2f`.
No global Flutter/FVM/host configuration changed. Flutter template dependency
resolution, native builds, devices and store verification have not run.

## Implemented and checked subset

Code: [verdi_core](../../apps/mobile/packages/verdi_core/README.md), independently
authored, no template code/assets copied. No runtime third-party dependencies;
package:test development dependencies are locked in pubspec.lock.

| Requirement subset | Actual code/check coverage | Remaining full requirement behavior |
| --- | --- | --- |
| REQ-007 AC1–3,5–6 calculation/data subset | Stable event identity/original local date/UTC context; effective history; history-only addition; correction/void/explicit restore audit; immutable previous snapshots and head preservation | Serialized schema/label/zone validation, native persistence, preview UI, durable receipts/retries, grouped Undo, archived/retired/deleted collection integration |
| REQ-008 AC2–8,12–13 calculation subset | Unknown/known seeds; future/earlier-than-latest guard; actual-date recurrence/today clamp; Gregorian month/year/day/week math; checked-not-needed, snooze and anchored skip; one stable head in each routine snapshot | Plant-level uniqueness, original suggestions, interval/override-clearing edits, pause/archive/resume, database rollback, UI confirmations and duplicate-command recovery |

These are partial implementation results, not completion of either requirement.
Canonical docs coverage remains conservative; no accepted text or approval digest
was changed to represent code progress. The pure immutable planner is not a
CollectionStore or a serializable persistence model. Command IDs are audit
correlation here, not proof of idempotency; the future coordinator owns that gate.

Executed with official Dart 3.13.7 macos_arm64:

- `dart pub get --enforce-lockfile`: passed against the committed lock candidate.
- `dart format --output=none --set-exit-if-changed lib test example`: passed.
- `dart analyze`: passed, no issues.
- `dart test`: 23 tests passed, independently repeated by a separate reviewer.
- Calendar subset: 11 tests passed under both America/New_York and
  Pacific/Kiritimati process timezones; sampled 400-year and reference-cadence
  checks also passed. These are calendar tests, not device notification DST tests.
- `dart run example/care_walkthrough.dart`: rejected early current completion
  with CARE_PRECEDES_LATEST; separate historical addition produced 2 actual events,
  latest care 2026-10-20 and unchanged next check 2026-10-27.
- Independent code review: no blocking finding in the declared subset. Root
  rechecked source/test diff, ignored build/tool output and immutable source owners.

## Next action and release boundary

**Historical next step; continued in the
[guarded-save delivery](guarded-saves-2026-10-30.md).** The evidence above records
the first published slice and remains unchanged by later implementation.

Next implement and test the guarded command coordinator with explicit preview,
frozen identity/receipt recovery and injected failure cases, then collection/draft
integration. Keep native SQL/OS/store implementations and Flutter UI behind their
separate reviews. The current runnable example is synthetic and memory-only:
it is not a real-data app, a full Flutter-template dependency solve or a release.
Figma inspection/visual verification belongs to the later UI phase.
