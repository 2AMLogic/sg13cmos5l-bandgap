#!/usr/bin/env bash
# Fixture test for sim/tools/pex_device_inventory.py (issue #32), plus a re-derivation of the
# committed T1-item-7 record's own device inventory from the two netlists it names. Needs only
# bash and python3: no PDK, no klt, no ngspice, no network.
#
#   bash sim/tests/test-pex-device-inventory.sh
#
# The last check is the load-bearing one. The item-7 record's central claim -- that the
# extracted netlist is missing the bandgap core's three `pnpMPA` devices, so no `klt pex` delta
# row can be graded -- is re-derived here from the committed extracted netlist and the
# committed schematic DUT, and compared against what the record says. A record edited by hand,
# an extracted netlist swapped under it, or a design change that adds or removes a device
# without a fresh run all fail here rather than being believed.
#
# Negative controls (each run while writing it): deleting one `XQ` card from the schematic
# fixture flips "drops a device class" to reporting 2 units instead of 10; renaming the
# extracted fixture's `.SUBCKT` makes the --extracted-top lookup exit 2; and editing the
# committed record's `difference.schematic_only` fails the last check.
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tool="${root}/sim/tools/pex_device_inventory.py"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
fails=0

pass() { echo "PASS $1"; }
fail() { echo "FAIL $1: ${2:-}"; fails=$((fails + 1)); }

# expect <label> <want-rc> <substring> -- <args to the tool>
expect() {
  local label="$1" want="$2" needle="$3"; shift 4
  local out rc
  out="$(python3 -I "${tool}" "$@" 2>&1)"; rc=$?
  if [[ ${rc} -eq ${want} && ( -z "${needle}" || "${out}" == *"${needle}"* ) ]]; then
    pass "${label}"
  else
    # shellcheck disable=SC2016  # the quotes are literal; ${needle} is inside double quotes.
    fail "${label}" "want rc=${want}${needle:+ containing '${needle}'}, got rc=${rc}: ${out}"
  fi
}

# ---- fixtures: a hierarchical schematic export and flat `.SUBCKT` extractions --------------
# Shaped like this repo's own pair: the schematic top is FLAT (an xschem export whose
# `.subckt` top line is commented out) and calls sub-blocks that define their own devices,
# while `klt extract` output is always one flat `.SUBCKT`.
cat > "${tmp}/schematic.spice" <<'SPICE'
** sch_path: /fixture/top.sch
**.subckt top vdd vss out
Xx1 vdd vss out core
**.ends

.subckt core vdd vss out
XM1 out g vdd vdd pfet w=10u l=1u m=1
XM2 out g vss vss nfet w=10u l=1u m=1
XQ1 vss vss out bip a={ 1u * 2u } m=1
XQ2 vss vss e2 bip a={ 1u * 2u } m=8
XQ3 vss vss e3 bip a={ 1u * 2u } m=1
XR1 out e3 vss poly w=2u l=10u m=1
.ends
.end
SPICE

# The same devices, flat and `.SUBCKT`-wrapped, with parasitic R/C cards beside them.
cat > "${tmp}/extracted-full.spice" <<'SPICE'
* extracted by a fixture
.GLOBAL vsubs
.SUBCKT top vdd vss out
X$1 out__t0 g__t0 vdd__t0 vdd__t1 pfet L=1U W=10U
X$2 out__t1 g__t1 vss__t0 vss__t1 nfet L=1U W=10U
Q$3 vss vss out bip
Q$4 vss vss e2 bip m=8
Q$5 vss vss e3 bip
X$6 out__t2 e3__t0 vss__t2 poly r=1234.5 L=10U W=2U
Rout_t0 out__t0 out 8.5
Cout out vsubs 5.6e-15
Rvsubs_dctie vsubs 0 1e+12
.ENDS top
SPICE

# The real shape this repo hits: the extraction deck recognises no bipolar, so every `bip` is
# simply absent -- not flagged, not a zero-valued device, gone.
sed '/ bip/d' "${tmp}/extracted-full.spice" > "${tmp}/extracted-nobip.spice"
# Same model set, one MOS finger more: the `count_only` shape.
# shellcheck disable=SC2016  # the `$2` here is SPICE instance text, not a shell positional.
sed 's/^X\$2 /X$2x out__t1 g__t1 vss__t0 vss__t1 nfet L=1U W=10U\nX$2 /' \
    "${tmp}/extracted-full.spice" > "${tmp}/extracted-extramos.spice"

expect "identical device multisets match" 0 '"status": "match"' -- \
  --schematic "${tmp}/schematic.spice" \
  --extracted "${tmp}/extracted-full.spice" --extracted-top top --format json

expect "m=8 is expanded into unit counts (3 cards, 10 units)" 0 '"units": 10' -- \
  --schematic "${tmp}/schematic.spice" \
  --extracted "${tmp}/extracted-full.spice" --extracted-top top --format json

expect "an extraction that drops a device class is a model_set mismatch" 1 '"model_set"' -- \
  --schematic "${tmp}/schematic.spice" \
  --extracted "${tmp}/extracted-nobip.spice" --extracted-top top --format json

expect "the dropped class is named with its unit count" 1 'bip' -- \
  --schematic "${tmp}/schematic.spice" \
  --extracted "${tmp}/extracted-nobip.spice" --extracted-top top

expect "same models, different instance counts is count_only" 1 '"count_only"' -- \
  --schematic "${tmp}/schematic.spice" \
  --extracted "${tmp}/extracted-extramos.spice" --extracted-top top --format json

expect "parasitic R/C primitives are not counted as devices" 0 '"device_cards": 6' -- \
  --schematic "${tmp}/schematic.spice" \
  --extracted "${tmp}/extracted-full.spice" --extracted-top top --format json

expect "a --extracted-top that is not in the netlist is a usage error" 2 'in this netlist (have: top)' -- \
  --schematic "${tmp}/schematic.spice" \
  --extracted "${tmp}/extracted-full.spice" --extracted-top nosuchcell

expect "an unreadable netlist is a usage error" 2 "" -- \
  --schematic "${tmp}/nonexistent.spice" \
  --extracted "${tmp}/extracted-full.spice" --extracted-top top

# ---- the committed item-7 record re-derives from the netlists it names ----------------------
if ! python3 -I - "${root}" "${tool}" <<'PY'
import glob, json, os, subprocess, sys

root, tool = sys.argv[1], sys.argv[2]
fails = []


def check(name, ok, detail=""):
    print(("PASS " if ok else "FAIL ") + name + (("" if ok else ": " + detail)))
    if not ok:
        fails.append(name)


records = sorted(glob.glob(os.path.join(root, "sim/pex-bandgap-top/records/*.json")))
check("at least one committed item-7 record exists", bool(records))
for rec_path in records:
    rel = os.path.relpath(rec_path, root)
    rec = json.load(open(rec_path))
    inv = rec.get("device_inventory")
    check("%s carries a device inventory" % rel, isinstance(inv, dict))
    if not isinstance(inv, dict):
        continue
    netlist = rec.get("extracted_netlist")
    check("%s names a committed extracted netlist" % rel,
          bool(netlist) and os.path.exists(os.path.join(root, netlist)), str(netlist))
    if not netlist or not os.path.exists(os.path.join(root, netlist)):
        continue
    # The record's own hashes must still describe the files it names.
    import hashlib

    def sha256(p):
        with open(os.path.join(root, p), "rb") as f:
            return hashlib.sha256(f.read()).hexdigest()

    check("%s extracted netlist matches extraction.netlist_sha256" % rel,
          sha256(netlist) == rec["extraction"]["netlist_sha256"])
    check("%s schematic DUT matches its recorded sha256" % rel,
          sha256(rec["schematic_dut"]["path"]) == rec["schematic_dut"]["sha256"])
    check("%s layout matches its recorded sha256" % rel,
          sha256(rec["layout"]["path"]) == rec["layout"]["sha256"])

    proc = subprocess.run(
        [sys.executable, "-I", tool,
         "--schematic", rec["schematic_dut"]["path"],
         "--extracted", netlist,
         "--extracted-top", rec["layout"]["top_cell"],
         "--format", "json"],
        cwd=root, capture_output=True, text=True)
    check("%s inventory re-runs (exit 0 or 1)" % rel, proc.returncode in (0, 1),
          "exit %s: %s" % (proc.returncode, proc.stderr[-300:]))
    if proc.returncode not in (0, 1):
        continue
    fresh = json.loads(proc.stdout)
    check("%s recorded inventory equals a fresh one" % rel, fresh == inv,
          "recorded difference %r vs fresh %r" % (inv.get("difference"),
                                                  fresh.get("difference")))
    # The record's status and the inventory verdict are one statement, not two.
    expect_ok = fresh["difference"]["status"] == "match"
    check("%s status agrees with the inventory verdict" % rel,
          (rec["status"] == "ok") == expect_ok,
          "status %r with inventory %r" % (rec["status"], fresh["difference"]["status"]))
    # Item 7 cannot be graded met from an extraction-only report: assert the record says so
    # rather than leaving it to prose.
    check("%s is an extraction-only report with no delta rows" % rel,
          rec.get("mode") == "extract-only" and rec.get("delta") == [],
          "mode %r delta %r" % (rec.get("mode"), rec.get("delta")))
    check("%s quotes extraction.model and body_bias" % rel,
          isinstance(rec["extraction"].get("model"), dict)
          and isinstance(rec.get("body_bias"), dict))

sys.exit(1 if fails else 0)
PY
then
  fails=$((fails + 1))
fi

echo
if [[ ${fails} -eq 0 ]]; then
  echo "All checks passed."
  exit 0
fi
echo "${fails} check(s) failed."
exit 1
