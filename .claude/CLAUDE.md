# idea-to-release

Agent skills that take a project from idea to release. See `README.md` for the overview.

- Read `conventions.md` before changing anything. It is the source of truth for vocabulary, labels, branches, commits, traceability and safety tiers.
- This repository is built with its own skills. Until a skill exists, follow the conventions by hand (see `docs/decisions/0001-build-skills-before-using-them.md`).
- Skills (`skills/*/SKILL.md`) use only the neutral verbs from conventions §2. Anything forge-specific belongs in `adapters/`.
- Every verb in conventions §2 has a section in each adapter, even if it only says `Status: not yet implemented`. `scripts/check-adapters.sh` enforces this. Run it after editing an adapter or §2.
- Scripts must run on macOS defaults: bash 3.2 (no `mapfile`, associative arrays or `${var,,}`), BSD awk (no newlines in `-v` values) and BSD sed. Test them on macOS before pushing.
- The plan is `docs/plan/PLAN.md`, and every task has an issue titled `T-NNN: ...`. Work this repository's tasks with the `work-issue` skill (`skills/work-issue/SKILL.md`): it picks the next `ready` issue, runs the `run` commands from `.project/config.yml`, ticks the plan and opens the change request. Run `scripts/check-plan.sh` after editing the plan. Merging is always the maintainer's.
