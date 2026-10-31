# Native repository bridge tooling

Run from this directory with the application-pinned Dart SDK:

```sh
dart pub get --enforce-lockfile
python3 check_generation.py --write
python3 check_generation.py
```

Pigeon 29.0.11 is separately locked so its analyzer cannot alter the Flutter
Freezed/router/DI generator solve. Dart and Swift outputs are generated together;
do not edit them by hand. The reproducible pipeline formats Dart output with
the pinned SDK (language 3.13, width 80); raw Pigeon output has trailing whitespace. Set `DART_BIN` when the pinned Dart is not on PATH.

The draft API is a DEBUG-only integration harness with a separate native
Application Support directory and SQLite application ID. It is not the customer
CollectionRepository and has no reset/delete channel. The main development UI uses the separate CoreRepositoryHostApi and permanent
custom_core_v1 profile. A missing/corrupt initialized database does not become an
empty one. Simulator file protection is reported as unverified; device proof and
remaining product features remain outstanding.

`DraftRepositoryService.open()` establishes the transport/session only. Its caller
must page pending metadata, resolve receipts, and explicitly retry or abandon an
uncommitted original write before starting new edits. It never silently replays
pending drafts. `durable_draft_test.dart` exercises that sequence with disposable
input through actual native channels and one service isolate. Keep the original
ID/hash after unknown outcomes; reopen before receipt resolution after a
transport timeout. No production UI should register this partial backend.


The same Pigeon source also defines CoreRepositoryHostApi. Its bounded canonical
request/response envelopes use a closed native operation/statement registry,
preserve raw UTF-16 and carry no arbitrary SQL/path. NativeCollectionRepository
serializes it through one service isolate; UI receives immutable domain DTOs.
Unknown native/transport outcomes close the service. Receipt resolution reopens a
native session and checks the original ID before re-planning. Runtime file paths
are selected only by CoreRepositoryBridge.
