# Verdi application

This repository is the selected home for Verdi application code. Development has started with an independently authored [pure Dart core](apps/mobile/packages/verdi_core/README.md) for the future Flutter customer app. There is no Flutter runner, native integration or admin scaffold yet. Product requirements and human review records live in the independent docs repository, pinned here at [docs/](docs/README.md).

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
dart format --output=none --set-exit-if-changed lib test example
dart analyze
dart test
dart run example/care_walkthrough.dart
dart run example/guarded_save_walkthrough.dart
```

The package uses synthetic, memory-only state, with locked grapheme and hashing
dependencies. The guarded-save example exercises draft integration and recovery
from a simulated lost reply without duplicating a plant.
These commands do not test native persistence, Flutter screens or store/OS behavior.

## Flutter development preview

The adapted Flutter customer app is in `apps/mobile`. Use Flutter **3.47.8** with
bundled Dart **3.13.7**. Read its `AGENTS.md` and `TEMPLATE_PROVENANCE.md` before
changing setup. This entry uses a temporary synthetic collection; closing the
process loses its data. It refuses release mode and is not a public release build.

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
