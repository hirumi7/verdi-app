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

The core loop implemented the remaining REQ-007/008/009 standard bulk and Undo/read
contracts in `technical/local-data-and-care.md` sections 6–7. The next selected
docs pin is `47ff07b4b81e57950dfb86863f4afa5b0f63e7b5`, published on
`codex/verdi-app-readiness-2026-10-31`; it adds a separately reviewed synthetic
Flutter presentation scope. No production persistence or release claim.

## Verification plan

- Bulk: explicit compatible targets, all-or-none stale/failure handling, frozen
  IDs, receipt replay, unchanged unselected routines.
- Undo: 7,999/8,000 ms boundary, no restart/replay renewal, all-member revision
  guards, retained audit, rollback and lost-reply recovery.
- Reads: full-set counts, keyset pagination, stale revision/date/query rejection,
  archived history, actual-care-only Done today, no health inference.
- Run package analysis/tests, review the diff, then update evidence here.

## Next action

Continue the docs-first native-storage design/review, then implement durable
persistence and bridge integration. Preserve the verified synthetic UI and all
accepted requirements. Real-device/store configuration and full release remain
separate gates; no new permission to keep building is needed.

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

## Flutter preparation and docs adoption

Core checkpoint commit `39de0d6f1dc076d268db909593ce0a31ff11a821` preserves all
inherited guarded-save/lifecycle work plus the reviewed bulk/Undo/read additions.
Docs commit `47ff07b4b81e57950dfb86863f4afa5b0f63e7b5` was pushed before changing
the app gitlink. Its 18 accepted requirement files are byte-identical to the old
pin. User rights/access confirmations and exact remaining limits are recorded.

Flutter 3.47.8 / Dart 3.13.7 is installed in the isolated user runtime cache,
verified against official archive SHA-256. The selected template checkout at
`ea035cccdd6aa5c0a6cf243b7ff2ca16e94a4d26` passed dependency solve and analyzer
after exactly four SDK-required lock updates (recorded in the docs review).
Figma foundations, Today, Plants, Add details and empty Today were inspected.
The iPhone 16 / iOS 18.3 simulator booted; no app build or device test is claimed.

## Presentation implementation in progress

The app pin was committed in `f77b32e`; committed consumer verification passed,
and mounted docs aggregate passed 8/8 with 268 tooling tests (112.638 seconds).
The Flutter template iOS runner and relevant local rules were adapted in
`apps/mobile`, alongside theme/localizations, generated DI/router/Freezed state,
temporary collection adapter, draft/confirmation controllers and initial screens.
The development entry refuses release mode. Public native/storage/store readiness
is not implied by these files.

Actual code generation exposed analyzer 7.7.1 incompatibility with the SDK despite
the old template dependency/analyzer passes. Functional UI work paused for the
docs-first correction. Candidate generator versions are recorded in the separate
docs working branch. Actual generation and a fresh-cache comparison of six
generated Dart files passed; analyzer now includes generated files and passes.
The generated-wiring custom draft → preview → save test passes. Generator
correction docs checks/publication/adoption remain pending before feature work.

Known UI follow-up work (not a completion claim): robust pending draft recovery
when raw fields change during an uncertain save; truthful debounce/acknowledgement
status; unselected seed-branch draft preservation; explicit preview dates/counts;
remaining schedule/history controls and pagination; lifecycle destinations;
layout/contrast/locale/motion tests, simulator visual review and failure-path tests.
Native production adapters and excluded full-product features remain outstanding.

## Synthetic Flutter milestone and correction closure — 2026-10-31

Current docs pin: `512bfa816085c9c211b7054229f150cf4a4d2725`, published before
adoption in app commit `12ec9d6`. Requirements affected: REQ-006/007/008/009 and
applicable REQ-018. All accepted docs bytes remain unchanged. The app remains
explicitly development-only, temporary synthetic state with UTC test dates.

Implemented template-derived DI/router/Cubits, Figma light/dark tokens and generic
art, Today/Plants/detail/history, all five standard routine seeds, interval and
state controls, raw draft recovery, guarded confirmation, bulk/Undo, archive/
restore/delete and paginated collection/Today/history. Full product coverage is
not inferred; excluded catalog/media/backup/store/OS/native/admin work remains.

Independent AI reviewer `core_readiness_review` found and rechecked fixes for:
exact unresolved draft payload/version reuse; read-back binding to its receipt;
explicit conflict re-review; consumed/replaced draft local discard; persistent
discard failures and lost-reply recovery; successful-edit/discard navigation;
stale/missing preview return to review; routine identity/count in previews; and
unselected seed canonicalization. The null seed cannot hide an unhashable date or
bypass the draft size bound. The reviewer independently ran **12 recovery tests**
and closed the scoped findings. This is not full-product certification.

Executed verification on Flutter 3.47.8 / Dart 3.13.7 and Xcode 16.2:

- App locked dependency resolution, localization generation and actual
  build_runner generation passed. The earlier fresh-cache comparison of all six
  generated outputs remains recorded in the correction review. Later SDK
  integration_test tooling adds seven test dependencies with no overrides.
- Final Flutter analyzer passed, and **21 unit/widget tests passed**, including
  full lifecycle routing, explicit seed, stale confirmation and failed-save retry,
  bulk Undo, revision races, pagination, en-US/en-GB dates and measured light/dark
  text/control contrast. Format checks passed. The final save-review identity
  caption was added after that run; its focused UI recheck is recorded below.
- Large-text verification uses 375×667 logical pixels, 320% text, Reduce Motion,
  and an actual 300-pixel keyboard inset. It initially exposed a 29-pixel overflow;
  letting nested page scaffolds own keyboard avoidance fixed both themes.
- Core locked dependencies, analyzer, **105 tests** and both walkthroughs passed.
- iPhone 16 / iOS 18.3 simulator: native build passed; native integration exercised
  actual add → draft → save → edit → archive and repository reads. Final native
  rerun passed (Xcode build 54.3 seconds; one test plus teardown, 13 seconds).
  The native runner still uses the synthetic repository, not SQLite durability.
- Mounted docs aggregate passed **8/8** with **268 tooling tests**; committed
  consumer/pin verification passed. Accepted requirement files match prior pin.

Failures were corrected, not suppressed: SDK generator AST incompatibility;
missing inherited CocoaPods file lists; CocoaPods non-UTF-8 process locale;
router missing Key import; form element identity after inserting save status;
focus/keyboard layout; and a context-lifetime lint. Flutter generated Swift
Package Manager integration for its test plugin; its warning about the retained
CocoaPods Flutter dependency is not a failed build. Native UI automation through
the desktop connector timed out, so native verification used the integration-test
runner and a separately inspected simulator screenshot instead.

Remaining release gates include actual durable native database/receipt/bridge and
process-death proofs; real catalog/content validation; photos/journal/backup;
StoreKit/reminders/settings; production branding/signing/store setup; physical
iPhone/VoiceOver and compatibility tests; current submission SDK/host; admin
implementation within accepted scope. User-confirmed rights and device/account
access stay confirmed. Exact device model/OS and existing app/product identifiers
are still pending questions. No public release, payment setup or hardware/host
purchase has occurred.

Final focused recheck: **9 generated-wiring/presentation tests passed** after the
save-review identity caption and generator-format option. Staged diff checking
caught whitespace emitted by Freezed's default format-off output; enabled its
supported `format: true` build option and regenerated the files, rather than
hand-editing generated source or weakening the check. No business behavior or
dependency version changed. The final analyzer/format/diff recheck follows this
pure formatting correction.

Final staged diff check passed. Flutter analyzer passed again (14.8 seconds),
with 30 app/test/integration Dart files unchanged by the format check. The first
final analyzer invocation was accidentally issued from the repository root and
failed in Flutter's executable-path bootstrap before analysis; the documented
`apps/mobile` invocation succeeded. No failed invocation is counted as a pass.
The native integration rerun and scoped independent review are both complete;
no release-readiness claim is made.


## Native SQLite foundation — 2026-10-31

**Author:** Codex (AI assistant).
**Date:** 2026-10-31 (Asia/Jakarta).

Published docs `7f48c37a90cf6a0f3dcb3409a086d3ede44890cc` before app pin commit
`d4a692f`. Separate AI review cleared the bounded design after preflight ordering,
atomic bootstrap, uncertain-error lifecycle and queue/session/close corrections.
App baseline `4c28d0d42f2f7f2ba1e32d31d8faba3fbbe4fe0b` and all accepted decisions
remain preserved. This infrastructure supports later REQ-006/007/008/009 durable
behavior; no complete requirement or customer-data repository is delivered here.

Implemented `apps/mobile/packages/verdi_native` using Foundation/Dispatch and OS
SQLite3, with no remote dependencies: exclusive bootstrap, read-only preflight,
identity/integrity validation, WAL/FULL/FK readback, typed bound statements, scoped
sessions, serialized whole transactions, autocommit-aware rollback, poisoned-state
recovery, safe diagnostics and explicit close. Compiled synthetic schema version
7001 is test-only. No bridge, product schema, real-data registration or protection
claim is added to the Flutter app.

Actual corrections during verify → test → review → fix:

- Initial native tests failed `SQLITE_CANTOPEN`: Foundation canonicalization still
  rewrote the trusted `/private/var` parent to its symlink alias. A standalone
  SQLite probe confirmed POSIX `realpath` fixes the parent while NOFOLLOW preserves
  leaf rejection. No database-file symlink is followed.
- Failed-bootstrap assertions initially masked an unrelated opening failure.
  Tests now assert exact DDL/validator errors and use separate retained files;
  deleting only a main file while sidecars remain correctly rejects recreation.
- Independent reviewer reproduced a partial-write defect after a callback caught
  SQLite's automatic rollback. Failure-latched sessions and active-transaction
  guards now prevent continuation and prevent successful finish after swallowed
  errors. The independent reproduction reopened with only the original row.

Executed on Swift 6.0.3 (package tools/language 5.10/5), macOS 14.6 and Xcode16.2:

- `swift test`: **17 tests pass**, real OS SQLite 3.43.2. Cases cover reopen,
  preservation, FK/uniqueness and whole-work rollback, actual deferred-FK COMMIT
  failure, bounded BUSY and retry, concurrent operations, close/session lifetime,
  caught automatic rollback and deterministic uncertain-outcome faults.
- `swift build -Xswiftc -warnings-as-errors`: passed, no compiler warnings.
- `xcodebuild -scheme VerdiNative -destination 'platform=iOS Simulator,id=<local iPhone 16>'
  -derivedDataPath /tmp/verdi-native-ios-build test`: **17 tests pass** on iOS18.3,
  with iOS18 deployment target and SDK18.2; OS SQLite3.43.2. Initial failing run
  used the pre-fix bootstrap test; final corrected run passed. Test logs retain
  actual library compile options and settings without user data.
- Independent AI reviewer reran **17 tests**, recompiled the rollback regression
  and found no remaining blocking issue in the bounded package. Review excludes
  product schema, bridge, physical device and release readiness.
- Published docs aggregate and mounted aggregate both pass **8/8**, including
  **268 tooling tests**. Committed consumer handoff passes at the exact pin above;
  accepted requirement and decision diffs are empty.

Close fault injection proves lifecycle control flow, not an actual leaked handle
or disk/power fault. Reopen is not process-death proof. Full product schema,
registered guarded plans, generated Pigeon/service-isolate wiring, native clocks/
receipts/Undo, file protection, recovery-generation handling and interruption
proofs remain before personal data. Flutter retains synthetic temporary state.
Next: docs-first design/review of the product schema and command bridge, then
implement and test those exact contracts. Existing UI/core test evidence above
remains unchanged; no unrelated re-run is counted as new verification.

### Consistent read snapshots and simulator/store follow-up

**Author:** Codex (AI assistant).
**Date:** 2026-10-31 (Asia/Jakarta).

The user directs simulator-first development and says store records are not yet
configured; configuration preparation is authorized. Do not repeat the physical
model question during core work. Available development targets remain iPhone16
and compact SE3/iOS18.3. Physical access stays confirmed, actual release testing
remains outstanding. The docs checkout prepares candidate store identifiers and
metadata without adopting them into runtime or creating account records.

Under the same docs pin, native read callbacks now use a deferred transaction so
all SELECTs share one consistent snapshot, including if another connection
commits meanwhile. An independent reviewer found and rechecked a read-cleanup
error classification issue: uncertain read cleanup now returns unavailable and
requires reopen, never claims an ambiguous new mutation. Writable operations keep
unknownOutcome. Both read regressions independently pass. Final full suites pass
**19 tests on macOS and 19 on iPhone16/iOS18.3 simulator**; the warnings-as-errors
build passes. The runtime contract already required snapshot-consistent reads and
no new commit outcome for reads; this is a conformance correction, not new scope.
