#!/usr/bin/env bash
# Check the ledger against conventions.md §6 and the plan.
#
# The ledger must use the restricted YAML shape shown in §6, so it can be
# checked without a YAML library:
#
#   tasks:                       (or "tasks: {}" when empty)
#     T-001:                     two-space indent
#       milestone: M1            four-space indent, one "key: value" per line
#       issue: 12
#       change_requests: [15, 16]
#       released_in: v0.1.0
#       created: 2026-11-20
#       merged: 2026-11-21
#       released: 2026-11-24
#
# Blank lines and "#" comments are allowed anywhere.
#
# Checks:
# - only the keys above, each at most once per task; task IDs unique
# - every task ID exists in the plan, and its milestone matches the plan's
# - issue is an integer; change_requests is a list of integers;
#   released_in is a tag v<major>.<minor>.<patch>; dates are YYYY-MM-DD
# - every task has milestone, issue and created
# - merged needs change_requests; released_in and released come together;
#   created <= merged <= released
#
# Usage: scripts/check-ledger.sh [ledger] [plan]
#        (defaults: .project/ledger.yml and docs/plan/PLAN.md)
# Exit status: 0 if every check passes, 1 otherwise.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
ledger="${1:-$root/.project/ledger.yml}"
plan="${2:-$root/docs/plan/PLAN.md}"
[[ -f "$ledger" ]] || { echo "error: $ledger not found" >&2; exit 1; }
[[ -f "$plan" ]]   || { echo "error: $plan not found" >&2; exit 1; }

awk '
function fail(line, msg) { printf "FAIL  %s:%d: %s\n", FILENAME, line, msg; failures++ }
function is_date(v) { return v ~ /^[0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]$/ }

function close_task(    k) {
  if (task == "") return
  for (k in required) if (!((task, k) in val)) fail(task_line, task ": missing " k)
  if (((task, "merged") in val) && !((task, "change_requests") in val && val[task, "change_requests"] != "[]"))
    fail(task_line, task ": merged is set but change_requests is empty")
  if (((task, "released_in") in val) != ((task, "released") in val))
    fail(task_line, task ": released_in and released must be set together")
  if (((task, "created") in val) && ((task, "merged") in val) && val[task, "merged"] < val[task, "created"])
    fail(task_line, task ": merged is before created")
  if (((task, "merged") in val) && ((task, "released") in val) && val[task, "released"] < val[task, "merged"])
    fail(task_line, task ": released is before merged")
  task = ""
}

BEGIN {
  required["milestone"]; required["issue"]; required["created"]
  known["milestone"]; known["issue"]; known["change_requests"]; known["released_in"]
  known["created"]; known["merged"]; known["released"]
}

# First input: the plan. Record the milestone of each task.
FNR == NR {
  if ($0 ~ /^## M[0-9]+: /) { m = $2; sub(/:$/, "", m) }
  else if ($0 ~ /^## /) m = ""
  else if (m != "" && $0 ~ /^### T-[0-9][0-9][0-9]: /) { t = $2; sub(/:$/, "", t); plan_ms[t] = m }
  next
}

# Drop comments (a "#" at the start or after whitespace) and trailing spaces.
{ line = $0; sub(/(^|[ \t])#.*$/, "", line); sub(/[ \t]+$/, "", line) }
line == "" { next }

!seen_root {
  if (line == "tasks:")         { seen_root = 1; next }
  if (line == "tasks: {}")      { seen_root = 1; empty = 1; next }
  fail(FNR, "the ledger must start with \"tasks:\""); exit_now = 1; exit
}

empty { fail(FNR, "\"tasks: {}\" must not be followed by entries"); next }

line ~ /^  [^ ]/ {
  close_task()
  if (line !~ /^  T-[0-9][0-9][0-9]:$/) { fail(FNR, "expected a task ID line like \"  T-001:\""); next }
  task = line; sub(/^  /, "", task); sub(/:$/, "", task); task_line = FNR
  if (task in tasks) fail(FNR, "duplicate task " task)
  tasks[task] = 1
  if (!(task in plan_ms)) fail(FNR, task ": not a task in the plan")
  next
}

line ~ /^    [^ ]/ {
  if (task == "") { fail(FNR, "field outside a task"); next }
  if (line !~ /^    [a-z_]+: [^ ]/) { fail(FNR, "expected \"key: value\""); next }
  key = line; sub(/^    /, "", key); sub(/:.*$/, "", key)
  v = line; sub(/^    [a-z_]+: /, "", v)
  if (!(key in known)) { fail(FNR, task ": unknown key " key); next }
  if ((task, key) in val) { fail(FNR, task ": duplicate key " key); next }
  val[task, key] = v
  if (key == "milestone") {
    if (v !~ /^M[0-9]+$/) fail(FNR, task ": milestone must be M<n>")
    else if ((task in plan_ms) && plan_ms[task] != v) fail(FNR, task ": milestone " v " does not match the plan (" plan_ms[task] ")")
  } else if (key == "issue") {
    if (v !~ /^[0-9]+$/) fail(FNR, task ": issue must be an integer")
  } else if (key == "change_requests") {
    if (v !~ /^\[([0-9]+(, [0-9]+)*)?\]$/) fail(FNR, task ": change_requests must be a list like [15, 16]")
  } else if (key == "released_in") {
    if (v !~ /^v[0-9]+\.[0-9]+\.[0-9]+$/) fail(FNR, task ": released_in must be a tag like v0.1.0")
  } else if (!is_date(v)) {
    fail(FNR, task ": " key " must be a date YYYY-MM-DD")
  }
  next
}

{ fail(FNR, "unexpected indentation; use two spaces for task IDs and four for fields") }

END {
  if (exit_now) { printf "%d problem(s) in %s\n", failures, FILENAME; exit 1 }
  close_task()
  if (!seen_root) fail(1, "the ledger must start with \"tasks:\"")
  if (failures > 0) { printf "%d problem(s) in %s\n", failures, FILENAME; exit 1 }
  n = 0; for (t in tasks) n++
  printf "ok: %s has %d task(s)\n", FILENAME, n
}
' "$plan" "$ledger"
