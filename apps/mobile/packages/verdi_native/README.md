# Verdi native SQLite foundation

This module implements the connection/bootstrap/transaction infrastructure in
docs pin `7f48c37a90cf6a0f3dcb3409a086d3ede44890cc`, owned by
[`technical/native-sqlite-foundation.md`](../../../../docs/technical/native-sqlite-foundation.md).
It supports future durable REQ-006/007/008/009 behavior. It does not implement the
product schema, command registry, Pigeon bridge or a customer-data repository.
The Flutter preview still uses temporary synthetic data.

The package has no remote dependencies. It links the OS SQLite3 library and uses
one serial Dispatch queue per connection, FULLMUTEX, WAL/FULL, foreign keys and a
2,500 ms busy timeout. Swift tools 5.10 / language mode 5, macOS 14 and iOS 18 are
the package's development build floors; these are not submission-toolchain claims.

The internal API accepts only app-compiled SQL/schema descriptors and native
app-owned file URLs. Existing files receive read-only validation before writable
configuration. Trusted parent paths use POSIX `realpath` because Foundation can
normalize Apple's `/private/var` back to its symlink alias; the leaf is never
resolved and NOFOLLOW rejects a substituted file. New files are exclusive, mode
0600; stale sidecars reject creation. This is not iOS file-protection integration.

`read` and `transaction` callbacks are synchronous and scoped. Do not block on
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

Tests use a deliberately synthetic schema identity/version 7001. They exercise
real OS SQLite creation, close/reopen, constraints, rollback, lock contention,
concurrent calls and scoped access. Deterministic injected commit/rollback/close
faults test recovery control flow; the deferred foreign-key case fails a real
SQLite COMMIT. These do not prove hardware I/O failure, power loss, OS process
termination, iOS first-unlock/file protection, or Flutter bridge recovery.

Before personal data: implement full product schema/registered plans, native
guards/receipts/Undo, generated Pigeon/service-isolate wiring, file protection and
generation handling, then execute the runtime owner's interruption/recovery tests.
Do not register this foundation as the collection repository or remove the
development entry's release guard to make a preview look complete.
