#!/usr/bin/env bash
# Fixture test for design/tools/netlist_pin_delta.py, the normalization T1 item 1's
# freshness gate rests on. Needs only bash and python3: no PDK, no klt, no xschem, no
# network, so CI runs it on every push.
#
#   bash design/tests/test-netlist-pin-delta.sh
#
# The point of the suite is the negative controls. A tolerance is only worth having if
# it is narrow, so every case below that SHOULD fail is at least as important as the
# ones that should pass: `mm_ok` at any value other than 1, `mm_ok` on a device model
# outside the classified set, a changed port order (the xschem 3.4.4-vs-3.4.7 export
# difference ruled on in sg13g2-bandgap#441/#442), a resized or deleted device, a
# renamed net and an added blank line all have to read as DRIFT. If one of them ever
# reads as fresh, the gate has stopped testing what T1 item 1 is about.
#
# The last check is PDK-free but not a fixture: it re-derives from the committed
# netlists that they carry no `mm_ok` token at all, which is the premise the whole
# normalization rests on (they were exported at the archived PDK pin). If a future
# commit regenerates them at this repo's pin, that premise is gone and this fails
# rather than letting the tolerance silently become a no-op.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tool="${root}/design/tools/netlist_pin_delta.py"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
fails=0

pass() { echo "PASS $1"; }
fail() { echo "FAIL $1: ${2:-}"; fails=$((fails + 1)); }

# expect <label> <want-rc> <committed> <regenerated>
expect() {
  local label="$1" want="$2" a="$3" b="$4" out rc
  out="$(python3 -I "${tool}" --committed "${a}" --regenerated "${b}" 2>&1)"; rc=$?
  if [[ ${rc} -eq ${want} ]]; then
    pass "${label}"
  else
    fail "${label}" "want rc=${want}, got rc=${rc}: ${out}"
  fi
}

# ---- the baseline: an xschem export shaped like this block's own cells --------------
cat > "${tmp}/committed.spice" <<'SPICE'
** sch_path: /Users/someone/GitHub/sg13g2-bandgap/.loom/worktrees/issue-73/design/sg13cmos5l/cell.sch
**.subckt cell vdd vss fb vref

*.iopin vdd
*.iopin vss
*.iopin fb
*.iopin vref
XM1 sns1 fb vdd vdd sg13_hv_pmos w=10u l=1u ng=1 m=1
XQ1 vss vss sns1 pnpMPA a={ 1u * 2u } p={ ( 1u + 2u ) * 2 } m=1
XR1 vref e3 sub! rppd w=2u l=647.0u m=1 b=0
XRPU vdd det sub! rhigh w=1u l=1411.3u m=1 b=0
XMN1 det sns1 vss vss sg13_hv_nmos w=10u l=0.5u ng=1 m=1
**.ends
.end
SPICE

# Same circuit as this repo's PDK pin exports it: a different provenance header, klt's
# own inputs line, and `mm_ok=1` on each of the four classified device models.
cat > "${tmp}/fresh-ok.spice" <<'SPICE'
** klt-netlist-inputs: {"pdk_variant": "ihp-sg13cmos5l", "rcfile": "xschemrc", "xschem_version": "3.4.7"}
** sch_path: design/sg13cmos5l/cell.sch
**.subckt cell vdd vss fb vref

*.iopin vdd
*.iopin vss
*.iopin fb
*.iopin vref
XM1 sns1 fb vdd vdd sg13_hv_pmos w=10u l=1u ng=1 m=1 mm_ok=1
XQ1 vss vss sns1 pnpMPA a={ 1u * 2u } p={ ( 1u + 2u ) * 2 } m=1
XR1 vref e3 sub! rppd w=2u l=647.0u m=1 b=0 mm_ok=1
XRPU vdd det sub! rhigh w=1u l=1411.3u m=1 b=0 mm_ok=1
XMN1 det sns1 vss vss sg13_hv_nmos w=10u l=0.5u ng=1 m=1 mm_ok=1
**.ends
.end
SPICE

expect "identical files are fresh" 0 "${tmp}/committed.spice" "${tmp}/committed.spice"
expect "the classified pin delta plus header churn is fresh" 0 \
  "${tmp}/committed.spice" "${tmp}/fresh-ok.spice"

# The tolerance it applied has to be visible, not silent.
got="$(python3 -I "${tool}" --committed "${tmp}/committed.spice" \
         --regenerated "${tmp}/fresh-ok.spice" --format json)"
if [[ "$(printf '%s' "${got}" | python3 -I -c 'import json,sys; d=json.load(sys.stdin); print(d["normalization"]["tolerated_tokens"]["regenerated"])')" == "4" ]]; then
  pass "the four tolerated tokens are counted and reported"
else
  fail "the four tolerated tokens are counted and reported" "${got}"
fi

# ---- negative controls: each of these MUST read as drift ----------------------------

# A real resize riding along with the tolerated token.
sed 's/^XM1 \(.*\)w=10u l=1u \(.*\)$/XM1 \1w=20u l=1u \2/' "${tmp}/fresh-ok.spice" \
  > "${tmp}/fresh-resized.spice"
expect "a device resize beside the pin delta is drift" 1 \
  "${tmp}/committed.spice" "${tmp}/fresh-resized.spice"

# mm_ok at a value other than 1 is a different statement about mismatch.
sed 's/ mm_ok=1/ mm_ok=0/' "${tmp}/fresh-ok.spice" > "${tmp}/fresh-mmzero.spice"
expect "mm_ok=0 is drift, not the classified delta" 1 \
  "${tmp}/committed.spice" "${tmp}/fresh-mmzero.spice"
sed 's/ mm_ok=1/ mm_ok=2/' "${tmp}/fresh-ok.spice" > "${tmp}/fresh-mmtwo.spice"
expect "mm_ok=2 is drift" 1 "${tmp}/committed.spice" "${tmp}/fresh-mmtwo.spice"

# mm_ok on a model outside the classified set -- here the bipolar, the device this
# block's accuracy actually turns on -- is never tolerated.
sed 's/^\(XQ1 .*m=1\)$/\1 mm_ok=1/' "${tmp}/fresh-ok.spice" > "${tmp}/fresh-mmbip.spice"
expect "mm_ok=1 on an unclassified model (pnpMPA) is drift" 1 \
  "${tmp}/committed.spice" "${tmp}/fresh-mmbip.spice"

# The port-order export difference ruled on in sg13g2-bandgap#441/#442 lives on a
# COMMENT line (`**.subckt`), so it would vanish if the gate dropped comments wholesale.
sed 's/^\*\*\.subckt cell vdd vss fb vref$/**.subckt cell fb vref vdd vss/' \
  "${tmp}/fresh-ok.spice" > "${tmp}/fresh-ports.spice"
expect "a reordered subckt port list is drift even though it is a comment line" 1 \
  "${tmp}/committed.spice" "${tmp}/fresh-ports.spice"

# A dropped device, a renamed net, a changed multiplier, an added blank line.
grep -v '^XRPU ' "${tmp}/fresh-ok.spice" > "${tmp}/fresh-dropped.spice"
expect "a deleted device card is drift" 1 "${tmp}/committed.spice" "${tmp}/fresh-dropped.spice"
sed 's/\bsns1\b/sns9/g' "${tmp}/fresh-ok.spice" > "${tmp}/fresh-net.spice"
expect "a renamed net is drift" 1 "${tmp}/committed.spice" "${tmp}/fresh-net.spice"
sed 's/^\(XR1 .*\)m=1 b=0 mm_ok=1$/\1m=8 b=0 mm_ok=1/' "${tmp}/fresh-ok.spice" \
  > "${tmp}/fresh-mult.spice"
expect "a changed device multiplier is drift" 1 "${tmp}/committed.spice" "${tmp}/fresh-mult.spice"
sed '5a\
' "${tmp}/fresh-ok.spice" > "${tmp}/fresh-blank.spice"
expect "an added blank line is drift" 1 "${tmp}/committed.spice" "${tmp}/fresh-blank.spice"

# A non-provenance comment is content, not churn.
sed 's|^\*\* sch_path: design/sg13cmos5l/cell.sch$|** a hand-added note|' \
  "${tmp}/fresh-ok.spice" > "${tmp}/fresh-comment.spice"
expect "an added non-provenance comment is drift" 1 \
  "${tmp}/committed.spice" "${tmp}/fresh-comment.spice"

expect "an unreadable file is a usage error" 2 "${tmp}/nonexistent.spice" "${tmp}/fresh-ok.spice"

# ---- the premise, re-derived from the committed netlists (no PDK needed) ------------
if python3 -I - "${root}" <<'PY'
import glob, os, sys

root = sys.argv[1]
nets = sorted(glob.glob(os.path.join(root, "design/sg13cmos5l/netlist/*.spice")))
bad = []
if len(nets) != 4:
    bad.append("expected 4 committed netlists, found %d" % len(nets))
for path in nets:
    body = open(path, encoding="utf-8").read()
    if "mm_ok" in body:
        bad.append("%s already carries mm_ok: the archived-pin premise of the "
                   "normalization no longer holds (see decision record 0015)"
                   % os.path.relpath(path, root))
for line in bad:
    print("  " + line)
sys.exit(1 if bad else 0)
PY
then
  pass "the committed netlists carry no mm_ok token (archived-pin premise holds)"
else
  fail "the committed netlists carry no mm_ok token (archived-pin premise holds)"
fi

echo
if [[ ${fails} -eq 0 ]]; then
  echo "All checks passed."
  exit 0
fi
echo "${fails} check(s) failed."
exit 1
