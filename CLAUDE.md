# idea-to-release

Agent skills that take a project from idea to release. See `README.md` for the overview.

- Read `conventions.md` before changing anything. It is the source of truth for vocabulary, labels, branches, commits, the ledger and safety tiers.
- This repository is built with its own skills. Until a skill exists, follow the conventions by hand (see `docs/decisions/0001-build-skills-before-using-them.md`).
- Skills (`skills/*/SKILL.md`) use only the neutral verbs from conventions §2. Anything forge-specific belongs in `adapters/`.
- Every verb in conventions §2 has a section in each adapter, even if it only says `Status: not yet implemented`. `scripts/check-adapters.sh` enforces this. Run it after editing an adapter or §2.
- Scripts must run on macOS defaults: bash 3.2 (no `mapfile`, associative arrays or `${var,,}`), BSD awk (no newlines in `-v` values) and BSD sed. Test them on macOS before pushing.
- The plan is `docs/plan/PLAN.md`. Work its tasks in dependency order, and run `scripts/check-plan.sh` after editing it. Next up: M2 (T-007, T-008), building `plan-to-issues`.
