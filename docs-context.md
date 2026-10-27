# Verdi documentation context

The `docs/` Git submodule is the product documentation owner. Its committed gitlink is this application's authoritative docs dependency; inspect the mounted checkout and staged candidate separately when updating it. Read [application instructions](AGENTS.md) before changing code or the pin.

## Choose the relevant context

- [Product overview](docs/overview.md): purpose, business direction and source boundaries.
- [Feature navigation](docs/features/README.md): behavior and acceptance by user task; follow its canonical requirement links.
- [Repository map](docs/repositories.md): stable app/repository identities and actual responsibilities.
- [Technical design owner](docs/technical/README.md): current design, contract ownership and unresolved implementation choices. Follow its actual contracts; do not invent an HTTP service or installed stack.
- [Current review checkpoint](docs/history/reviews/index.md): selected review, input identity, readiness findings and remaining decisions.
- [Record index](docs/INDEX.md): known requirements, questions, sources and original decision evidence.
- [Shared workflow](docs/workflow/README.md): canonical skills, rules and documentation verification.

Acceptance, documentation readiness, implementation and executed verification are different claims. A `not_ready` checkpoint blocks application implementation handoff, not an explicitly authorized docs-only publication or pin update. Preserve that state and report the failed readiness check honestly. Use the [README checks](README.md#documentation-checks) and record the exact docs pin and affected requirement IDs in each change review.
