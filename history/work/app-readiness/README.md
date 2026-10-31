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

The latest catalog delivery and remaining product boundaries are recorded in the
final section below. Continue the next selected feature through design/review,
implementation and actual client verification. Preserve durable data and all
accepted requirements. Device/store work and public release remain separate gates;
no new permission to keep building is needed.

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

## Shared Dart/Swift command codec — 2026-10-31

**Author:** Codex (AI assistant).
**Date:** 2026-10-31 (Asia/Jakarta).

Final authoritative docs pin:
`7821cdff8187363ac3676df09dbb242001ab3ba4`, published before adoption in
`a22a780`. Store preparation was published/adopted at `3776eea`; the first codec
review at `714d0a1` is superseded by the raw-draft correction. All 18 accepted
requirement files and existing decision records remain byte-identical to the
prior `512bfa8` baseline. Work supports REQ-006/007/008/009 retry/draft integrity;
configuration preparation preserves REQ-014 and the existing REQ-018 UI checks.
No full requirement or public-release completion is claimed.

Implemented a module-internal native typed canonical encoder/SHA-256 using OS
CryptoKit, matching the existing Dart command wrapper. Dart now enforces the
reviewed 4 MiB encoded-byte and 64-container limits without changing valid hashes.
One shared JSON resource contains 20 independently computed Python vectors,
executed by both Dart and Swift; regenerating it is byte-identical with SHA-256
`8ed0db64906f279c9a80567d6af991731aa251011e278b005b66f31c84ec11d9`.
Original SavePlant hash remains unchanged. Arrays/order/ASCII keys, Unicode,
escaping, integer extremes and exact size/depth limits are verified.

The initial full core run caught a real contract regression: 109 passed and the
existing raw-draft test failed when isolated UTF-16 units were rejected during
hashing. Feature work paused for docs review. The corrected native `.utf16` case
represents a logical string, combines valid pairs and escapes isolated units
losslessly; it never hashes the units as an array. Dart's existing raw JSON
behavior and original regression remain unchanged. Final Text validation still
rejects invalid saved content. Future raw bridge, escaped JSON storage and backup
owners now consistently specify lossless recovery; none is claimed implemented
by the codec. Independent review also checked the new synthetic backup fixture's
exact bytes/hash and raw units, preserving original fixtures.

Actual final verification:

- Core analyzer passed and **110 core tests passed**, including unchanged
  acknowledged-invalid-draft preservation and the independent SavePlant vector.
- **26 Swift tests passed on macOS**, comprising 19 SQLite and 7 codec tests.
  Warnings-as-errors build passed. The same **26 tests passed on iPhone16/iOS18.3
  simulator**, using Xcode16.2/SDK18.2 and iOS18 deployment target.
- **22 Flutter unit/widget tests passed**. Final Flutter analyzer passed (5.4s);
  changed Dart source/tests passed format checks. No dependency version or
  generated router/DI/Freezed output changed.
- One earlier Flutter run passed 20 and failed the lifecycle helper at its first
  Add Plant lookup. Independent reproduction proved a cached illustration put
  the button outside the lazy list's built region (0 matches before scrolling,
  1 after). The helper now scrolls before selecting `.last`. A deterministic
  precached-image regression opens the actual form and independently passes;
  the full corrected Flutter suite passes. No app behavior was weakened.
- Separate AI reviewer independently passed 8 Dart codec tests plus the unchanged
  raw-draft test, all 7 Swift codec tests and all 20 regenerated vectors. Scoped
  codec and test-helper findings are closed; native bridge/full app are excluded.
- Corrected docs aggregate and final mounted aggregate each passed **8/8**,
  including **268 tooling tests**. Final committed consumer handoff passed.
  Final diff review excludes credentials, source imports and generated build data.

User's latest direction remains simulator first, with physical device details
deferred and access confirmed. Store preparation is available in the pinned
`technical/store-release-preparation.md` and `technical/release/app-store-candidate.json`:
proposed `com.plabs.verdi` / `com.plabs.verdi.pro.lifetime`, unregistered and not
consumed at runtime. Real account IDs, URLs, agreement status, territories and
live price remain unset; no account/product or public release was created.

Next implementation work is the reviewed product schema/registered command plans,
typed Pigeon/service-isolate connection and durable native guard/receipt recovery.
Then connect the Flutter repository and execute restart/interruption tests before
personal data. Catalog, media/journal/backup, notifications, StoreKit, admin and
physical/current-toolchain release evidence also remain. The app is a tested
synthetic preview, not a release-ready personal-data app.

## Durable draft repository integration — 2026-10-31

**Author:** Codex (AI assistant).
**Date:** 2026-10-31 (Asia/Jakarta).

Current authoritative docs pin is
`0bb0ff89df8529b1d7736057e0107b3a76a56d18`. The original boundary was published
at `89af1c7` and adopted in `999b973`; the simulator protection refinement was
published at `0bb0ff8` and adopted in `c5f7cfa` before its implementation. Baseline
app `2d3bfdf` and all existing core/presentation work are preserved. Accepted
requirement/decision diff from docs `7821cdf` to the current pin is empty.
REQ-006 raw-input/retry behavior is the bounded supported scope; related
REQ-007/008/009/014/015/018 behavior is preserved, not newly declared delivered.
REQ-019 remains proposed. No whole requirement or public-release gate is closed.

Implemented an actual native `DraftRepository` and lossless canonical JSON token
reader, generated Pigeon 29.0.11 Dart/Swift messages, a DEBUG-only Runner host and
one serial Dart service isolate. A separate `VDRF` installation-local development
schema stores add-draft rows, immutable frozen commands, successful receipts and
command-ID/hash tombstones. Draft+receipt+raw-body cleanup commit atomically;
replay precedes stale guards. Acknowledged raw NUL/unpaired UTF16, null seed and
duplicate draft routine rows survive SQLite and generated bridge round trips.
No Foundation raw-string repair, second Dart database, JSON collection dump or
silent reset is used. The exact 1 MiB payload boundary includes escaped bytes.

**This is an isolated disposable integration harness, not the full customer
CollectionRepository.** The existing app UI still uses `MemoryCollectionRepository`.
Native draft integration does not yet persist plants, care, history, media,
entitlements or Undo. It must not be partially registered behind that UI. The
harness's open establishes a session; its caller explicitly lists pending
metadata, fetches one bounded body, resolves and retries/abandons the original
operation before new edits. It grants no full runtime-ready capability.

Review/fix evidence:

- Separate reviewer `core_readiness_review` caught unbounded pending-body pages
  and premature rejection of duplicate raw routine rows in design. Metadata-only
  pages and single bounded body fetch preserve the domain's raw-draft behavior.
- Review caught a genuinely missing platform reply hanging a live service. Every
  call now has a 30-second deadline; terminal transport failure settles pending
  mutations as unknown and reads unavailable, closes ports and permits reopening
  for same-ID receipt recovery. A live receiver that never replies is tested.
- The first iOS run failed eight draft startup cases. A focused diagnostic proved
  simulator setAttributes succeeds but protectionKey read-back is nil. Scope
  returned to docs before implementation: simulator/macOS explicitly report
  fileProtectionVerified=false; compile-time device code still checks the exact
  class on directory, marker, DB and existing WAL/SHM. Setter errors and wrong
  non-null classes reject. Physical first-unlock evidence remains absent.
- The first client build exposed a missing public codec export (fixed without
  algorithm changes). The subsequent channel failure was independently traced to
  Runner Debug lacking Swift DEBUG: the C/Objective-C definition was insufficient.
  Runner Debug now explicitly defines inherited DEBUG; actual Release settings
  exclude it, and native registration stays guarded. Temporary diagnostics removed.
- A first separate-launch attempt was invalid because the pinned Flutter test
  runner uninstalls integration apps by default. Repeated with --no-uninstall.
  Freeze left the native DB/worker open, then the test runner stopped the app;
  simctl confirmed no process remained. Read-only inspection showed 0 drafts,
  1 pending command, 0 receipts. A separately launched recover test discovered
  that frozen body and committed its original ID once. After exit: 1 draft,
  0 pending commands, 1 receipt, revision 1. This proves restart after freeze,
  not process death during an SQLite transaction or physical power-loss behavior.

Actual verification on Flutter 3.47.8/Dart 3.13.7, Xcode16.2/SDK18.2,
iPhone16 simulator/iOS18.3:

- 110 core tests and core analyzer passed; existing raw-input regression unchanged.
- 38 native tests passed on macOS and 38 on iOS simulator; Swift build with
  warnings-as-errors passed. Includes 19 foundation, 7 codec and 12 draft/parser
  cases: stale/competing writes, rollback, unknown commit/reopen, hash reuse,
  abandon/body scrub, session invalidation, corrupt/missing initialized storage,
  metadata paging and exact byte limits.
- 23 Flutter unit/widget tests passed. Following final transport cleanup, the
  nonreplying-transport test passed again; Flutter analyzer reports no issues.
- Actual generated bridge/service-isolate test passed; separate freeze and
  recover launches each passed. Final `flutter test integration_test --no-uninstall`
  passed both actual iOS entrypoints (2/2): unchanged synthetic UI add/save/edit/
  archive and the generated native draft/retry path. The latter also matches its
  payload hash to the existing core SaveDraft model.
- Both generated outputs match the pinned Pigeon + Dart formatter pipeline. An
  isolated negative probe changed a generated output and the check rejected it.
  Raw Pigeon trailing whitespace was corrected through this reproducible
  generation pipeline, not hand-edited. Tooling lock is separate
  from the app's existing Freezed/router/DI dependency solve. The generation
  check writes only temporary output; ConfigurePigeon annotations override CLI
  output flags in this pinned generator.
- Both scoped docs aggregates and the final mounted docs aggregate passed 8/8,
  each including 268 tooling tests. Final committed consumer/gitlink checks
  passed. Independent
  semantic/code rechecks closed the scoped findings. No physical-device, StoreKit,
  notification, backup, full native collection or release test is claimed.

Logs retained locally outside Git: `/tmp/verdi-draft-native-final.log`,
`/tmp/verdi-draft-native-ios-final.log`, `/tmp/verdi-draft-native-build.log`,
`/tmp/verdi-draft-core-test.log`, `/tmp/verdi-draft-flutter-test-final.log`,
`/tmp/verdi-draft-flutter-analyze-final.log`, `/tmp/verdi-draft-transport-final.log`,
`/tmp/verdi-draft-process-freeze.log`, `/tmp/verdi-draft-process-recover.log` and
`/tmp/verdi-draft-all-integration-final.log`.

Next: review the complete custom-core physical schema and registered plans,
extract the pure planner from memory-store authority, then integrate all currently
exposed collection reads/mutations together with native clocks/access guards,
receipts, outbox and Undo. Complete that coherent repository before changing the
main UI's registration. Full product features, physical/current submission
host/store configuration and release evidence remain open. Simulator-first and
prepared-but-unregistered store configuration remain the user's current choices.


## Durable custom-core main UI delivery — 2026-10-31

**Author:** Codex (AI assistant).
**Date:** 2026-10-31 (Asia/Jakarta).

Implementation contract: published docs
`91d61be2201811e19d538e7c720a0be694e55c52`, adopted before code in app
`2c4da6d`. App baseline `f344a996b20b068313d41fbcbd93db8790ff5bd6`, the
isolated draft harness and existing tests are preserved. This delivers the
currently exposed custom-core portion of REQ-006/007/008/009 with related
REQ-014 Free-cap, REQ-015 local-storage and REQ-018 recovery presentation checks.
All 18 accepted requirement files and decision records remain byte-identical;
REQ-019 remains proposed. No complete requirement or release gate is closed.

The main development entry now opens native `custom_core_v1` storage, resolves
unfinished operations and hydrates current rows before showing the workspace.
It no longer registers the memory repository. SQLite persists custom plants,
all five standard routine kinds, pending heads, original care events, correction/
void/restore audit, schedule changes and raw add/edit drafts. Native writes
commit rows, revisions, receipts, outbox and frozen-body cleanup together.
Stored hydration never replays seed commands. The memory store remains an
explicit test environment and a disposable planner projection, not durability
authority. Startup failure retains files and offers Retry without reset/fallback.

The generated Pigeon API accepts bounded canonical envelopes through one serial
Dart service isolate. Native code owns clock/zone, compiled statement registry,
revision/identity/count/draft-set/Free-cap guards, preview grants and eight-second
acknowledgement-bound Undo. Same-ID receipt lookup precedes stale guards and
local preview lookup. Unknown outcomes reopen the native owner before recovery;
queued later editor text survives retry. Restart presents unfinished actions for
explicit retry/cancel, with fresh review for actions requiring confirmation.

Independent reviewer `core_readiness_review` inspected design and source,
reproduced hostile-plan/Unicode issues, reread fixes and checked final retry/UI
logs. Final bounded review found no remaining blocking defect. Corrections include:

- Before-row hashes bound escaped raw draft update size; exact delete counts and
  owned edit-draft set include the empty set. Same-instant changes still bind
  native timestamps. Native command-specific scopes reject field smuggling.
- Strict raw-draft structure validation precedes freeze, while invalid draft
  strings/null seeds/duplicate rows remain lossless. Native comparison is byte
  exact; whitespace matches Dart, including FEFF. Final Text rejects NUL under
  the existing contract, without rejecting raw draft NUL.
- Unknown outcomes close poisoned sessions. Sticky submission/preparation IDs
  and receipt-first confirmation preserve one operation across reconnect.
  A freeze that was never acknowledged is not incorrectly abandoned.
- Deleting one plant preserves unrelated Undo; slow native readback subtracts
  elapsed time from the visible offer. Replays/restarts grant no new Undo.
- A recovery dialog initially left a loading animation active behind it; the
  busy state now pauses during confirmation. UI tests now scroll lazy lists and
  settle scroll animation before accessing controls at large text sizes.

Executed on Flutter 3.47.8/Dart 3.13.7, macOS14.6, Xcode16.2/SDK18.2 and
iPhone16 simulator/iOS18.3, using the repository lockfiles:

- Core: `dart analyze`, format check and `dart test`: 116 tests passed. New
  tests verify all 21 wire commands over 28 shared transitions, direct hydration,
  corrupt-row rejection, raw UTF16, large escaped drafts and native-fixture drift.
- Native: `swift test`: 51 tests passed; `swift build -Xswiftc -warnings-as-errors`
  passed. `xcodebuild -scheme VerdiNative -destination
  'platform=iOS Simulator,name=iPhone 16,OS=18.3' -derivedDataPath
  /tmp/verdi-native-ios-build test`: the same 51 tests passed. Includes actual
  SQLite reopen/constraints/transaction recovery, hostile plans, exact deletion
  guards, active cap, all-command row-hash replay and Undo deadline boundaries.
- Flutter: format and `flutter analyze` passed; final `flutter test` passed
  all 24 tests. The new startup failure test
  proves retained recovery and reachable Retry at 320 px and 320% text.
- Main UI: `flutter test integration_test/durable_core_test.dart -d DEVICE_ID
  --no-uninstall --dart-define=VERDI_CORE_PHASE=seed`, then the same command with
  `recover`: each passed 1/1 in separate retained-installation processes. Actual
  UI add, complete, past care, correction, void, interval, archive and restore
  were followed by restarted history/head reads, pending-action confirmation and
  recovered draft editing. No uninstall/reset was used.
- Actual native retry: `flutter test integration_test/native_retry_test.dart
  -d DEVICE_ID --no-uninstall`: passed 1/1. Exercises loss before freeze, BUSY
  before commit with later keystrokes, lost committed reply plus unavailable
  receipt, confirmation replay after service restart and delayed Undo readback.
  Faults here are injected at the service boundary around real native writes;
  Swift tests separately inject native transaction faults.
- `DART_BIN=PINNED_DART python3 tooling/pigeon/check_generation.py` passed for
  Dart and Swift output. Localized and DI generated output is retained.
- Preserved integration regression command: `flutter test
  integration_test/collection_flow_test.dart integration_test/durable_draft_test.dart
  -d DEVICE_ID --no-uninstall`: both passed (2/2). This retains the explicit memory
  UI scenario and separate native draft namespace. `git diff --check` passed;
  reviewed files contain no
  imported source originals, credentials or generated build directories.

Local logs: `/tmp/verdi-core-final-tests.log`, `/tmp/verdi-core-final-analyze.log`,
`/tmp/verdi-core-native-final.log`, `/tmp/verdi-core-native-ios-final.log`,
`/tmp/verdi-core-native-warnings.log`, `/tmp/verdi-flutter-final-analyze.log`,
`/tmp/verdi-flutter-final-tests.log`, `/tmp/verdi-core-ui-seed-final.log`,
`/tmp/verdi-core-ui-recover-final2.log`, `/tmp/verdi-core-native-retry.log` and
`/tmp/verdi-core-preserved-integration.log`. They are local execution evidence,
not a portable archived test report.

Remaining: bundled species/catalog and species-change suggestions, media/journal,
backup and generation replacement, notification delivery, StoreKit entitlements,
admin and full product accessibility/performance verification. Simulator protection
is explicitly unverified. Physical protection/first-unlock, real interruption,
current submission toolchain and store/release evidence remain open. The DEBUG
entry still refuses release mode; prepared store IDs remain unregistered.


## Verified delivery docs publication and pin — 2026-10-31

**Author:** Codex (AI assistant).
**Date:** 2026-10-31 (Asia/Jakarta).

Implementation `8a6d6f833def10721d11f7ebb46f036a4ea1506f` is published on
`codex/flutter-core-2026-10-30`. The independently reviewed delivery coverage,
current handoff and repository map are published in docs
`fb55ed4f044d140be368b21564bc62dca1b85cb7` on
`codex/verdi-app-readiness-2026-10-31`; this change advances the app gitlink to
that exact published revision. The implementation contract remains
`91d61be2201811e19d538e7c720a0be694e55c52`; the new docs commit changes evidence
and current observations, not technical behavior or accepted requirements.

Final docs aggregate passed 8/8, including 268 tooling tests, on the refreshed
input manifest (`/tmp/verdi-core-docs-verified.log`). One intermediate run caught
a stale generated scope after a regeneration command used a Python environment
without PyYAML; regeneration with the established docs virtualenv and a complete
aggregate rerun passed. No gate was relaxed. Requirement/decision paths have no
diff from the prior accepted baseline. Separate reviewer `core_readiness_review`
rechecked final evidence, partial coverage and remaining boundaries, and closed
with no blocking mismatch. App code/tests are unchanged from the verified
implementation commit. Staged and committed consumer/gitlink checks accompany
this pin update; public release and remaining feature/device/store work stay open.

## Bundled catalog and species integration — 2026-10-31

**Author:** Codex (AI assistant).
**Date:** 2026-10-31 (Asia/Jakarta).

Implementation contract: docs `63b6062da0d1d868617f0b90aa26054ca2e0adcd`,
published before adoption in app `574a275`. Affected REQ-001–006/016, preserving
related REQ-007/008/009/014/015/018 behavior. Accepted requirement and decision
records are unchanged; REQ-019 stays proposed. This extends the existing durable
main Flutter UI, not the product's release status.

The actual bundle has the fixed 24 Popular species, reviewed against primary
NC State/RHS sources, with authored summaries and explicit source/content/rights
records. The reviewer inspected all 22 NC State captures and independently opened
the two RHS profiles after correcting insufficient excerpts. Four qualified
active-growth fertilizer intervals are supplied; no fixed watering advice was
invented. Difficulty and unsupported animal-specific toxicity remain Unknown.
The generic Figma illustration uses the user's confirmed rights; original source
captures remain ignored, and no third-party article photos are bundled.

The main picker now supports immediate whole-inventory search, pinned Unicode15.1
case folding/whitespace, exact phrase/rank/tie rules, Popular, distinct information
and selection actions, source-attributed guides, generic-art fallback and custom
entry. Selection must be durably acknowledged before advancing. Restart restores
its species/name and raw draft. Existing routines require explicit keep/apply when
species changes; original suggestion snapshots remain immutable and applied ones
are added atomically with the plant/routines/draft/receipt. Unknown last care does
not invent history or change its chosen first check merely to apply an interval.

Native schema v2 adds catalog/selection/snapshot tables to the same permanent
`custom_core_v1` database. It retains every original table and stable identity.
Strict bounded package validation, lossless duplicate-key rejection, fixed asset
paths and decoded PNG validation precede atomic install. Failed updates retain
the last good package. Malformed catalog metadata cannot block custom saves/care;
new selections revalidate entry review, lifecycle, version, exact projection and
embedded ID. Unchanged stored selections retain their offline edit exception.

Independent reviewer `core_readiness_review` inspected design, content and actual
code. Fixes include native schedule-transition guards for apply, catalog failure
isolation, retained manifest validation, qualified toxicity downgrade, entry-ID
binding, required result labels/attributions and small-screen picker layout.
Actual UI testing found that an unknown-seed apply with unchanged next-check row
was rejected by native result validation. The fix accepts only the exact existing
head ID/revision for authorized changed routines. A shared regression covers it,
and the originally interrupted save succeeded with its retained command ID.
No failing command or user data was erased to get a passing result.

Executed on Flutter3.47.8/Dart3.13.7, macOS14.6, Xcode16.2/SDK18.2 and iPhone16 /
iPhone SE3 simulators on iOS18.3:

- Core analyzer and all **122 tests** passed. Flutter analyzer and **29 unit/widget
  tests** passed, including acknowledged-selection failure/retry, stale selection,
  search/info/query preservation/custom prefill and 320px/320% text with a 300px
  keyboard. Format checks passed. DI/Freezed/localization generation and Pigeon
  Dart/Swift reproduction passed; catalog/Unicode generation reproduced exact
  bytes and the native fixture bundle matches the actual app bundle.
- Native `swift test` and iOS `xcodebuild ... test`: **63 tests passed on each**.
  Covers real v1 migration and rollback/lost-reply recovery, retained v1 frozen
  SavePlant/DeletePlant commands, hostile apply plans, known/unknown-seed shared
  replay/reopen, immutable suggestions, package/retained corruption rejection,
  catalog update preservation and all preserved core tests.
- Actual retained iPhone16 installation upgraded v1→v2 without uninstall/reset.
  All 12 original tables retained identical row counts/hashes and the same dataset
  identity; the new catalog contains 24 entries. This includes 56 intents, 56
  receipts and 101 reservations. The `upgrade` UI phase passed 1/1.
- Main `catalog_flow_test.dart` seed/recover each passed **1/1** in separate retained
  processes. UI search/info, add, explicit species apply, care, archive/restore and
  acknowledged draft all survive restart. `resumeApply` additionally recovered
  the original interrupted save 1/1. Test-only fixes use the actual Cancel/Discard
  changes labels, navigate the Archived collection and clear the live test
  binding's cached editable after native focus changes; product assertions stay.

The preserved main custom core seed/recover passed **1/1 each** on iPhone SE3,
including custom entry through the bundled picker, full care/history/lifecycle,
pending-action recovery and draft recovery. The native retry integration passed
**1/1** and the memory collection plus isolated native draft regressions passed
**2/2**. The custom test now scrolls the picker list rather than the TextField and
waits for the editor after native acknowledgement, including when the progress
indicator is offscreen. Assertions remain intact. Native warnings-as-errors and
both core walkthroughs passed. The independent reviewer closed the last embedded-ID
finding after reading the final native and catalog recovery logs.

Local logs: `/tmp/verdi-catalog-core-final.log`,
`/tmp/verdi-catalog-widget-final.log`, `/tmp/verdi-catalog-analyze-final.log`,
`/tmp/verdi-catalog-swift-final.log`, `/tmp/verdi-catalog-native-ios-final.log`,
`/tmp/verdi-catalog-upgrade-ui.log`, `/tmp/verdi-catalog-seed-ui.log`,
`/tmp/verdi-catalog-recover-ui.log`, `/tmp/verdi-catalog-apply-recovery.log` and
`/tmp/verdi-catalog-simulator-migration-result.json`. These are local execution
records, not a portable archived report. Preserved-flow logs are
`/tmp/verdi-catalog-old-core-seed.log`, `/tmp/verdi-catalog-old-core-recover.log`,
`/tmp/verdi-catalog-old-retry.log` and `/tmp/verdi-catalog-preserved.log`.

Remaining: broader launch inventory/species artwork, physical offline/screen-reader
and full accessibility/performance checks; media/journal, backup/generation
replacement, notifications, StoreKit and admin. Physical protection/first-unlock,
interruption and actual store/release checks remain open. The development entry
still refuses release mode; candidate store IDs remain unregistered.

Final normal development build (`flutter build ios --simulator --debug -t
lib/main_development.dart`) passed, then `flutter run --no-pub -t
lib/main_development.dart -d DEVICE_ID` opened the main workspace on the retained
iPhone16 installation. The rendered Today screen was inspected with both the
prior custom fixture and new catalog fixture present; no data reset was used.
Logs: `/tmp/verdi-catalog-ios-build-final.log`, `/tmp/verdi-catalog-main-run.log`;
local screenshot `/tmp/verdi-catalog-main-preview.png`. Final full Dart analyzer
and format recheck passed after the test-navigation changes. Independent evidence
review also matched the preserved integration results to partial coverage.

## Catalog delivery publication and docs pin — 2026-10-31

**Author:** Codex (AI assistant). **Date:** 2026-10-31 (Asia/Jakarta).

Implementation `176183887d79a300204c145c1e721135395b0662` is published on
`codex/flutter-core-2026-10-30`. Verified delivery, partial coverage and current
repository observations are published in docs
`1737da78dfeb76d995ae399cb701f0aa50ad94e2` on
`codex/verdi-app-readiness-2026-10-31`; this pin advances to that exact published
revision. The implementation contract remains
`63b6062da0d1d868617f0b90aa26054ca2e0adcd`. No accepted requirement or decision
bytes changed. The docs aggregate passed **8/8**, including **268 tooling tests**
(`/tmp/verdi-catalog-docs-final.log`). Independent source/evidence review found no
remaining blocking defect for the bounded catalog slice. Staged/committed
consumer checks accompany this pin; full feature/device/store release gates remain.

Mounted docs verification also passed **8/8** with **268 tooling tests**
(`/tmp/verdi-catalog-mounted-docs-final.log`); staged consumer and clean-gitlink
checks passed at `1737da78dfeb76d995ae399cb701f0aa50ad94e2`. Code and tests are
unchanged from the published, verified implementation commit.
