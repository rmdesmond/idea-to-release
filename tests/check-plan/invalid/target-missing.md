<!-- expect: "## Release target" has no "Target:" line -->

## Verification strategy

Lint only.

## Release target

It ships a command.

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
