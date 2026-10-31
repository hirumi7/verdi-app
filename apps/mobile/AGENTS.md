# Flutter customer code

Read the root application instructions and pinned docs review first. This folder
adapts PLabs flutter-template at ea035cccdd6aa5c0a6cf243b7ff2ca16e94a4d26;
selected code rules are retained in `.cursor/rules/`. Feature-first Cubit/Freezed,
get_it/injectable and auto_route are the local conventions. No auth/network demo,
runtime font downloads or preference-backed care database is adopted.

The current entry `lib/main_development.dart` opens native custom-core storage
through CoreBootstrap and refuses release mode. Memory is an explicit test
environment. Native ownership follows docs/technical/native-core-repository.md
and flutter-runtime.md in the repository root; missing/corrupt storage never
falls back to an empty or memory collection.

Use Flutter 3.47.8 / Dart 3.13.7. After dependency changes, retain and review the
lockfile. Run `flutter gen-l10n`, `dart run build_runner build`, `flutter analyze`,
`flutter test` and the separate verdi_core checks. Generated output is committed;
do not hand-edit it. Critical interaction/large-text tests are required by the
product review even though the template discourages low-value widget tests.

For native verification build `flutter build ios --simulator --debug -t
lib/main_development.dart`. Record actual results and unavailable device/store
checks in the root current handoff.

The native draft bridge is a separate DEBUG-only integration harness, with its
own development schema/path. It does not replace CollectionRepository. Its
service caller must resolve pending metadata/bodies before new edits. The main
CoreRepository API uses a separate permanent schema/path and full current-core
registry; preserve both namespaces. Follow the
pinned native-draft-repository owner and `tooling/pigeon/README.md`; regenerate
Dart and Swift together. Use `--no-uninstall` for integration restart tests,
because the pinned Flutter test runner otherwise deletes the installation.
