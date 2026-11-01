# Verdi application

This repository is the selected home for Verdi application code. Development includes a [pure Dart core](apps/mobile/packages/verdi_core/README.md), a tested Flutter/iOS preview and a [native SQLite foundation](apps/mobile/packages/verdi_native/README.md). The main development UI saves custom and catalog plants, care, combined history, journal notes and drafts in native SQLite, with original photos in managed local files. A reviewed 24-species bundle supplies offline search, species information and explicit care-suggestion choices. Settings now manages custom care types; plant detail adds standard or Pro custom routines, with preserved historical labels and compatible backup restore. The full product feature set and internal admin remain unfinished. Product requirements and human review records live in the independent docs repository, pinned here at [docs/](docs/README.md).

## Start with the AI

Give your assistant [AGENTS.md](AGENTS.md) and describe the task. Start with [docs context](docs-context.md) for the product, feature and current review routes. For documentation work, say **“Continue the docs”** or **“Review the pending requirement questions.”** The assistant follows the [canonical workflow](docs/workflow/README.md) in the pinned checkout and maintains the records. Questions and requirement acceptance require actual human answers.

Thin adapters in `.agents/skills/` and `.claude/skills/` expose all shared documentation and delivery skills without copying their bodies. Interactive discovery depends on the client; the explicit fallback is `docs/workflow/skills/<skill-name>/SKILL.md`. Follow links from the canonical skill directory, not the adapter directory.

## Restore the docs checkout

The documentation submodule uses SSH. Team members need read access to both GitHub repositories and a GitHub SSH key configured locally. After cloning this repository, initialize its recorded docs commit:

```sh
git submodule update --init --checkout -- docs
```

Check for local changes inside an existing docs checkout before switching its version. The submodule records an exact commit; use the [adoption skill](docs/workflow/skills/docs-adopt/SKILL.md) to prepare a version update. Publish the docs commit and verify remote access before updating the app pin. Preserve local changes and ignored originals before changing the mounted checkout. Original imported source material stays local and is unavailable in a fresh clone; the docs record the captured evidence and its limitations.

## Documentation checks

From this repository's root, prepare Python 3.11 or later and the docs dependencies:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r docs/scripts/requirements.txt
.venv/bin/python docs/scripts/check_gitlink.py --root . --docs-path docs
.venv/bin/python docs/scripts/check_consumer.py --root . --mount docs
.venv/bin/python docs/scripts/check_all.py --root docs
```

Run and report all three checks even if an earlier one fails. The gitlink check verifies the staged/index pin and clean mounted checkout only. The full consumer check verifies the committed pin, selected ready review/input identity, shared skill adapters and context links. The docs aggregate runs the required check profile maintained in `docs/workflow/checks.json`; it does not establish product readiness.

When preparing a pin update, stage only the intended gitlink and use `--pin index` with the full consumer command to inspect the staged candidate. After committing, run the default full consumer command again against the committed pin.

If the [selected checkpoint](docs/history/reviews/index.md) is `not_ready`, the full consumer handoff check must fail and application implementation remains blocked. An explicitly authorized docs-only publication or pin update can still proceed with that failure recorded; it is not an implementation-ready handoff. Do not weaken the check or relabel the checkpoint to obtain a pass. Structural checks, remote publication/access and interactive skill discovery are separate evidence.

On Windows, use `.venv\Scripts\python.exe`. No application CI is configured yet.

## Core development checks

Use Dart 3.13.7 (or that bundled in selected Flutter 3.47.8), then:

```sh
cd apps/mobile/packages/verdi_core
dart pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test example tool
dart analyze
dart test
dart run example/care_walkthrough.dart
dart run example/guarded_save_walkthrough.dart
```

The package supplies the canonical planner, stored-row hydration and an explicit
memory test harness, with locked grapheme and hashing dependencies. The guarded-save example exercises draft integration and recovery
from a simulated lost reply without duplicating a plant.
These commands do not test native persistence, Flutter screens or store/OS behavior.

## Flutter development preview

The adapted Flutter customer app is in `apps/mobile`. Use Flutter **3.47.8** with
bundled Dart **3.13.7**. Read its `AGENTS.md` and `TEMPLATE_PROVENANCE.md` before
changing setup. This entry opens the permanent `custom_core_v1` native store,
reconciles interrupted operations and hydrates the collection before opening the
workspace. Failed startup retains files and offers Retry. It refuses release mode.

```sh
cd apps/mobile
flutter pub get --enforce-lockfile
flutter gen-l10n
dart run build_runner build
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter run -t lib/main_development.dart
```

For a fresh iOS checkout, run `LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install`
from `apps/mobile/ios`. Use `flutter devices` to select an available iOS simulator,
then run `flutter test integration_test/collection_flow_test.dart -d DEVICE_ID`
from `apps/mobile`. The native test exercises the actual Flutter/iOS runner with
synthetic data; it does not prove durable storage, StoreKit or notifications.
Keep native/generated dependencies and secrets out of commits according to the
repository ignores. Generated Dart source and dependency lockfiles are committed.

The [current delivery handoff](history/work/app-readiness/README.md) records exact docs
identity, scope, executed evidence and remaining criteria. Do not run upstream
fresh-repository setup over this existing repository or copy unreviewed assets.

## Native SQLite foundation

The [Swift package](apps/mobile/packages/verdi_native/README.md) owns real OS
SQLite connection/bootstrap/transaction infrastructure. Run `swift test` and
`swift build -Xswiftc -warnings-as-errors` from `apps/mobile/packages/verdi_native`.
Its README supplies the iOS simulator package-test command and scope limits.
The permanent current-core schema is distinct from the preserved synthetic
foundation and draft-harness schemas. Main UI data is in Application Support/
VerdiCore initially; validated restores select a new sibling generation through an
installation-local recovery database. Settings now exposes free backup/restore.
Simulator file protection remains
unverified; device, store, missing-feature and release checks remain outstanding.


## Durable main UI verification

Run these separate processes against the same simulator installation (the Flutter
runner otherwise uninstalls the app). Tests clean up only their named synthetic
fixtures and retain other records. Run recovery immediately after seed:

```sh
cd apps/mobile
flutter test integration_test/durable_core_test.dart -d DEVICE_ID --no-uninstall --dart-define=VERDI_CORE_PHASE=seed
flutter test integration_test/durable_core_test.dart -d DEVICE_ID --no-uninstall --dart-define=VERDI_CORE_PHASE=recover
flutter test integration_test/native_retry_test.dart -d DEVICE_ID --no-uninstall
```

The first two exercise the main startup, plant/care/history UI and retained draft/
pending-action recovery. The retry test injects service-boundary failures around
real native writes; native transaction-boundary failures are exercised separately
in Swift. Test hooks are debug-only, expose no file paths or SQL, and are not UI
controls. The memory environment is requested explicitly by unit/widget tests.

Regenerate the 28-transition Dart/native storage fixture from `packages/verdi_core`
with `dart run tool/generate_storage_vectors.dart`; the core test detects drift.
Keep `tooling/pigeon/check_generation.py` passing for both generated API outputs.

## Bundled catalog verification

The reviewed content, source/rights evidence and deterministic build instructions
are in [tooling/catalog](tooling/catalog/README.md). The installed catalog is
separate from user data; schema v2 adds linked selection and immutable suggestion
snapshots without replacing the permanent `custom_core_v1` dataset. A failed
catalog update retains the last good catalog and custom entry stays available.

Run the catalog UI seed and recovery in separate processes on the same retained
installation, immediately one after the other:

```sh
cd apps/mobile
flutter test integration_test/catalog_flow_test.dart -d DEVICE_ID --no-uninstall --dart-define=VERDI_CATALOG_PHASE=seed
flutter test integration_test/catalog_flow_test.dart -d DEVICE_ID --no-uninstall --dart-define=VERDI_CATALOG_PHASE=recover
```

These exercise search/info, durable selection, explicit suggestion application,
care/lifecycle and draft recovery. The `upgrade` phase is a separate migration
probe for the documented retained v1 fixture; do not claim migration evidence
from running it on an already upgraded installation. Native tests separately
exercise real v1 migration, interrupted migration, retained frozen commands,
malformed bundles and catalog updates. Regenerate the known/unknown-seed catalog
vectors with `dart run tool/generate_catalog_vectors.dart` from `packages/verdi_core`.

## Photos and journal verification

The main preview now retains journal notes/dates/drafts and original photos in
SQLite plus managed files. Photos can be attached from the native library, used
as covers, replaced without changing their ID, or deleted with shared references
updated atomically. Journal entries join care history in the plant timeline.
Free original export uses an explicit metadata warning and the OS share sheet.
Camera code is present; physical capture/protection tests remain outstanding.
Optional photo optimization is now available through explicit selection and confirmation; remaining release checks stay separate.

The media integration test uses the real OS picker. Seed the bundled
`assets/illustrations/empty-plants.png` and the distinct synthetic
`packages/verdi_native/Tests/VerdiNativeTests/Fixtures/catalog/media-green.png`
into the simulator Photos library using `xcrun simctl addmedia DEVICE_ID PATH`.
Run phases in order on the same retained installation:

```sh
cd apps/mobile
flutter test integration_test/photos_journal_test.dart -d DEVICE_ID --no-uninstall --dart-define=VERDI_MEDIA_PHASE=seed
flutter test integration_test/photos_journal_test.dart -d DEVICE_ID --no-uninstall --dart-define=VERDI_MEDIA_PHASE=recover
flutter test integration_test/photos_journal_test.dart -d DEVICE_ID --no-uninstall --dart-define=VERDI_MEDIA_PHASE=replace
flutter test integration_test/photos_journal_test.dart -d DEVICE_ID --no-uninstall --dart-define=VERDI_MEDIA_PHASE=cover_export
```

Choose the plant illustration for `seed`, then the distinct green fixture for
`replace` and `cover_export`. Cancel the final OS share sheet without sending.
The test preserves other plants and verifies their IDs remain present; it retains
its named synthetic plant/notes. It needs operator interaction and is not an
unattended CI test. Use a new named fixture or a fresh test simulator for another
full sequence; never reset an existing user's store merely to rerun tests.

## Backup and restore verification

Settings → Backup & restore creates a portable ZIP, opens explicit iOS sharing,
and validates a selected ZIP before a replace-not-merge confirmation. Format2
contains the complete implemented `custom_core_v1` content and preferences;
unreleased documentary format1 is not an import format. Replacement reopens the
Flutter repository/router with a new dataset identity. Old collections remain
retained until recovery verifies the new generation. No entitlement is imported.

Use a **separate disposable simulator** for replacement tests. The retained
normal development collection must not be overwritten by QA. Run
`integration_test/backup_restore_test.dart` with `--no-uninstall`; default `seed`
creates the named QA plant and tests native backup creation. The `rich` phase
(`--dart-define=VERDI_BACKUP_PHASE=rich`) verifies a previously imported rich
synthetic fixture, restart hydration and replacement-draft review. It assumes
that fixture, and never silently resets another collection. Generate it with
`VERDI_BACKUP_FIXTURE_OUTPUT=/tmp/verdi-backup-rich.zip swift test --filter
 testBackupRich` in the native package; use the OS Files picker to import it.
The handoff records actual simulator IDs, results and remaining release checks.

## One-time Pro verification

The development preview uses native StoreKit2 with the Xcode-only non-consumable
`dev.verdi.preview.pro.local`. Settings → Verdi Pro and the add/restore limit offer
unlimited plants, explicit Restore, and Free exit. No real store product is
registered. Without an active local StoreKit session the offer is unavailable;
core care, existing content and backup remain usable. Entitlements and purchase
attempts stay outside content backups. A purchase never saves a plant automatically.

Run hosted tests on a **disposable simulator**, separate from retained user data:

```sh
cd apps/mobile/ios
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 xcodebuild \
  -workspace Runner.xcworkspace -scheme Runner -configuration Debug \
  -destination 'platform=iOS Simulator,id=DEVICE_ID' \
  -parallel-testing-enabled NO -derivedDataPath /tmp/verdi-hosted-store-build \
  -only-testing:RunnerTests/StoreKitIntegrationTests \
  FLUTTER_TARGET=lib/main_development.dart test
```

The TestAction isolates the hosted coordinator with `VERDI_NATIVE_STORE_TESTS=1`;
ordinary launches and Flutter integration retain the real platform bridge.
`RunnerTests/Verdi.storekit` supplies simulated purchases with no real charge.
Hosted tests exercise purchase/restore/refund, pending approval/decline/retry,
late approval, restart, cancellation and failed cache writes. Native authority
fault tests use `swift test --filter 'Store|ProGate'` in the native package.

`flutter test integration_test/pro_test.dart -d DEVICE_ID --no-uninstall` from
`apps/mobile` requires the retained rich **QA** collection with at least five
active plants and an archived plant. It exercises Settings and the restore gate,
then checks that existing plants/history/photos/drafts are preserved. It never
resets a collection or initiates a purchase. Flutter widget tests separately
verify same-command fresh confirmation after upgrade and delayed store/UI races.
Physical StoreKit/account/protection and production configuration remain open.

## Local share cards and comparisons

Plant detail → Share plant card prepares a free local PNG preview from the plant's
name/species and cover or explicit illustration. Photos → Compare photos lets a
Pro user choose two same-plant photos with their recorded dates. Native authority
rechecks sources and entitlement before each external handoff. Preview bytes are
the actual exported PNG; notes, location and original metadata are excluded.

Save image uses Photos add-only authorization. A lost result tells the person to
check Photos before explicitly retrying; no external save/share retries itself.
Passive previews do not block backup restore. Active OS operations retain their
own file lease through preview closure/reopen until their callback ends.

Run `swift test --filter Card` from the native package and `flutter test
 test/card_test.dart` from `apps/mobile`. Main simulator `integration_test/cards_test.dart`
requires the retained QA collection with a saved cover. Use `--no-uninstall`,
cancel the native share sheet without sending, then answer the add-only permission
prompt. `--dart-define=VERDI_CARD_DENIED=true` exercises a simulator with Photos
add-only access denied. The test retains collection data; successful Save creates
one synthetic card in that simulator's Photos library. Restore the test permission
after a denial run. Physical recipient/save/protection and production Pro checks
remain release evidence, separately from these development checks.

## Local privacy, help and feedback

Settings now includes bundled Privacy & local data, Help & feedback and
Open-source licenses. Feedback initially contains only app/build/iOS versions;
it can be edited and explicitly copied. Direct support contact is unconfigured,
so there is no Send action or invented address. Copy errors/timeouts preserve
edits; leaving a changed draft asks before discarding it. No collection content
is automatically attached. The Flutter license registry retains the bundled
ZIPFoundation notice alongside package notices.

Run `flutter test test/help_test.dart` for boundaries, recovery and large-text
checks. Run `flutter test integration_test/help_test.dart -d DEVICE_ID
--no-uninstall` against the retained QA simulator for native metadata, exact
clipboard content and unchanged collection evidence. It copies a synthetic QA
message to the simulator clipboard without sending it. Public support/policy,
network observation and platform privacy disclosures remain release work.

## Optional local photo optimization

Photos → Optimize photos starts with nothing selected. Review 1–200 saved photos,
JPEG quality 85%, a 1280px maximum long edge without upscaling, and replacement of
app-stored originals before confirming. Existing cover/journal references and
photo IDs/dates remain. Alpha-bearing PNGs remain unchanged with an explanation;
smaller files are not guaranteed. Each result is durable. Cancel remaining does
not undo successes; an interruption requires explicit recovery, never automatic
replacement retry. Failed replacement drafts can be opened from the result.

Run `swift test --filter Optimization` from the native package and `flutter test
test/optimization_test.dart` from `apps/mobile`. The actual-main-UI test
`integration_test/optimization_test.dart` needs a **separate QA simulator**, a
large opaque JPEG and alpha-bearing PNG in its Photos library, and operator picker
selection. Use `--no-uninstall`; it changes only its named Optimization QA fern
fixture and retains other plants. It covers partial results and lost-reply recovery.
The schema6 additive operational ledger is excluded from content backup format3;
formats2/3 and old switched-generation recovery remain supported. Device memory,
protection and power-loss checks remain open.
