# Schedule edits and plant lifecycle core

**Author:** Codex (AI assistant).
**Date:** 2026-10-31 (Asia/Jakarta).

## Authority and preserved baseline

The user requested continuing development after the guarded-save delivery.
Applied the pinned delivery skill and verified its selected ready review/input
manifest before implementation. This remains the separately reviewed synthetic
pure-Dart/fake-adapter scope, not native real-data or release readiness.

Exact unchanged docs pin: **b6519e8a6946d4767b75467cd48925e0c8dcc046**.
App HEAD remains `bd7ef9fd0be978a7f6b336aecaffd1a3fa372aec` on
`codex/flutter-core-2026-10-30`. The [previous guarded-save work](guarded-saves-2026-10-30.md)
was already uncommitted at start and was preserved, including all 60 existing
tests. A local snapshot of the existing source, tests, manifests and handoffs
was made before edits for preservation/diff review. No reset or checkout switch.
No accepted requirement, decision, docs file, pin, dependency version or raw
Claude import changed. No remote commit/push was requested or performed here.

Contracts: [local data and care](../../docs/technical/local-data-and-care.md)
sections 2–5 and lifecycle/history reads; relevant interaction boundaries in
[customer interactions](../../docs/technical/customer-interactions.md).
Requirement scope is REQ-006, REQ-007, REQ-008 and REQ-014; all remain partial.

## Implemented behavior

- `SetInterval` uses the effective latest actual care with a today clamp, retains
  an existing date override, or keeps the explicit first-check seed. When no
  usable actual care/first seed remains, a chosen first check is required.
- `ClearOverride` explicitly recalculates. Without actual care, it requires a
  chosen first date even if an older first-check seed exists. Neither command
  invents an event. Overflow rejects without changing saved state.
- `PauseRoutine`, `ResumeRoutine` and `RetireRoutine` preserve history and head
  identity. Resume clamps an overdue head/override to today. Retired routines
  remain selectable for historical correction, not current care or resumption.
  Paused/archived interval edits leave reminder eligibility off.
- `ArchivePlant` retains all supported records and removes eligibility.
  `RestorePlant` preserves plant/routine IDs, clamps only non-retired heads,
  preserves paused/retired status and checks the five-active-Free-plant gate.
  Archived plants no longer count toward capacity; archived metadata edits do
  not silently restore them.
- Explicit schedule edits (including Snooze) and lifecycle propagation record
  immutable before/after value snapshots, change date, recording instant/zone,
  command ID and care label. Custom-only suggestion references are null; stable
  head ID is retained in the audit. `getScheduleChange` resolves retained records.
- `DeletePlant` requires archived state and a distinct permanent-delete preview.
  The preview exposes counts for supported owned records and binds collection,
  plant, routine and acknowledged editor revisions. Changed content or draft
  inputs require renewed review, including an unrelated saved-content change.
- Confirmed deletion removes owned plant/routine/head/history/correction/audit
  and current editor records, plus related frozen editor/command payloads.
  Minimal ID/revision/outcome receipts still resolve lost replies. Cancelling or
  injected pre-commit failure preserves everything; unrelated plants/drafts stay
  intact. The delete receipt identifies the removed plant, not a live detail.
- Collection snapshots expose active/archived plant and eligible-routine
  projections. These are eligibility primitives, not the full paginated Today,
  timeline or native reminder APIs. Editor routine bases exclude retired routines
  and an already-open draft must be explicitly re-reviewed after retirement.

## Coverage and remaining scope

| Requirement subset | New evidence | Still outside this slice |
| --- | --- | --- |
| REQ-006 AC7–11 | Retained editor conflicts, archive/restore, distinct delete confirmation, scoped atomic deletion and retry recovery | Actual UI dialogs, photos/journal/filesystem cleanup, catalog/apply suggestions and process durability |
| REQ-007 AC4,9–11 | Retries do not duplicate schedule audit; retirement retains readable care; archive retains history; only confirmed deletion removes owned history/audit | Full label/native schema mapping, replacement-routine creation, grouped Undo, backup |
| REQ-008 AC9–12 | Interval and override rules, pause/archive/resume/restore, stable heads, no invented care, rollback and audit | Complete UI, native persistence, original catalog suggestions, full Today/bulk/Undo |
| REQ-014 AC1–2,6,8–9 | Archived count exclusion, guarded restore, upgrade re-preview of same intent, retained over-cap data | Real store verification, purchases, native adapters and import/restore integration |

The command model remains typed Dart, not complete native DTOs or SQL. Manual
schedule/lifecycle audit is delivered; existing completion/check/skip events
remain their historical action evidence. Full wire mapping, combined timeline
rendering and production audit/Undo persistence are not claimed. Deletion has no
media/journal cleanup implementation because those record types are not present
in this harness. Final UI must show the removal summary and destructive warning,
including that external exports cannot be removed; confirmation keys/counts alone
do not prove that rendered flow.

Memory stores are still lost on actual process termination. Recovery tests reuse
the same live memory store with a new coordinator. Cleanup is synchronous before
the simulated lost-reply boundary. Older snapshots already returned to callers
may remain in memory; no secure-erasure guarantee is made. No template code,
assets, Flutter runner, OS integration or public release is introduced.

## Verification and review

The previous temporary SDK directory was absent. Restored official Dart 3.13.7
macos_arm64 into the user cache, verifying both its official checksum sidecar and
the previously recorded archive SHA-256:
`9f972ee1e1139cb4f845f35c7c77bef269dd2ec727b239fb17a2ebcb66d0fb2f`.
No host PATH, Flutter/FVM installation or locked package version changed.

Self-review only; no independent reviewer is claimed. Review covers preservation of the earlier
60-test behavior, interval/override precedence, archived metadata stability,
non-retired draft bases, all-routine rollback, cap and child-revision guards,
deletion confirmation invalidation, receipt-first recovery after payload cleanup,
and absence of accepted-document changes.

| Executed check | Final result |
| --- | --- |
| `dart pub get --enforce-lockfile` | Passed; existing dependency files unchanged |
| `dart format --output=none --set-exit-if-changed lib test example` | Passed; 16 files, zero changes |
| `dart analyze` | Passed; no issues |
| `dart test` | Passed; 77 tests, including all previous 60 and 17 new lifecycle/schedule integration cases |
| `dart run example/care_walkthrough.dart` | Passed; original October historical-care behavior unchanged |
| `dart run example/guarded_save_walkthrough.dart` | Passed; lost reply resolves one plant/one event/zero drafts; retry replays |
| `python docs/scripts/check_gitlink.py --root . --docs-path docs` | Passed; clean unchanged indexed docs pin |
| `python docs/scripts/check_consumer.py --root . --mount docs` | Passed; committed pin and ready scoped input manifest verified |
| `python docs/scripts/check_all.py --root docs` | Passed; 8/8 checks, 268 tooling tests in 46.468 seconds |
| `git diff --check` and preservation comparison | Passed; no baseline file lost, prior test/dependency files byte-identical, docs checkout clean |

Commands ran from the package except docs/Git checks from app root. Python used
the existing docs-tooling virtual environment. No native/Flutter/device/store
tests ran; the reviewed scope is still memory-only. Changes remain local and
uncommitted alongside the preserved previous work.

## Next step

Continue the reviewed fake core with Today/timeline reads, explicit bulk actions
and guarded Undo, followed by catalog-backed editing/replacement routines. Native
durability, Flutter/template integration, devices/stores and Figma-rendered UI
still need their separate implementation and verification gates.
