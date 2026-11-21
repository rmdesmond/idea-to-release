# 0014: Installed skills find their shared files in a sibling folder

Date: 2026-11-21
Status: accepted

## Context

Every skill reads `conventions.md`, looks up verbs in `adapters/`, and some run `scripts/check-*.sh`. In this repository those sit at the root, two levels above `skills/<skill>/`.

Agents that read Agent Skills look for `<skills-folder>/<skill>/SKILL.md` and nothing else. Once installed, the skills need to find the shared files from inside a skills folder.

Options considered:

- **A copy in every skill folder.** Self-contained, but seven copies of the same files that can drift apart, and an update has to replace all of them.
- **A sibling folder,** `<skills-folder>/idea-to-release/`, with no `SKILL.md`. One copy, next to the skills.
- **Move the files into a skill folder in this repository too,** so the clone and the install look the same. That's a large move of the repository's own layout for no gain while working on it.

## Decision

- When installed, the shared files are in `<skills-folder>/idea-to-release/`: `conventions.md`, `adapters/`, `scripts/check-*.sh`, `LICENSE` and a `VERSION` file. It has no `SKILL.md`, so it isn't loaded as a skill.
- Each `SKILL.md` says where to look: `../idea-to-release/` when installed, or `../../` in a clone of this repository (conventions §3).
- The release archive uses the installed layout, so `install.sh` copies folders as they are, and a hand copy works too.
- `install.sh` replaces only an earlier idea-to-release install, recognised by `idea-to-release/VERSION`. It refuses to overwrite skill folders it didn't install, unless given `--force`.

## Consequences

- One copy of the shared files per install, and an upgrade replaces it whole.
- A skill copied on its own, without the sibling folder, can't find the conventions. `package.verify` checks that every installed skill can.
- The folder name `idea-to-release` is reserved in any skills folder the set is installed into.
