# idea-to-release

Agent skills that take a project from idea to release. See `README.md` for the overview.

- Read `conventions.md` before changing anything. It is the source of truth for vocabulary, labels, branches, commits, the ledger and safety tiers.
- This repository is built with its own skills. Until a skill exists, follow the conventions by hand (see `docs/decisions/0001-build-skills-before-using-them.md`).
- Skills (`skills/*/SKILL.md`) use only the neutral verbs from conventions §2. Anything forge-specific belongs in `adapters/`.
- Every verb in conventions §2 has a section in each adapter, even if it only says `Status: not yet implemented`. `scripts/check-adapters.sh` enforces this. Run it after editing an adapter or §2.
- Current focus: roadmap items 2–3 (GitHub adapter verbs needed by `repo-bootstrap`, and the skill itself). Tracked in issue #1.
