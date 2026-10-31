# Flutter starter and visual provenance

Adapted from the user-selected PLabs Flutter template at
`ea035cccdd6aa5c0a6cf243b7ff2ca16e94a4d26` (master). The iOS runner and selected
code rules were copied; application/bootstrap/theme/router are adapted to the
private offline product, with feature Cubits, Freezed states, injectable/get_it
and auto_route retained. Authentication, network clients/loggers, preferences
storage and remote fonts are excluded. The user confirmed commercial template
and imported-artwork rights on 2026-10-31; see pinned SRC-011.

Figma file `j2I5k6LkRUkpvzDHNwpvdF`: semantic tokens from 5:3; layouts from
11:396, 11:481, 11:4688 and 11:4271. `assets/illustrations/empty-plants.png` is an
unmodified asset export of illustration node 11:407, not a screenshot used as UI.
This single generic scene does not constitute a reviewed production species
artwork catalog. Ephemeral asset URLs are not runtime sources or committed here.

Original template dependency solve with Flutter 3.47.8 needed only four SDK-bound
updates: matcher 0.12.20, meta 1.19.0, test_api 0.7.12, vector_math 2.4.4.
This app intentionally retains the required architecture packages and removes
unused demo dependencies; its own reviewed lock is authoritative.

Actual fresh generation required the reviewed correction pinned in docs
`512bfa816085c9c211b7054229f150cf4a4d2725`: Freezed 4.0.1 / annotations
3.1.0, injectable 3.0.0 / generator 3.1.3, auto_route 11.2.0 / generator
10.6.0, build_runner 2.16.1 and analyzer 13.3.0. No overrides are used.
The Flutter SDK integration_test dependency adds only development test tooling.
Flutter generated Swift Package Manager integration for that test plugin; the
existing CocoaPods Flutter integration remains and passes native simulator tests.
CocoaPods 1.16.2 and its lock are retained. A UTF-8 process locale is required for
pod installation on this host. This is simulator setup, not release signing.
