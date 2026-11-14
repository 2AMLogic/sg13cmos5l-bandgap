#!/usr/bin/env bash
# Fake-tree test for sim/tools/check-documented-figures.py. Needs only bash and
# python3: no PDK, no network, no ngspice. Run: bash sim/tests/test-documented-figures.sh
#
# Covers the four PR #98 error shapes (a count claim printing 3 where 4 corners
# satisfy the predicate; a range claim printing 0.40-0.60 where the span is
# 0.37-0.64; a pct_change claim printing one grid-wide value that holds at only
# one temperature; an extremum claim naming a corner that does not hold the
# extremum), each asserted to fail with the file, the claim and the expected
# value in the message; the exit-code contract (un-annotated in-scope document
# -> 0 with the gap reported, malformed annotation -> 1, missing cited envelope
# -> 1, unreadable manifest -> 2); unit scaling (V recorded -> uV / mV printed);
# single vs double rounding of a derived cell; and a real-tree run requiring
# exit 0 against the committed sim/closed-loop-psrr/README.md and manifest.
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tool="${root}/sim/tools/check-documented-figures.py"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
fails=0

# mkenv <path> <corners-json>: write a schema_version 3 envelope.
mkenv() {
  mkdir -p "$(dirname "$1")"
  python3 -I - "$1" "$2" <<'PY'
import json, sys
corners = json.loads(sys.argv[2])
json.dump({"schema_version": 3, "corner_count": len(corners), "corners": corners},
          open(sys.argv[1], "w"), indent=1)
PY
}

E1='[
 {"corner_id":"typ/3.300V/27C","process":"typ","supply_v":{"Vvdd":3.3},"temperature_c":27,"status":"pass",
  "measurements":[{"name":"m","unit":"V","value":10.0},{"name":"r","unit":"V","value":0.37},
                  {"name":"k","unit":"V","value":5.0},{"name":"m2","unit":"V","value":1.0}]},
 {"corner_id":"wcs/2.970V/125C","process":"wcs","supply_v":{"Vvdd":2.97},"temperature_c":125,"status":"fail",
  "measurements":[{"name":"m","unit":"V","value":20.0},{"name":"r","unit":"V","value":0.5},
                  {"name":"k","unit":"V","value":0.5},{"name":"m2","unit":"V","value":2.0}]},
 {"corner_id":"bcs/3.630V/27C","process":"bcs","supply_v":{"Vvdd":3.63},"temperature_c":27,"status":"pass",
  "measurements":[{"name":"m","unit":"V","value":30.0},{"name":"r","unit":"V","value":0.64},
                  {"name":"k","unit":"V","value":6.0},{"name":"m2","unit":"V","value":3.0}]},
 {"corner_id":"fs/2.970V/125C","process":"fs","supply_v":{"Vvdd":2.97},"temperature_c":125,"status":"fail",
  "measurements":[{"name":"m","unit":"V","value":40.0},{"name":"r","unit":"V","value":0.5},
                  {"name":"k","unit":"V","value":7.0},{"name":"m2","unit":"V","value":4.0}]},
 {"corner_id":"sf/3.300V/-40C","process":"sf","supply_v":{"Vvdd":3.3},"temperature_c":-40,"status":"pass",
  "measurements":[{"name":"m","unit":"V","value":1.0},{"name":"r","unit":"V","value":0.37},
                  {"name":"k","unit":"V","value":8.0},{"name":"m2","unit":"V","value":5.0}]}]'

E2='[
 {"corner_id":"typ/27C","process":"typ","supply_v":{"Vvdd":3.3},"temperature_c":27,"status":"pass",
  "measurements":[{"name":"g","unit":"V","value":0.649461}]}]'

E3='[
 {"corner_id":"ref/27C","process":"ref","supply_v":{"Vvdd":3.3},"temperature_c":27,"status":"pass",
  "measurements":[{"name":"x","unit":"V","value":1.0}]},
 {"corner_id":"p/27C","process":"p","supply_v":{"Vvdd":3.3},"temperature_c":27,"status":"pass",
  "measurements":[{"name":"x","unit":"V","value":1.247}]},
 {"corner_id":"p/125C","process":"p","supply_v":{"Vvdd":3.3},"temperature_c":125,"status":"pass",
  "measurements":[{"name":"x","unit":"V","value":1.52}]},
 {"corner_id":"p/5C","process":"p","supply_v":{"Vvdd":3.3},"temperature_c":5,"status":"pass",
  "measurements":[{"name":"x","unit":"V","value":-0.5}]}]'

E4='[
 {"corner_id":"a","process":"typ","supply_v":{"Vvdd":3.3},"temperature_c":27,"status":"pass",
  "measurements":[{"name":"dvref","unit":"V","value":-6.86348215271e-05}]},
 {"corner_id":"b","process":"typ","supply_v":{"Vvdd":3.3},"temperature_c":125,"status":"pass",
  "measurements":[{"name":"dvref","unit":"V","value":0.0001728075273892}]}]'

for e in 1 2 3 4; do
  var="E${e}"; mkenv "${tmp}/envs/e${e}.json" "${!var}"
done

# mkcase <name> <env-basename>: fake repo tree with a manifest naming one
# document; echoes the tree dir. The document itself is written per case.
mkcase() {
  local d="${tmp}/$1"
  mkdir -p "${d}/sim/bench/envelopes"
  cp "${tmp}/envs/$2" "${d}/sim/bench/envelopes/cited.json"
  cat > "${d}/sim/documented-figures.json" <<'JSON'
{"schema_version": 1, "documents": [{"path": "sim/bench/README.md"}]}
JSON
  echo "${d}"
}

# expect <label> <tree-dir> <exit-code> [output-substring]
expect() {
  local out rc
  out="$(cd "$2" && python3 -I "${tool}" 2>&1)"; rc=$?
  if [[ ${rc} -eq $3 && ( -z "${4:-}" || "${out}" == *"$4"* ) ]]; then
    echo "PASS $1"
  else
    echo "FAIL $1 (want rc=$3 ${4:+containing '$4'}, got rc=${rc}): ${out}"; fails=$((fails+1))
  fi
}

# expect3 <label> <tree-dir> <exit-code> <file> <claim> <expected>
# The four PR #98 error shapes must name all three in the message.
expect3() {
  local out rc ok=1
  out="$(cd "$2" && python3 -I "${tool}" 2>&1)"; rc=$?
  for s in "$4" "$5" "$6"; do [[ "${out}" == *"$s"* ]] || ok=0; done
  if [[ ${rc} -eq $3 && ${ok} -ne 0 ]]; then
    echo "PASS $1"
  else
    echo "FAIL $1 (want rc=$3 containing '$4' + '$5' + '$6', got rc=${rc}): ${out}"; fails=$((fails+1))
  fi
}

MANIFEST_ERROR_PREFIX="check-documented-figures: ERROR cannot read manifest"

# ---- PR #98 error shape 1: double rounding of a derived cell -----------------
d="$(mkcase cell-round e2.json)"
cat > "${d}/sim/bench/README.md" <<'EOF'
<!-- figure: {"envelope":"envelopes/cited.json","kind":"cell","corner":"typ/27C","measurement":"g","printed":{"value":"0.649","unit":"V"}} -->
The got value is 0.649 V at the typ corner.
EOF
expect "cell rounded once from full precision passes" "${d}" 0

cat > "${d}/sim/bench/README.md" <<'EOF'
<!-- figure: {"envelope":"envelopes/cited.json","kind":"cell","corner":"typ/27C","measurement":"g","printed":{"value":"0.650","unit":"V"}} -->
The got value is 0.650 V at the typ corner.
EOF
expect3 "double-rounded cell rejected, names file+claim+expected" "${d}" 1 \
  "sim/bench/README.md" "cell g" "expected 0.649"

# ---- PR #98 error shape 2: a range that is not the subset's min/max ----------
d="$(mkcase range e1.json)"
cat > "${d}/sim/bench/README.md" <<'EOF'
<!-- figure: {"envelope":"envelopes/cited.json","kind":"range","measurement":"r","subset":{},"printed":{"min":"0.40","max":"0.60","unit":"V"}} -->
The error span is 0.40 V to 0.60 V.
EOF
expect3 "coarsened range rejected, names file+claim+expected" "${d}" 1 \
  "sim/bench/README.md" "range r" "expected 0.64"
cat > "${d}/sim/bench/README.md" <<'EOF'
<!-- figure: {"envelope":"envelopes/cited.json","kind":"range","measurement":"r","subset":{},"printed":{"min":"0.37","max":"0.64","unit":"V"}} -->
The error span is 0.37 V to 0.64 V.
EOF
expect "exact range passes" "${d}" 0

# ---- PR #98 error shape 3: a count that does not match the predicate ---------
d="$(mkcase count e1.json)"
cat > "${d}/sim/bench/README.md" <<'EOF'
<!-- figure: {"envelope":"envelopes/cited.json","kind":"count","measurement":"m","subset":{},"predicate":{"op":">","value":5,"unit":"V"},"printed":{"value":"3"}} -->
The same three points exceed 5 V.
EOF
expect3 "count printing 3 where 4 satisfy, names file+claim+expected" "${d}" 1 \
  "sim/bench/README.md" "count m" "expected 4"
cat > "${d}/sim/bench/README.md" <<'EOF'
<!-- figure: {"envelope":"envelopes/cited.json","kind":"count","measurement":"m","subset":{},"predicate":{"op":">","value":5,"unit":"V"},"printed":{"value":"4"}} -->
4 points exceed 5 V.
EOF
expect "count corrected to 4 passes" "${d}" 0
cat > "${d}/sim/bench/README.md" <<'EOF'
<!-- figure: {"envelope":"envelopes/cited.json","kind":"count","measurement":"m","subset":{},"predicate":{"op":">","value":5,"unit":"V"},"printed":{"value":"4/5"}} -->
4/5 points exceed 5 V.
EOF
expect "count-of-total form passes" "${d}" 0
cat > "${d}/sim/bench/README.md" <<'EOF'
<!-- figure: {"envelope":"envelopes/cited.json","kind":"count","subset":{},"status":"pass","printed":{"value":"3/5"}} -->
3/5 points pass.
EOF
expect "count by corner status passes" "${d}" 0
cat > "${d}/sim/bench/README.md" <<'EOF'
<!-- figure: {"envelope":"envelopes/cited.json","kind":"count","measurement":"m","subset":{"corner_id":"*/125C"},"predicate":{"op":">","value":5,"unit":"V"},"printed":{"value":"2"}} -->
Two of the 125C points exceed 5 V.
EOF
expect "corner_id glob subset passes" "${d}" 0
cat > "${d}/sim/bench/README.md" <<'EOF'
<!-- figure: {"envelope":"envelopes/cited.json","kind":"count","measurement":"m","subset":{"process":"nope"},"predicate":{"op":">","value":5,"unit":"V"},"printed":{"value":"1"}} -->
One nope point exceeds 5 V.
EOF
expect "empty subset counts zero and fails the claim" "${d}" 1 "expected 0"

# ---- PR #98 error shape 4a: grid-wide pct_change true at one temperature -----
d="$(mkcase pct e3.json)"
cat > "${d}/sim/bench/README.md" <<'EOF'
<!-- figure: {"envelope":"envelopes/cited.json","kind":"pct_change","measurement":"x","subset":{"process":"p"},"from":{"process":"ref"},"direction":"rise","printed":{"value":"25","unit":"%"}} -->
Over-tracking rises ~25 % grid-wide.
EOF
expect3 "grid-wide pct_change rejected where it holds at one temperature" "${d}" 1 \
  "sim/bench/README.md" "pct_change x" "expected 52"

cat > "${d}/sim/bench/README.md" <<'EOF'
<!-- figure: {"envelope":"envelopes/cited.json","kind":"pct_change","measurement":"x","subset":{"process":"p"},"from":{"process":"ref"},"per":"temperature_c","printed":{"values":{"27":"25","125":"52"},"unit":"%"}} -->
Over-tracking rises ~25 % at 27C and ~52 % at 125C.
EOF
expect "pct_change split by per requires the missing group and fails" "${d}" 1 \
  "no entry for temperature_c=5"

cat > "${d}/sim/bench/README.md" <<'EOF'
<!-- figure: {"envelope":"envelopes/cited.json","kind":"pct_change","measurement":"x","subset":{"process":"p"},"from":{"process":"ref"},"per":"temperature_c","printed":{"values":{"27":"25","125":"52","5":"-150"},"unit":"%"}} -->
Over-tracking rises ~25 % at 27C, ~52 % at 125C and falls −150 % at 5C.
EOF
expect "pct_change split per temperature passes once the sign change is named" "${d}" 0

cat > "${d}/sim/bench/README.md" <<'EOF'
<!-- figure: {"envelope":"envelopes/cited.json","kind":"pct_change","measurement":"x","subset":{"process":"p"},"from":{"process":"ref"},"direction":"rise","per":"temperature_c","printed":{"values":{"27":"25","125":"52","5":"-150"},"unit":"%"}} -->
Over-tracking rises at every point.
EOF
expect "direction rise rejected when a corner falls" "${d}" 1 "claimed rise but x falls at p/5C"

# ---- PR #98 error shape 4b: extremum attributed to the wrong corner ----------
d="$(mkcase extremum e1.json)"
cat > "${d}/sim/bench/README.md" <<'EOF'
<!-- figure: {"envelope":"envelopes/cited.json","kind":"extremum","measurement":"m2","extremum":"min","subset":{},"printed":{"value":"1.0","unit":"V","corner":"wcs/2.970V/125C"}} -->
Worst m2 is 1.0 V at wcs/2.970V/125C.
EOF
expect3 "extremum naming a corner that does not hold it" "${d}" 1 \
  "sim/bench/README.md" "extremum m2 min" "typ/3.300V/27C"

cat > "${d}/sim/bench/README.md" <<'EOF'
<!-- figure: {"envelope":"envelopes/cited.json","kind":"extremum","measurement":"m2","extremum":"min","subset":{},"keyed_to":"k","printed":{"value":"2.0","unit":"V","corner":"wcs/2.970V/125C"}} -->
Worst m2 is 2.0 V at wcs/2.970V/125C, the corner that holds the k minimum.
EOF
expect "extremum passes once keyed_to declares the quantity it is keyed to" "${d}" 0

# ---- exit-code contract ------------------------------------------------------
d="$(mkcase unannotated e1.json)"
printf 'A document that cites an envelope (envelopes/cited.json) but has no annotations yet: 1.5 V.\n' > "${d}/sim/bench/README.md"
expect "un-annotated in-scope document exits 0 with the gap reported" "${d}" 0 \
  "0/0 annotation(s) verified"

d="$(mkcase malformed e1.json)"
cat > "${d}/sim/bench/README.md" <<'EOF'
<!-- figure: {"kind":"wAT"} -->
A malformed annotation: 1.5 V.
EOF
expect "malformed annotation exits 1" "${d}" 1 "figure #1"

d="$(mkcase noenv e1.json)"
cat > "${d}/sim/bench/README.md" <<'EOF'
<!-- figure: {"envelope":"envelopes/missing.json","kind":"count","subset":{},"printed":{"value":"5"}} -->
Five points: 1.5 V.
EOF
expect "missing cited envelope exits 1" "${d}" 1 "cited envelope missing"

d="$(mkcase absent e1.json)"
cat > "${d}/sim/bench/README.md" <<'EOF'
<!-- figure: {"envelope":"envelopes/cited.json","kind":"range","measurement":"nope","subset":{},"printed":{"min":"0.37","max":"0.64"}} -->
A measurement the envelope does not carry: 0.37 to 0.64.
EOF
expect "measurement absent from cited envelope exits 1" "${d}" 1 "absent from"

d="$(mkcase unreadable e1.json)"
printf 'not json {' > "${d}/sim/documented-figures.json"
expect "unreadable manifest exits 2" "${d}" 2 "${MANIFEST_ERROR_PREFIX}"

# ---- unit scaling ------------------------------------------------------------
d="$(mkcase uv e4.json)"
cat > "${d}/sim/bench/README.md" <<'EOF'
<!-- figure: {"envelope":"envelopes/cited.json","kind":"range","measurement":"dvref","subset":{},"printed":{"min":"-68.6","max":"+172.8","unit":"µV"}} -->
The residual spans −68.6 µV … +172.8 µV.
EOF
expect "range with V recorded and µV printed passes" "${d}" 0

cat > "${d}/sim/bench/README.md" <<'EOF'
<!-- figure: {"envelope":"envelopes/cited.json","kind":"range","measurement":"dvref","subset":{},"printed":{"min":"-68.6348","max":"+172.8075","unit":"mV"}} -->
The residual spans -68.6348 mV to 172.8075 mV.
EOF
expect "wrong-scale unit rejected" "${d}" 1 "expected -0.0686"

# ---- real committed tree -----------------------------------------------------
expect "real committed tree verifies (closed-loop-psrr annotated)" "${root}" 0 \
  "sim/closed-loop-psrr/README.md: 18/18 annotation(s) verified"

if [[ ${fails} -ne 0 ]]; then echo "${fails} case(s) FAILED"; exit 1; fi
echo "all cases passed"
