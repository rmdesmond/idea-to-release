#!/usr/bin/env bash
# Render the pipeline block of .project/config.yml as a GitHub Actions
# workflow (pipeline.render in adapters/forge/github.md, conventions §11).
#
# The output is deterministic: the same config always gives the same bytes,
# so accept-the-plan can compare it with the committed file and report "no changes".
#
# Reads the restricted config shape from conventions §4:
#
#   default_branch: main
#   release:
#     tag_prefix: v
#   pipeline:
#     ci: on-demand                  (optional: always | on-demand; default always)
#     stages:
#       lint:
#         enabled: true
#         run: "make lint"           (enabled stages)
#       build:
#         enabled: false
#         reason: "Nothing to compile"   (disabled stages)
#     extra_stages:                  (or "extra_stages: []")
#       - name: audit
#         runs_on: [change_request, schedule]
#         mode: advisory             (required | advisory)
#         run: "make audit"
#         cron: "0 6 * * 1"          (optional; schedule stages only)
#
# Usage: render-pipeline.sh [config]   (default: .project/config.yml)
# Writes the workflow to standard output. Exit status: 0 on success, 1 if
# the config can't be rendered (the reason goes to standard error).

set -euo pipefail

config="${1:-.project/config.yml}"
[[ -f "$config" ]] || { echo "error: $config not found" >&2; exit 1; }

awk '
function err(msg) { printf "error: %s: %s\n", FILENAME, msg > "/dev/stderr"; bad = 1 }

# A value: a double-quoted string (with \" and \\ escapes) or a bare word,
# optionally followed by a comment.
function value(s,    out, i, c) {
  sub(/^[ \t]+/, "", s)
  if (substr(s, 1, 1) == "\"") {
    out = ""
    for (i = 2; i <= length(s); i++) {
      c = substr(s, i, 1)
      if (c == "\\") { i++; out = out substr(s, i, 1); continue }
      if (c == "\"") return out
      out = out c
    }
    err("unterminated string: " s); return ""
  }
  sub(/[ \t]+#.*$/, "", s); sub(/[ \t]+$/, "", s)
  return s
}

# Shell single-quoting, for echoing a reason safely.
function sq(s) { gsub(/\047/, "\047\\\047\047", s); return "\047" s "\047" }

# A run command as a YAML block scalar under "run: |".
function block(cmd, indent,    n, lines, i, out) {
  n = split(cmd, lines, "\n"); out = ""
  for (i = 1; i <= n; i++) out = out indent lines[i] "\n"
  return out
}

# The "if:" condition for a list of triggers.
function cond(runs_on,    n, r, i, parts, p) {
  n = split(runs_on, r, /[ ,]+/); p = ""
  for (i = 1; i <= n; i++) {
    if (r[i] == "") continue
    if (r[i] == "change_request") parts = "github.event_name == \047pull_request\047"
    else if (r[i] == "merge") parts = "(github.event_name == \047push\047 && github.ref == \047refs/heads/" branch "\047)"
    else if (r[i] == "release") parts = "(github.event_name == \047push\047 && startsWith(github.ref, \047refs/tags/" prefix "\047))"
    else if (r[i] == "schedule") parts = "github.event_name == \047schedule\047"
    else { err("unknown runs_on value: " r[i]); continue }
    if (od && r[i] == "change_request") parts = prcond
    if (od && r[i] == "merge") continue   # on-demand: merges run nothing
    p = (p == "") ? parts : p " || " parts
  }
  if (od) p = (p == "") ? "github.event_name == \047workflow_dispatch\047" : p " || github.event_name == \047workflow_dispatch\047"
  return p
}

BEGIN { branch = "main"; prefix = "v"; nx = 0; ci = "always" }

{ line = $0 }
/^[ \t]*#/ || /^[ \t]*$/ { next }

/^[a-z_]+:/ {
  top = line; sub(/:.*$/, "", top); sec = ""
  if (top == "default_branch") { v = line; sub(/^[a-z_]+:/, "", v); branch = value(v) }
  next
}
top == "release" && /^  tag_prefix:/ { v = line; sub(/^  tag_prefix:/, "", v); prefix = value(v); next }
top != "pipeline" { next }

/^  ci:/ { v = line; sub(/^  ci:/, "", v); ci = value(v); sec = ""; next }
/^  stages:/ { sec = "stages"; next }
/^  extra_stages:/ {
  sec = "extra"; v = line; sub(/^  extra_stages:/, "", v); v = value(v)
  if (v != "" && v != "[]") err("extra_stages must be a list or []")
  next
}

sec == "stages" && /^    [a-z_]+:[ \t]*$/ { st = line; sub(/^    /, "", st); sub(/:.*$/, "", st); seen[st] = 1; next }
sec == "stages" && /^      [a-z_]+:/ {
  k = line; sub(/^      /, "", k); sub(/:.*$/, "", k)
  v = line; sub(/^      [a-z_]+:/, "", v); S[st, k] = value(v); next
}

sec == "extra" && /^    - name:/ { nx++; v = line; sub(/^    - name:/, "", v); X[nx, "name"] = value(v); next }
sec == "extra" && /^      [a-z_]+:/ {
  k = line; sub(/^      /, "", k); sub(/:.*$/, "", k)
  v = line; sub(/^      [a-z_]+:/, "", v); v = value(v)
  if (k == "runs_on") { if (v !~ /^\[.*\]$/) err(X[nx, "name"] ": runs_on must be a list like [change_request]"); gsub(/[\[\]]/, "", v) }
  X[nx, k] = v; next
}

{ err("unexpected line in the pipeline block: " line) }

END {
  if (ci != "always" && ci != "on-demand") err("pipeline.ci must be always or on-demand: " ci)
  od = (ci == "on-demand")
  # On-demand (conventions §11): a change request runs only with the ci:full
  # label or from a release branch. Adding a label starts a run only when the label
  # is ci:full, on a branch other than a release branch (which runs anyway).
  prcond = "(github.event_name == \047pull_request\047 && (contains(github.event.pull_request.labels.*.name, \047ci:full\047) || startsWith(github.head_ref, \047chore/release-\047)) && (github.event.action != \047labeled\047 || (github.event.label.name == \047ci:full\047 && !startsWith(github.head_ref, \047chore/release-\047))))"
  split("lint build unit integration", core, " ")
  for (i = 1; i <= 4; i++) {
    s = core[i]
    if (!(s in seen)) err("missing core stage " s)
    else if (S[s, "enabled"] == "true" && S[s, "run"] == "") err(s ": enabled but has no run command")
    else if (S[s, "enabled"] == "false" && S[s, "reason"] == "") err(s ": disabled but has no reason")
    else if (S[s, "enabled"] != "true" && S[s, "enabled"] != "false") err(s ": enabled must be true or false")
  }
  sched = 0; cron = ""
  for (j = 1; j <= nx; j++) {
    n = X[j, "name"]
    if (n !~ /^[a-z][a-z0-9-]*$/) err("extra stage name must be lower case letters, digits and hyphens: " n)
    if (n == "lint" || n == "build" || n == "unit" || n == "integration") err("extra stage " n " has a core stage name")
    if (X[j, "mode"] != "required" && X[j, "mode"] != "advisory") err(n ": mode must be required or advisory")
    if (X[j, "run"] == "") err(n ": has no run command")
    if (X[j, "runs_on"] == "") err(n ": has no runs_on")
    else cond(X[j, "runs_on"])   # reports unknown values before anything is printed
    if (X[j, "runs_on"] ~ /schedule/) { sched = 1; if (X[j, "cron"] != "" && cron == "") cron = X[j, "cron"] }
  }
  if (bad) exit 1
  if (cron == "") cron = "0 6 * * 1"

  print "# Generated by accept-the-plan from .project/config.yml (conventions §11)."
  print "# Do not edit by hand: change the config and render it again (accept-the-plan, or work-issue for a task that enables a stage)."
  print "name: pipeline"
  print ""
  print "on:"
  print "  pull_request:"
  if (od) print "    types: [opened, synchronize, reopened, labeled]"
  print "  push:"
  if (!od) print "    branches: [" branch "]"
  print "    tags: [\047" prefix "*\047]"
  if (od) print "  workflow_dispatch:"
  if (sched) { print "  schedule:"; print "    - cron: \047" cron "\047" }
  print ""
  print "permissions:"
  print "  contents: read"
  print ""
  if (od) {
    # A newer run of the same change request cancels the older one. A run
    # started by adding some other label skips every job, so it gets its own
    # group and never cancels a real run.
    print "concurrency:"
    print "  group: pipeline-${{ github.event.pull_request.number || github.ref }}-${{ (github.event.action == \047labeled\047 && (github.event.label.name != \047ci:full\047 || startsWith(github.head_ref, \047chore/release-\047))) && \047other-label\047 || \047run\047 }}"
    print "  cancel-in-progress: ${{ github.event_name == \047pull_request\047 }}"
    print ""
  }
  print "jobs:"

  # Core stages (conventions §11): lint on change requests; the rest on
  # change requests, merges to the default branch and release tags.
  for (i = 1; i <= 4; i++) {
    s = core[i]
    print "  " s ":"
    print "    name: " s
    if (S[s, "enabled"] == "false") print "    # Disabled: " S[s, "reason"]
    print "    if: " (s == "lint" ? cond("change_request") : cond("change_request,merge,release"))
    print "    runs-on: ubuntu-latest"
    print "    steps:"
    if (S[s, "enabled"] == "true") {
      print "      - uses: actions/checkout@v5"
      print "      - name: " s
      print "        shell: bash"
      print "        run: |"
      printf "%s", block(S[s, "run"], "          ")
    } else {
      print "      - name: " s " (skipped)"
      print "        shell: bash"
      print "        run: |"
      print "          echo " sq("skipped: " S[s, "reason"])
    }
    print ""
  }

  for (j = 1; j <= nx; j++) {
    n = X[j, "name"]
    print "  " n ":"
    print "    name: " n
    print "    # Extra stage: " X[j, "mode"] ", runs on " X[j, "runs_on"]
    print "    if: " cond(X[j, "runs_on"])
    print "    runs-on: ubuntu-latest"
    if (X[j, "mode"] == "advisory") print "    continue-on-error: true"
    print "    steps:"
    print "      - uses: actions/checkout@v5"
    print "      - name: " n
    print "        shell: bash"
    print "        run: |"
    printf "%s", block(X[j, "run"], "          ")
    print ""
  }
}
' "$config" | sed -e '$ { /^$/d; }'
