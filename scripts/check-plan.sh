#!/usr/bin/env bash
# Check a plan file against conventions.md §5.
#
# Checks:
# - a "## Verification strategy" section exists
# - an optional "## Release target" section has exactly one "Target:" line:
#   "Target: none" or "Target: `<adapter-name>`", optionally followed by
#   " - <what ships>" (conventions §5)
# - milestones are "## M<n>: <title>", with no duplicate numbers
# - inside a milestone, every "###" heading is a task: "### T-NNN: <title>",
#   optionally ending in "(dropped)"; task IDs are unique
# - every task has a "Depends on:" line ("none" or comma-separated task IDs)
#   and a "Done when:" line followed by at least one "- [ ]" or "- [x]" item
# - the optional "Issue:" line is "#<number>"
# - dependencies name existing tasks, live tasks don't depend on dropped
#   ones, and there are no cycles
#
# IDs are not required to be in order: a task keeps its ID when it moves
# to another milestone.
#
# Usage: scripts/check-plan.sh [plan-file]   (default: docs/plan/PLAN.md)
# Exit status: 0 if every check passes, 1 otherwise.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
plan="${1:-$root/docs/plan/PLAN.md}"
[[ -f "$plan" ]] || { echo "error: $plan not found" >&2; exit 1; }

awk '
function fail(line, msg) { printf "FAIL  %s:%d: %s\n", FILENAME, line, msg; failures++ }

# Check the task that just ended.
function close_task() {
  if (task == "") return
  if (!has_dep)        fail(task_line, task ": missing \"Depends on:\" line")
  if (!has_done)       fail(task_line, task ": missing \"Done when:\" line")
  else if (items == 0) fail(task_line, task ": \"Done when:\" has no checklist items")
  task = ""
}

# Check the "## Release target" section that just ended.
function close_target() {
  if (!in_target) return
  if (targets == 0) fail(target_line, "\"## Release target\" has no \"Target:\" line")
  in_target = 0
}

function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }

# Depth-first search for a cycle; colour 1 = on the stack, 2 = finished.
function visit(t,    n, parts, i, d) {
  colour[t] = 1
  n = split(deps[t], parts, " ")
  for (i = 1; i <= n; i++) {
    d = parts[i]
    if (!(d in exists)) continue
    if (colour[d] == 1) { fail(line_of[t], "dependency cycle through " t " and " d); continue }
    if (colour[d] == 0) visit(d)
  }
  colour[t] = 2
}

/^## / {
  close_task()
  close_target()
  in_milestone = 0
  if ($0 ~ /^## Verification strategy[ \t]*$/) { has_vs = 1; next }
  if ($0 ~ /^## Release target[ \t]*$/) { in_target = 1; target_line = FNR; targets = 0; next }
  if ($0 ~ /^## M/) {
    if ($0 !~ /^## M[0-9]+: [^ ]/) { fail(FNR, "milestone heading must be \"## M<n>: <title>\""); next }
    m = $2; sub(/:$/, "", m)
    if (m in milestones) fail(FNR, "duplicate milestone " m)
    milestones[m] = 1
    in_milestone = 1
  }
  next
}

/^### / {
  close_task()
  if (!in_milestone) next
  if ($0 !~ /^### T-[0-9][0-9][0-9]: [^ ]/) { fail(FNR, "heading inside a milestone must be a task: \"### T-NNN: <title>\""); next }
  task = $2; sub(/:$/, "", task)
  if (task in exists) fail(FNR, "duplicate task ID " task)
  exists[task] = 1; line_of[task] = FNR; task_line = FNR
  if ($0 ~ /\(dropped\)[ \t]*$/) dropped[task] = 1
  has_dep = 0; has_done = 0; items = 0
  next
}

in_target && /^Target:/ {
  targets++
  if (targets > 1) { fail(FNR, "\"## Release target\" has more than one \"Target:\" line"); next }
  if ($0 !~ /^Target: (none|`[a-z0-9][a-z0-9-]*`)( - .+)?[ \t]*$/)
    fail(FNR, "\"Target:\" must be \"none\" or `<adapter-name>`, optionally followed by \" - <what ships>\"")
  next
}

task != "" && /^Depends on:/ {
  has_dep = 1
  v = trim(substr($0, length("Depends on:") + 1))
  if (v == "none") next
  n = split(v, parts, ",")
  for (i = 1; i <= n; i++) {
    d = trim(parts[i])
    if (d !~ /^T-[0-9][0-9][0-9]$/) { fail(FNR, task ": dependency \"" d "\" is not a task ID (use \"none\" or T-NNN, T-NNN)"); continue }
    deps[task] = deps[task] " " d
    dep_line[task, d] = FNR
  }
  next
}

task != "" && /^Issue:/ {
  v = trim(substr($0, length("Issue:") + 1))
  if (v !~ /^#[0-9]+$/) fail(FNR, task ": \"Issue:\" must be \"#<number>\"")
  next
}

task != "" && /^Done when:/ { has_done = 1; next }

task != "" && has_done && /^- \[[ xX]\] / { items++ }

END {
  close_task()
  close_target()
  if (!has_vs) fail(1, "missing \"## Verification strategy\" section")
  for (t in deps) {
    n = split(deps[t], parts, " ")
    for (i = 1; i <= n; i++) {
      d = parts[i]
      if (!(d in exists))                  fail(dep_line[t, d], t ": depends on unknown task " d)
      else if (d in dropped && !(t in dropped)) fail(dep_line[t, d], t ": depends on dropped task " d)
    }
  }
  for (t in exists) if (colour[t] == 0) visit(t)
  ntasks = 0; for (t in exists) ntasks++
  nms = 0; for (m in milestones) nms++
  if (failures > 0) { printf "%d problem(s) in %s\n", failures, FILENAME; exit 1 }
  printf "ok: %s has %d milestone(s) and %d task(s)\n", FILENAME, nms, ntasks
}
' "$plan"
