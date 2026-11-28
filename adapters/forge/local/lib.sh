#!/usr/bin/env bash
# The local forge: functions shared by forge.sh and merge.sh. Not run on its own.
#
# Change requests are records in the local tracker's store (decision 0027):
#
#   crs/NNNN.md   "Key: value" header lines, a blank line, then the body
#
#   Number, Title, State (open | closed | merged), Head, Base, Created, Labels,
#   Merged (UTC date), Merge-Commit, Closes (the issues the merge closed)
#
# Numbers come from the store's shared counter, so a change request and an
# issue never share a number, as on GitHub.

here_lib="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=adapters/tracker/local/store.sh
. "$here_lib/../../tracker/local/store.sh"

cr_file() { printf '%s/crs/%04d.md' "$STORE" "$1"; }

# All change request numbers, in order.
cr_numbers() {
  local f
  for f in "$STORE"/crs/*.md; do
    [[ -f $f ]] || continue
    f=$(basename "$f" .md); printf '%d\n' "$((10#$f))"
  done
}

# cr_find <number | head-branch> [any]: the record's number. A branch finds its
# open change request, or with "any" its latest one in any state.
cr_find() {
  local n f found=""
  if [[ $1 =~ ^[0-9]+$ ]]; then
    [[ -f $(cr_file "$1") ]] || die "no change request #$1 in $STORE"
    printf '%s\n' "$1"; return
  fi
  for n in $(cr_numbers); do
    f=$(cr_file "$n")
    [[ $(rec_get "$f" Head) == "$1" ]] || continue
    if [[ $(rec_get "$f" State) == open || ${2:-} == any ]]; then found=$n; fi
  done
  [[ -n $found ]] || die "no change request for branch $1"
  printf '%s\n' "$found"
}

# closes_from_body: issue numbers after a closing keyword, as GitHub reads them:
# close(s|d), fix(es|ed), resolve(s|d), in any case, an optional colon, then #N.
closes_from_body() {
  awk '{
    s = tolower($0)
    while (match(s, /(close[sd]?|fix(e[sd])?|resolve[sd]?):?[ \t]*#[0-9]+/)) {
      before = (RSTART > 1) ? substr(s, RSTART - 1, 1) : " "
      hit = substr(s, RSTART, RLENGTH)
      s = substr(s, RSTART + RLENGTH)
      if (before ~ /[a-z0-9_]/) continue
      sub(/^[^#]*#/, "", hit)
      if (!(hit in seen)) { seen[hit] = 1; printf "%s%s", (n++ ? " " : ""), hit }
    }
  } END { if (n) print "" }'
}

# closes_issues <body-file>: the closing references that name an issue in the store.
closes_issues() {
  local n out=""
  for n in $(closes_from_body < "$1"); do
    [[ -f $(printf '%s/issues/%04d.md' "$STORE" "$n") ]] && out="${out:+$out }$n"
  done
  printf '%s\n' "$out"
}

# stage_lookup <config> <stage>: one line, "enabled<TAB><run>", "disabled<TAB><reason>"
# or "missing", from the config's pipeline block (core stages and extra_stages).
stage_lookup() {
  awk -v want="$2" '
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
        return out
      }
      sub(/[ \t]+#.*$/, "", s); sub(/[ \t]+$/, "", s)
      return s
    }
    /^[ \t]*#/ || /^[ \t]*$/ { next }
    /^[a-z_]+:/ { top = $0; sub(/:.*$/, "", top); sec = ""; next }
    top != "pipeline" { next }
    /^  stages:/ { sec = "stages"; next }
    /^  extra_stages:/ { sec = "extra"; next }
    /^  [a-z_]+:/ { sec = ""; next }
    sec == "stages" && /^    [a-z0-9_-]+:[ \t]*$/ { st = $0; sub(/^    /, "", st); sub(/:.*$/, "", st); next }
    sec == "stages" && /^      [a-z_]+:/ {
      k = $0; sub(/^      /, "", k); sub(/:.*$/, "", k)
      v = $0; sub(/^      [a-z_]+:/, "", v); S[st, k] = value(v); have[st] = 1; next
    }
    sec == "extra" && /^    - name:/ { v = $0; sub(/^    - name:/, "", v); st = value(v); have[st] = 1; S[st, "enabled"] = "true"; next }
    sec == "extra" && /^      [a-z_]+:/ {
      k = $0; sub(/^      /, "", k); sub(/:.*$/, "", k)
      v = $0; sub(/^      [a-z_]+:/, "", v); S[st, k] = value(v); next
    }
    END {
      if (!(want in have)) { print "missing"; exit }
      if (S[want, "enabled"] == "true") print "enabled\t" S[want, "run"]
      else print "disabled\t" S[want, "reason"]
    }' "$1"
}

# required_stages <project>: the stages rule.require-checks recorded, or the
# four core stages if it hasn't run.
required_stages() {
  local s; s=$(git -C "$1" config --get i2r.requiredchecks || true)
  printf '%s\n' "${s:-lint build unit integration}"
}

# run_stages <config> <folder> <log-dir> <stage>...: run each stage's command in
# <folder>, printing "<stage>: pass", "<stage>: pass (placeholder)" or
# "<stage>: fail". Returns 1 if any failed or is missing from the config.
run_stages() {
  local config=$1 dir=$2 logs=$3 st info kind cmd status=0; shift 3
  for st in "$@"; do
    info=$(stage_lookup "$config" "$st")
    kind=${info%%$'\t'*}; cmd=${info#*$'\t'}
    case $kind in
      missing) printf '%s: fail (not in the config)\n' "$st"; status=1 ;;
      disabled) printf '%s: pass (placeholder: %s)\n' "$st" "$cmd" ;;
      enabled)
        if [[ -z $cmd ]]; then printf '%s: fail (enabled with no run command)\n' "$st"; status=1
        elif (cd "$dir" && bash -c "$cmd") > "$logs/$st.log" 2>&1; then printf '%s: pass\n' "$st"
        else printf '%s: fail (log: %s)\n' "$st" "$logs/$st.log"; status=1; fi ;;
    esac
  done
  return $status
}

# stage_list <config>: every stage in config order, one tab-separated line each:
# name, enabled (true|false), mode (required|advisory), runs_on (space-separated),
# then the run command or the reason. Core stages are required, and run where
# conventions §11 says: lint on change requests, the others on change
# requests, merges and releases. Errors in the block go to stderr, with status 1.
stage_list() {
  awk '
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
        return out
      }
      sub(/[ \t]+#.*$/, "", s); sub(/[ \t]+$/, "", s)
      return s
    }
    function err(m) { print "error: " m > "/dev/stderr"; bad = 1 }
    /^[ \t]*#/ || /^[ \t]*$/ { next }
    /^[a-z_]+:/ { top = $0; sub(/:.*$/, "", top); sec = ""; next }
    top != "pipeline" { next }
    /^  stages:/ { sec = "stages"; next }
    /^  extra_stages:/ { sec = "extra"; next }
    /^  [a-z_]+:/ { sec = ""; next }
    sec == "stages" && /^    [a-z0-9_-]+:[ \t]*$/ { st = $0; sub(/^    /, "", st); sub(/:.*$/, "", st); order[++n] = st; next }
    sec == "stages" && /^      [a-z_]+:/ {
      k = $0; sub(/^      /, "", k); sub(/:.*$/, "", k)
      v = $0; sub(/^      [a-z_]+:/, "", v); S[st, k] = value(v); next
    }
    sec == "extra" && /^    - name:/ { v = $0; sub(/^    - name:/, "", v); st = value(v); order[++n] = st; X[st] = 1; S[st, "enabled"] = "true"; next }
    sec == "extra" && /^      [a-z_]+:/ {
      k = $0; sub(/^      /, "", k); sub(/:.*$/, "", k)
      v = $0; sub(/^      [a-z_]+:/, "", v); v = value(v)
      if (k == "runs_on") { gsub(/[\[\],]/, " ", v); gsub(/  +/, " ", v); sub(/^ /, "", v); sub(/ $/, "", v) }
      S[st, k] = v; next
    }
    END {
      split("lint build unit integration", core, " ")
      for (i = 1; i <= 4; i++) { found = 0; for (j = 1; j <= n; j++) if (order[j] == core[i]) found = 1; if (!found) err("the core stage " core[i] " is missing from the pipeline block") }
      for (j = 1; j <= n; j++) {
        st = order[j]; en = S[st, "enabled"]
        if (X[st]) {
          mode = S[st, "mode"]; runs = S[st, "runs_on"]
          if (mode != "required" && mode != "advisory") err(st ": mode must be required or advisory")
          if (runs == "") err(st ": runs_on is missing")
          if (S[st, "run"] == "") err(st ": an extra stage needs a run command")
        } else {
          mode = "required"; runs = (st == "lint") ? "change_request" : "change_request merge release"
          if (en != "true" && en != "false") err(st ": enabled must be true or false")
          if (en == "true" && S[st, "run"] == "") err(st ": an enabled stage needs a run command")
          if (en == "false" && S[st, "reason"] == "") err(st ": a disabled stage needs a reason")
        }
        print st "\t" en "\t" mode "\t" runs "\t" (en == "true" ? S[st, "run"] : S[st, "reason"])
      }
      exit bad
    }' "$1"
}
