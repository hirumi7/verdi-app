# Verdi application readiness

**Author:** Codex (AI assistant). **Updated:** 2026-10-31 (Asia/Jakarta).

## Outcome and authority

Continue docs → build → verify → test → review → fix until the accepted application
is ready. Preserve all accepted decisions and inherited work. User confirms rights
to the PLabs templates/imported artwork and access to a physical iPhone and Apple
Developer account. Actual device/store execution remains unverified.

## Baseline and current scope

App baseline `bd7ef9fd0be978a7f6b336aecaffd1a3fa372aec`; exact docs pin
`b6519e8a6946d4767b75467cd48925e0c8dcc046`.
Inherited uncommitted guarded-save and lifecycle work is preserved, with its
[77-test evidence](../lifecycle-core-2026-10-31.md). This is the current handoff for
the broader task; earlier handoffs remain historical evidence.

The selected docs review permits the synthetic pure-Dart core. The current loop
implements the remaining REQ-007/008/009 bulk and Undo/read contracts in
`technical/local-data-and-care.md` sections 6–7. Native Flutter scope still requires
its own review and published docs pin. No production persistence or release claim.

## Verification plan

- Bulk: explicit compatible targets, all-or-none stale/failure handling, frozen
  IDs, receipt replay, unchanged unselected routines.
- Undo: 7,999/8,000 ms boundary, no restart/replay renewal, all-member revision
  guards, retained audit, rollback and lost-reply recovery.
- Reads: full-set counts, keyset pagination, stale revision/date/query rejection,
  archived history, actual-care-only Done today, no health inference.
- Run package analysis/tests, review the diff, then update evidence here.

## Next action

Complete the reviewed core and its tests while preparing the separate native/UI
scope review. Preserve the new user answers in the docs working branch
`codex/verdi-app-readiness-2026-10-31` before publication/adoption.

## Core loop evidence — 2026-10-31

Implemented same-kind explicit bulk care, value-only session Undo with all-member
revision guards, and typed collection/detail/history/Today/reminder reads. These
remain synthetic memory operations; native storage and OS effects are unimplemented.

Self-review fixed monotonic rewind allowing an observed expiry to become eligible
again, and kept head revisions conditional on actual head-value changes.
Independent AI reviewer `core_readiness_review` found missing affected-member IDs
on bulk date failures and repeated full routine sorting per Plants row. Both were
fixed. The reviewer also found the original expiry test only checked entry-time
expiry; a replacement clock crosses 7,999→8,000 ms at the publication guard.
An initial incorrect four-sample expectation failed; code inspection showed the
existing-intent path takes three samples, and the corrected test passes.

Final core verification: locked pub get, analyzer, all **102 tests**, both examples
and diff checks passed. Format check covered 20 Dart files. The independent
reviewer rechecked the fixes and **25 targeted tests**, closing both findings;
the final receipt-absence assertion also passed in the targeted recheck. Native
and rendered UI checks have not run for this core loop.
