<!-- expect: "Target:" must be "none" or `<adapter-name>`, optionally followed by " - <what ships>" -->

## Verification strategy

Lint only.

## Release target

Target: a shell command

## M1: Skeleton

### T-001: Entry point
Depends on: none
Issue: #12
Done when:
- [x] prints version
- [x] unit test

### T-003: Config loader
Depends on: T-001
Done when:
- [ ] loads file

## M2: More

### T-002: Old idea (dropped)
Depends on: none
Done when:
- [ ] n/a

### T-004: Feature
Depends on: T-001, T-003
Done when:
- [ ] works
