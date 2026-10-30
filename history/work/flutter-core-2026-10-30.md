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
Post-commit consumer and actual core results will be recorded below.

An isolated official Dart 3.13.7 macos_arm64 SDK was downloaded and verified
against its official SHA-256 sidecar before extraction:
`9f972ee1e1139cb4f845f35c7c77bef269dd2ec727b239fb17a2ebcb66d0fb2f`.
No global Flutter/FVM/host configuration changed. Flutter template dependency
resolution, native builds, devices and store verification have not run.
