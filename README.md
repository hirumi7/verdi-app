# Verdi application

This repository is the selected home for Verdi application code. The application has not been scaffolded yet. Product requirements and human review records live in the independent docs repository, pinned here at [docs/](docs/README.md).

## Start with the AI

Give your assistant [AGENTS.md](AGENTS.md) and describe the task. For documentation work, say **“Continue the docs”** or **“Review the pending requirement questions.”** The assistant follows the skills in the pinned checkout and maintains the records. Questions and requirement acceptance require actual human answers.

## Restore the docs checkout

The documentation submodule uses SSH. Team members need read access to both GitHub repositories and a GitHub SSH key configured locally. After cloning this repository, initialize its recorded docs commit:

```sh
git submodule update --init --checkout -- docs
```

Check for local changes inside an existing docs checkout before switching its version. The submodule records an exact commit; use the [adoption skill](docs/skills/docs-adopt/SKILL.md) to prepare a version update. Original imported source material stays local and is unavailable in a fresh clone; the docs record the captured evidence and its limitations.

## Documentation checks

From this repository's root, prepare Python 3.11 or later and the docs dependency:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r docs/scripts/requirements.txt
.venv/bin/python docs/scripts/check_consumer.py --root . --docs-path docs
.venv/bin/python docs/scripts/check_docs.py --root docs
.venv/bin/python docs/scripts/build_index.py --root docs --check
```

On Windows, use `.venv\Scripts\python.exe`. These commands check the pinned documentation and submodule registration. Record application setup, tests, and build commands here when application code is introduced.
