# Publish the Verdi migration and update the app docs pin

**Author:** Codex (AI assistant; separate preservation and consumer-routing reviewers)
**Date:** 2026-10-27 (Asia/Jakarta)

## Scope and authority

The user requested: “go commit and push the migrated docs, then update the app’s docs pin. make sure all existing changes and accepted decisions stay preserved”. This handoff covers documentation publication and the consumer dependency/routing update only, not application implementation or new product acceptance.

Application base: `a14ac6d80859a8fddf42a4b0934d06168653a6f0` on main, with no app-file edits initially; the docs submodule contained preexisting uncommitted work. The app change is prepared on `codex/update-migrated-docs-pin-2026-10-27`. App remote publication is not part of this handoff; only the docs branch was requested for push.

## Published dependency and preservation

Old docs pin: `ed4ec65fe202cf6f90b1e6248ecdbb43e4f2d95f`.
New docs pin: `2b3256acf795abc757302713b7d98d2e93614a38`.

The [docs migration commit](https://github.com/hirumi7/verdi-docs/commit/2b3256acf795abc757302713b7d98d2e93614a38) was committed and pushed to `codex/docs-template-upgrade-2026-10-27` before changing the app's gitlink. An SSH remote-ref query returned the exact new SHA, and `git submodule update --init --checkout -- docs` freshly fetched and installed it from the configured GitHub remote. Docs remote main remained `9b3df9f034d581a3bdc0b71f7ef2f4cd4a830c92`; no force-push or merge to main occurred. Its October 8 workflow history is retained by exact source links in the [publication review](../../../docs/history/reviews/docs-publication-2026-10-27.md).

All 19 canonical requirements, four questions, five source records, two curated evidence files and BRD/FSD were compared against the original dirty source. All 17 accepted decisions/digests and all eight selection/eight capture records remain preserved; REQ-002 and REQ-019 remain proposed. The affected set is REQ-001 through REQ-019, for dependency exposure only—no behavior or acceptance changed during publication.

Before replacing the docs mount, the entire dirty checkout and its Git metadata were relocated to a recoverable sibling directory named `verdi-docs-preserved-2026-10-27.<unique-suffix>`. Its `worktree/`, `gitdir/`, original pointer/config copies and local recovery README preserve all existing work, including ignored source originals. All 90 non-.git worktree file hashes and the complete Git status, branch and HEAD matched after relocation. No reset, clean, stash or deletion was used. The initial metadata-update command could not follow the old relative worktree path; updating the config by explicit file path repaired that pointer, after which the full comparison passed. The separate application `claude-import/` directory was not changed. Private machine paths and raw originals are not published.

## App changes

Advance only the intended docs gitlink and reconcile AGENTS/README with the new canonical workflow. Add `docs-context.md` and eight thin shared-skill adapters in each of `.agents/skills` and `.claude/skills`; frontmatter matches the canonical bodies and subsequent links resolve from them. Existing CLAUDE/GEMINI forwarding guides are preserved. No stack, application code, global assistant settings or app CI was added.

## Verification and limits

- Published docs preparation: eight required checks and all 268 tests passed; final record/log checks and selected input identity passed before/after commit. The staged docs diff retained three disclosed blank-EOF warnings in historical evidence/an upstream fixture so their bytes were not silently changed.
- Fresh mounted docs aggregate (`docs/scripts/check_all.py --root docs` using the migration checkout's prepared Python 3.14.7 environment): **8/8 checks and all 268 tests passed**, 77.108 seconds. A separate final audit again confirmed all 32 authoritative product files and 17 accepted digests against the preserved original checkout; publication identity and clean mounted SHA matched.
- `python3 docs/scripts/check_gitlink.py --root . --docs-path docs`: passed against the staged pin and clean new mount.
- The unmodified `check_gitlink.check_consumer`, `check_consumer.check_submodule_mapping`, `check_consumer.check_skills`, context-link functions and `review_snapshot.check` separately passed for the staged pin: eight skills in each client, required context routes present, selected publication input identity current. This does not replace the readiness gate.
- `python3 docs/scripts/check_consumer.py --root . --mount docs --pin index`: **failed as expected**, exactly `Selected documentation checkpoint is not_ready`. Repeat against the committed pin after the app commit; do not alter the checkpoint or validator to obtain a pass.
- GitHub Actions status was unavailable: the configured `gh` API request returned HTTP 404. SSH push and fresh clone succeeded, but remote CI success is not claimed.
- Interactive client discovery and app/physical-device tests were not executed. No app build/test commands exist yet. Application implementation remains outside this task.

## Remaining work

Keep the published docs' product readiness `not_ready`. Q-002 Popular content, Q-003 licensed assets/mapping, Q-004 platform/device evidence and concrete implementation-design gaps remain open. The authorized dependency update does not resolve them or accept REQ-002/REQ-019. Retain the recovery checkout until the user no longer needs the pre-migration state. The app pin commit stays on its local change branch unless separately published.
