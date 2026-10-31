# Guarded saves, retry recovery and collection/draft integration

**Author:** Codex (AI assistant).
**Date:** 2026-10-30 (Asia/Jakarta).

## Authority and preserved inputs

The user requested continuing the core with guarded saves, retry recovery and
collection/draft integration while preserving accepted requirements and existing
work. This continues the [first published core](flutter-core-2026-10-30.md).
App baseline: `bd7ef9fd0be978a7f6b336aecaffd1a3fa372aec`, clean on inspection,
branch `codex/flutter-core-2026-10-30`. Existing calendar/care source and tests
remain unchanged. Raw imports remain ignored and untouched.

Exact unchanged docs pin: **b6519e8a6946d4767b75467cd48925e0c8dcc046**.
The selected [review](../../docs/history/reviews/customer-admin-2026-10-27.md)
and its input manifest permit synthetic pure-Dart/fake-adapter development only.
Owners: [local data and care](../../docs/technical/local-data-and-care.md),
especially sections 2–4 and 6; REQ-006, REQ-007, REQ-008 and REQ-014.
No product documents, accepted requirements, decisions, digests or readiness
records changed. Full requirements remain incomplete. No pin update needed.

## Delivered bounded behavior

The [package](../../apps/mobile/packages/verdi_core/README.md) now has a closed
typed command harness over an immutable in-memory collection. Plant, routine,
head, seed event, consumed draft and receipt publish together. A pre-commit
failure leaves the prior collection snapshot and draft intact. A post-commit
lost reply produces an unknown outcome, resolved from the original receipt.
Retries return the original IDs/revisions before stale-state guards run.

Draft-only writes keep collection revision and reminder generation unchanged;
each successful content command advances the collection revision once. Draft
revisions protect acknowledged input, including invalid raw strings. Final text
validation counts graphemes, rejects NUL/unpaired surrogates, reports all invalid
field paths and never truncates. The 1 MiB serialized bound retains the previous
acknowledged draft on failure.

Preview confirmations bind command identity/hash, draft/target revisions, local
day and applicable access revision. They expire after ten monotonic minutes and
are invalid in a new coordinator session. Re-previewing the same intent preserves
allocated IDs. Dataset replacement simulation rejects old callbacks before any
receipt replay. Unknown receipt-read outcomes remain unresolved; cancellation
resolves first, abandons only an uncommitted operation and keeps its editor.

Custom-plant metadata edits retain identity/history. Changing custom species or
its custom labels requires explicit keep choices for all retained routines.
Any care/history change while editing makes that draft's routine bases stale;
the current plant/history cannot be overwritten by those old choices. Raw draft
bases are never silently refreshed when reopening. A caller must explicitly
review current state and acknowledge a rebased draft before saving.

The five-active-Free-plant baseline is applied only to new plants. Fake upgrade
continuation re-previews the same intent; fake downgrade retains all existing
plants, history and edit access. These are simulated capabilities, not purchases.
No actual price, store setup, media permission or account service is involved.

## Partial requirement coverage

| Requirement subset | Implemented evidence | Remaining behavior |
| --- | --- | --- |
| REQ-006 AC1–9, custom/no-photo subset | Add/edit raw drafts; text/custom-label validation; known/unknown standard seeds; custom species keep choices; stale edit rejection; atomic save and receipt recovery; confirmed discard | Catalog and media paths, apply suggestions, real process-death durability, user-facing editor/confirmation/purchase flows, archive/restore/delete, export/import |
| REQ-007 AC1–6, integrated fake subset | Guarded history additions/corrections/void/explicit restore through saved collection; persistent-in-receipt history-only notice; original event identity and current head retained; duplicate commands replay once | Native schema/recording context/label mapping, UI explanations, grouped Undo, lifecycle and backup retention |
| REQ-008 AC1–8,12–13, standard-care subset | One standard kind/head at creation; existing recurrence engine used by atomic saved care/check/snooze/skip; future/earlier-date guards; previewed next dates; event/head rollback and retry | Original catalog suggestion snapshots, interval/clear-override editing, pause/archive/resume, native persistence and UI |
| REQ-014 AC1–2,6,8–9, simulated add/edit subset | Fifth plant accepted, sixth gated; draft retained; same-intent upgrade continuation; stale access preview rejected; over-cap records still readable/editable | Verified store evidence/cache/revocation, restore/archive, custom-care/cosmetic/photo gates, production purchase UI and backup exclusion proof |

## Implementation boundaries

The store is synchronous on one Dart isolate. Its sole immutable state-pointer
swap models a transaction; it does not prove SQLite durability, native guards,
multi-isolate coordination or a filesystem crash. Reopening tests create a new
coordinator over the **same live memory store**. Ending the actual process loses
all state. No real-data use or public release is enabled.

The typed Dart command model is a subset, not the full CollectionStore wire DTOs.
No external JSON decoder, Pigeon/native plan encoder, SQL executor, full schema,
routine-change audit, media ownership or notification outbox has been delivered.
History operations carry a typed full routine target in this harness; exact
native DTO mapping still belongs to the separately reviewed boundary work.
`reminderGeneration` is an atomic fake invalidation counter, not OS scheduling.
Missing catalog/media/custom-care fields are unavailable in this editor rather
than accepted and dropped. Clock/zone/UUID/capability adapters remain test-only.

Runtime dependencies are [characters 1.4.1](https://pub.dev/packages/characters/versions/1.4.1)
for grapheme boundaries and [crypto 3.0.8](https://pub.dev/packages/crypto/versions/3.0.8)
for SHA-256. Crypto was already the locked test dependency; no existing dependency
version was upgraded. Their official Dart-published package documentation was
checked. The canonical encoder sorts ASCII object keys, retains array order,
keeps strings case-sensitive and rejects non-integer/out-of-range numbers. A
fixed hash vector was separately calculated with Python hashlib.

## Verification and review

Environment: the existing isolated official Dart 3.13.7 macos_arm64 SDK from the
first delivery; no host Flutter/FVM configuration or default branch changed.
Checks run from the package except documentation commands, which run at app root.

| Executed command | Final outcome |
| --- | --- |
| `dart pub get --enforce-lockfile` | Passed; locked graph resolves without upgrades |
| `dart format --output=none --set-exit-if-changed lib test example` | Passed; 15 files, zero changes |
| `dart analyze` | Passed; no issues |
| `dart test` | Passed; 60 tests (23 existing, 34 collection integration, 3 canonical encoding) |
| `dart run example/care_walkthrough.dart` | Passed; earlier current completion rejected, explicit past care leaves October 27 check and October 20 latest care unchanged |
| `dart run example/guarded_save_walkthrough.dart` | Passed; simulated lost reply resolves original plant, retry replays, exactly one plant/one event/zero drafts |
| `python docs/scripts/check_gitlink.py --root . --docs-path docs` | Passed; clean mounted submodule at unchanged indexed pin |
| `python docs/scripts/check_consumer.py --root . --mount docs` | Passed; exact committed pin and ready development-only review/input identity |
| `python docs/scripts/check_all.py --root docs` | Passed; 8/8 checks, 268 tooling tests in 45.942 seconds |
| `git diff --check` | Passed |

The Python commands used the existing docs-tooling virtual environment. Docs
checks verify the documentation inputs, not implementation conformance. No
native/Flutter/device/store tests were run; no such implementation is claimed.
Changes from this continuation are local and uncommitted; no remote push made.

Self-review only for this single-repository slice; no independent agent review
claimed. Review covered receipt-before-stale ordering, immutable raw inputs and
snapshots, same-ID retries, session/date/access/generation guards, collection and
draft revision separation, transaction fault boundaries, preservation of current
history, canonical hashing and absence of changes to accepted docs. Review found
and fixed the minimum signed integer absolute-value edge in canonical number
validation, with a regression assertion. Initial test harness failures (an import
name collision and missing throws matchers) were corrected before results below.

## Next step

**Historical next step:** continued in the
[schedule/lifecycle delivery](lifecycle-core-2026-10-31.md). The verification above
remains the evidence for the prior slice.

Continue the reviewed fake core with interval/override and lifecycle commands,
routine-change audit, then Today/bulk/Undo and catalog-backed editor integration.
Native durability, full Flutter template dependency resolution, device/store
verification and rendered Figma/UI implementation remain separate gates. The
Figma reference remains recorded in the first handoff; no design was changed.
