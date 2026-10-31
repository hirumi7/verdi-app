# Verdi native storage

The main Flutter development UI uses `CoreRepository`, the permanent normalized
`custom_core_v1` profile reviewed in docs contract
`63b6062da0d1d868617f0b90aa26054ca2e0adcd` and
[native core owner](../../../../docs/technical/native-core-repository.md).
Schema v2 additively upgrades the same v1 installation and preserves its rows,
dataset, pending bodies and receipts. It persists custom/catalog plants, versioned
selections and original/applied suggestion snapshots, standard routines/heads, original care events,
corrections, schedule audit and raw drafts. Frozen intent/reservation/receipt and
outbox updates share each guarded transaction. Native owns previews, clock,
Free-cap checks and acknowledgement/Undo deadlines. The generated bridge and one
Dart service isolate connect the main UI. Schema mismatch/corruption never resets.

The earlier foundation and isolated draft harness remain separate and tested.
Their historical contracts appear below. This profile does not enable media, backup/import/generation switching, notifications, purchases or release.

The package has no remote dependencies. It links the OS SQLite3 library and uses
one serial Dispatch queue per connection, FULLMUTEX, WAL/FULL, foreign keys and a
2,500 ms busy timeout. Swift tools 5.10 / language mode 5, macOS 14 and iOS 18 are
the package's development build floors; these are not submission-toolchain claims.

The internal API accepts only app-compiled SQL/schema descriptors and native
app-owned file URLs. Existing files receive read-only validation before writable
configuration. Trusted parent paths use POSIX `realpath` because Foundation can
normalize Apple's `/private/var` back to its symlink alias; the leaf is never
resolved and NOFOLLOW rejects a substituted file. New files are exclusive, mode
0600; stale sidecars reject creation. The foundation itself does not select iOS protection; the draft harness below
adds explicit device checks and unverified simulator reporting.

`read` and `transaction` callbacks are synchronous and scoped. A read callback
uses one deferred transaction snapshot across all of its SELECTs. Failed read
cleanup can require reopen but never claims an ambiguous new mutation. Do not block on
another connection, call UI/network code, or dispatch reentrant work back to this
connection. A statement error latches failure even if the callback catches it;
later statements cannot write after an automatic rollback. Known rollback leaves
the connection usable. Uncertain COMMIT/ROLLBACK makes it unavailable until close
and reopen; future command integration must resolve the original receipt.
Explicit close reports failure and retains the handle for retry. Errors contain
typed codes, never SQL, raw paths or user content.

From this package directory:

```sh
swift test
swift build -Xswiftc -warnings-as-errors
xcodebuild -scheme VerdiNative \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3' \
  -derivedDataPath /tmp/verdi-native-ios-build test
```

Foundation tests use a deliberately synthetic schema identity/version 7001. They exercise
real OS SQLite creation, close/reopen, constraints, rollback, lock contention,
concurrent calls and scoped access. Deterministic injected commit/rollback/close
faults test recovery control flow; the deferred foreign-key case fails a real
SQLite COMMIT. These do not prove hardware I/O failure, power loss, OS process
termination, iOS first-unlock/file protection, or Flutter bridge recovery.

Remaining device protection/first-unlock, physical interruption, missing feature
and public-release evidence is tracked in the current delivery handoff. Never
remove the development entry's release guard to imply completion.

## Shared command encoding

The additional codec follows docs pin
`7821cdff8187363ac3676df09dbb242001ab3ba4` and
[command canonicalization](../../../../docs/technical/command-canonicalization.md).
It produces exactly matching bounded JSON/UTF-8/SHA-256 in Swift and Dart, with
one shared resource at `Tests/VerdiNativeTests/Fixtures/canonical-command-v1.json`.
Regenerate it with `python3 tools/generate_command_vectors.py`; the independent
Python standard-library oracle does not import either implementation.

The 20 vectors retain the original SavePlant hash and cover controls, Unicode,
integer bounds, ordering and raw UTF-16. Native `.utf16` is a logical string,
not a canonical array. It combines valid pairs and escapes isolated units without
replacement, preserving acknowledged raw drafts. Final Text validation still
rejects invalid saved names/notes. Size/depth guards include the command wrapper;
the separate raw-draft bound is not relaxed. The codec itself grants no command authority; the separate draft integration
uses its lossless decoder. Full backup and collection authority remain open.

## Durable draft integration harness

Docs pin `0bb0ff89df8529b1d7736057e0107b3a76a56d18` owns the
[bounded integration](../../../../docs/technical/native-draft-repository.md).
`DraftRepository` persists one add draft, frozen commands and successful receipts
in an installation-local development schema (`VDRF`, version 1). This is not the
product dataset schema and cannot be imported as a complete user backup.

The native writer commits the draft, receipt and frozen-body cleanup together.
Receipt replay precedes stale guards; abandonment retains ID/hash tombstones.
A missing/corrupt initialized DB never resets. `CanonicalParser` retains raw UTF16
units through escaped JSON TEXT, rejecting malformed/noncanonical envelopes.
Raw duplicate routine rows and null seed remain drafts; final plant validation
has not moved to this store.

Runner Debug registers a generated Pigeon host and uses a service isolate. Runner
Release has no registration. Swift DEBUG is explicitly set on Runner Debug;
Objective-C DEBUG alone is insufficient. Tooling is separately pinned in
`../../tooling/pigeon`. File protection must match the required class on devices;
simulator/macOS sessions explicitly report `fileProtectionVerified:false`.
No physical first-unlock, hardware power-loss or full customer durability claim.

From `apps/mobile`, execute the client integration with a selected simulator:

```sh
flutter test integration_test/durable_draft_test.dart -d <simulator-id>
flutter test integration_test/durable_draft_test.dart -d <simulator-id> \
  --no-uninstall --dart-define=DRAFT_RECOVERY_PHASE=freeze
# Terminate the app if the test runner has left it running, then launch separately:
flutter test integration_test/durable_draft_test.dart -d <simulator-id> \
  --no-uninstall --dart-define=DRAFT_RECOVERY_PHASE=recover
```

The pinned Flutter test runner uninstalls integration apps by default; the
`--no-uninstall` flag is necessary to test a restart of the same installation.
The freeze phase intentionally leaves a durable pending body and live handle;
recover discovers it through metadata/body reads after app termination, commits
its original ID once and verifies replay. It does not prove process death during
an SQLite transaction; deterministic native boundary tests cover rollback and
unknown commit control flow separately. The permanent CoreRepository namespace now supplies the main current-core UI;
this isolated draft harness remains unchanged as regression evidence.


## Permanent core checks

`CoreRepositoryTests` consumes `Fixtures/core-storage-v1.json`, generated by the
Dart planner and checked for drift in core tests. Twenty-eight transitions cover
all twenty-one current wire command names, with canonical row hashes verified
after every native transaction and selected reopen points. Additional tests cover
rollback/unknown receipt resolution, pending freeze restart, native expiry,
large escaped raw drafts, Unicode identity, malformed payloads, active cap,
exact delete-draft sets and unrelated-plant Undo preservation. Test fault injection
is internal to the Swift package. The public channel has no fault or reset API.

## Bundled catalog verification

The internal fixed bundle provider validates the package before installation.
A failed candidate retains the previous catalog; catalog-only read corruption
does not disable user-data operations. New selections validate against the native
current entry; unchanged stored selections retain their offline-edit exception.
`CatalogTests` checks the real 24-entry bundle, rights/review/hash/asset rejection.
`CoreRepositoryTests` replays the Dart catalog fixture, tests original suggestion
retention, atomic apply/rollback, corrupt reads, v1 pending-command migration and
older-reader rejection. Regenerate shared transitions with
`dart run tool/generate_catalog_vectors.dart` from the core package.

## Photos and journal extension

The permanent profile now migrates exact v1/v2 stores additively to schema v3,
retaining IDs, rows, frozen commands and receipts. New media/journal commands use
the same frozen-plan/preview/commit guards. A separate serialized file worker
retains OS selections, validates JPEG/PNG/HEIC, publishes registered immutable
originals, acknowledges draft ownership, and cleans only known unreferenced paths.
Ready/failed/consumed/deleted preparation status is durable. File-copy or failed
status-write recovery never resets the store. Original export copies are leased
through OS completion/cancellation, same-process reconnect, or 24-hour expiry.

`MediaFilesTests` exercises encoded formats, corruption, size/path boundaries,
original-byte preservation and backup eligibility. Native repository tests cover
v1/v2 migration, journal vectors/reopen, draft races, preparation replay, status
write recovery and export leases. Simulator tests do not prove physical iOS data
protection or power-loss durability. See the application handoff and focused
`docs/technical/photos-journal-integration.md` contract for remaining boundaries.
