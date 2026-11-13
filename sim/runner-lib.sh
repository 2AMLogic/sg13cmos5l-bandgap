# Source me from a bench runner, after `source sim/env.sh`:  source sim/runner-lib.sh
#
# Shared runner steps (issue #37): tool and ngspice gate, append-only record path.
# Sets/exports for the caller: NGSPICE_VERSION, STAMP, SHA, REC. The envelope parsing and
# the exclusive record write live in sim/tools/cm5_record.py. Record shapes stay with each
# runner (decision record 0008).
#
# Sourced, not executed: no shebang. Do not `set -e` here; callers keep their own.
# shellcheck shell=bash

# cm5_gate <tag> <tool>...: exit 3 unless every tool is on PATH and ngspice is >= 43.
cm5_gate() {
  local tag="$1" tool; shift
  for tool in "$@"; do
    command -v "${tool}" >/dev/null 2>&1 || { echo "${tag}: ${tool} not on PATH." >&2; exit 3; }
  done
  NGSPICE_VERSION="$(ngspice --version 2>&1 | grep -m1 -oE 'ngspice-[0-9]+(\.[0-9]+)*')"
  local major="${NGSPICE_VERSION#ngspice-}"; major="${major%%.*}"
  if (( major < 43 )); then
    echo "${tag}: ${NGSPICE_VERSION} cannot load the OSDI v0.4 objects the pinned openvaf-r builds (needs >= 43; sim/pdk.json 'simulator')." >&2
    exit 3
  fi
}

# cm5_osdi_gate <tag> <object>...: exit 3 unless each ${CM5_OSDI_DIR}/<object>.osdi exists.
cm5_osdi_gate() {
  local tag="$1" obj; shift
  for obj in "$@"; do
    [[ -f "${CM5_OSDI_DIR}/${obj}.osdi" ]] \
      || { echo "${tag}: ${CM5_OSDI_DIR}/${obj}.osdi missing; build it first (sim/README.md 'OSDI build')." >&2; exit 3; }
  done
}

# cm5_record_path <tag> <repo_dir> <records_dir>: sets STAMP, SHA, REC; exit 4 if REC exists.
cm5_record_path() {
  STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
  SHA="$(git -C "$2" rev-parse --short HEAD)"
  REC="$3/${STAMP}-${SHA}.json"
  [[ ! -e "${REC}" ]] || { echo "$1: ${REC} exists; records are append-only." >&2; exit 4; }
}

# ---- corner-verification grid helpers (issue #30) ----------------------------
# Shared by the five T1-item-5 benches (closed-loop-vref-pvt, -pvt-boxtc,
# closed-loop-psrr, closed-loop-iq, closed-loop-startup). Each bench keeps its own
# deck template, request file and record shape (decision record 0008); what is shared
# is reading the pin, staging the DUT, and the one way a grid reaches the batch fleet.

# cm5_pinned_source <tag> <repo_dir>: sets SRC_REPO and SRC_COMMIT from the first
# non-block `pin` source of reuse.lock.json. Exit 6 if the pin is unreadable or the
# commit is not a 40-hex sha.
cm5_pinned_source() {
  local tag="$1" repo_dir="$2"
  # shellcheck disable=SC2034  # set for the caller, like cm5_gate's NGSPICE_VERSION
  read -r SRC_REPO SRC_COMMIT < <(python3 -I - "${repo_dir}/reuse.lock.json" <<'PY'
import json, re, sys
for s in json.load(open(sys.argv[1]))["sources"]:
    if s.get("mode") == "pin" and "block" not in s:
        if not re.fullmatch(r"[0-9a-f]{40}", s["commit"]):
            sys.exit("reuse.lock.json commit is not a 40-hex sha: %r" % s["commit"])
        print(s["repo"], s["commit"]); break
else:
    sys.exit("reuse.lock.json has no pinned design source")
PY
  ) || { echo "${tag}: cannot read the pinned source from reuse.lock.json." >&2; exit 6; }
}

# The subcircuit name the staged DUT is wrapped in, and the pin order it is wrapped with
# (decision record 0013). Both are the EXTRACTED netlist's, not the schematic export's:
# `klt pex` reuses the bench's positional `X...` line on both legs, so a wrapper with the
# same pins in the schematic's own `vdd vss vref` order fires `pin_order_mismatch` and the
# extracted leg is skipped. Named here, once, because the deck templates' `Xdut` line and
# sim/tests/test-grid-benches.sh both have to agree with it.
CM5_DUT_SUBCKT="sg13cmos5l_bandgap_top"
CM5_DUT_PINS="vdd vref vss"

# cm5_stage_dut <tag> <repo_dir> <work_dir>: stage the in-repo migrated DUT netlist
# (decision record 0006) for a bench deck to `.include`. Sets CM5_DUT_FETCHED (the file
# as read, whose sha256 equals the pinned source blob), CM5_DUT (the staged, wrapped copy)
# and CM5_DUT_SHA256 (the staged copy's own hash, recorded next to the source's).
#
# The staged copy differs from the source in exactly three ways, all derived here and none
# of them an edit to the attested file (decision record 0013):
#   1. the commented-out top block header `**.subckt bandgap_top vdd vss vref` becomes a
#      live `.subckt ${CM5_DUT_SUBCKT} ${CM5_DUT_PINS}` card,
#   2. its matching `**.ends` becomes `.ends ${CM5_DUT_SUBCKT}`,
#   3. the final `.end` card is dropped, so the including deck's end card is the only one.
# Decks instantiate the result (`Xdut vdd vref vss sg13cmos5l_bandgap_top`); nothing else in
# the netlist is touched, and the three leaf `.subckt` definitions stay where they are.
#
# Electrically a no-op, measured rather than assumed: on typ/27 C/3.30 V every
# sim/closed-loop-vref-pvt measurement is identical to the flat deck's to all reported
# digits (vref_v = 1.19696 V, decision record 0013 "What was measured"). The source's
# `sub!` resistor-bulk nodes were ALREADY local to each leaf instance under ngspice
# (`xx1.sub!`, `xx3.sub!` -- `!` is an xschem global marker, not an ngspice one), so the
# wrapper only lengthens them to `xdut.xx1.sub!`. Staging adds no `.global sub!` card: that
# card lives in each of the five deck templates, beside the `Vsub sub! vss dc 0` line it
# makes true, so the fixture choice stays visible in the fixture rather than hidden inside
# this DUT derivation (issue #83, decision record 0014, which supersedes item 5 of 0013).
# A global net ignores subcircuit depth, so the card reaches through this wrapper unchanged.
#
# Exit 6 if the netlist is absent, is not the expected flattened export, or does not carry
# exactly one expected top block to rewrite.
cm5_stage_dut() {
  local tag="$1" repo_dir="$2" work="$3"
  local rel="design/sg13cmos5l/netlist/bandgap_top.spice"
  # shellcheck disable=SC2034  # set for the caller (grid-run.sh passes it into the record)
  CM5_DUT_SOURCE_PATH="${rel}"
  CM5_DUT_FETCHED="${work}/bandgap_top.fetched.spice"
  CM5_DUT="${work}/bandgap_top.spice"
  [[ -f "${repo_dir}/${rel}" ]] \
    || { echo "${tag}: SOURCE_MISSING ${rel} is not in this tree (decision record 0006)." >&2; exit 6; }
  cp "${repo_dir}/${rel}" "${CM5_DUT_FETCHED}"
  grep -q '^\.subckt bandgap_core ' "${CM5_DUT_FETCHED}" \
    || { echo "${tag}: ${rel} has no 'bandgap_core' subckt; not the expected netlist." >&2; exit 6; }
  python3 -I - "${CM5_DUT_FETCHED}" "${CM5_DUT}" "${CM5_DUT_SUBCKT}" "${CM5_DUT_PINS}" <<'PY' \
    || { echo "${tag}: ${rel} is not the expected flattened export; see the error above." >&2; exit 6; }
import sys
src, dst, top, pins = sys.argv[1:]
HEAD = "**.subckt bandgap_top vdd vss vref"   # the xschem export's commented-out top block
FOOT = "**.ends"
lines = open(src).read().splitlines()
heads = [i for i, l in enumerate(lines) if l.strip() == HEAD]
foots = [i for i, l in enumerate(lines) if l.strip() == FOOT]
if len(heads) != 1 or len(foots) != 1 or foots[0] < heads[0]:
    sys.exit("TOP_BLOCK_UNEXPECTED: want exactly one %r followed by one %r; found %d and %d"
             % (HEAD, FOOT, len(heads), len(foots)))
lines[heads[0]] = ".subckt %s %s" % (top, pins)
lines[foots[0]] = ".ends %s" % top
# Drop the file's own end card (never a leaf `.ends`), so the including deck's is the only one.
kept = [l for l in lines if l.strip().lower() != ".end"]
with open(dst, "w") as f:
    f.write("\n".join(kept) + "\n")
PY
  # shellcheck disable=SC2034  # set for the caller (grid-run.sh passes it into the record)
  CM5_DUT_SHA256="$(sha256sum "${CM5_DUT}" | cut -d' ' -f1)"
}

# cm5_grid_submit <tag> <request> <outdir> <envelope_out> <err_out>: run one multi-corner
# `klt sim` grid. Sets CM5_KLT_RC (never fails the shell, so the caller can record a failed
# envelope) and CM5_BACKEND.
#
# The grid goes to the Spot batch fleet, never to a local ngspice loop: this is the host
# rule for every multi-corner request, and sim/README.md records it. `--wait-for-capacity
# 600` makes a vCPU-budget refusal (batch_no_capacity / batch_concurrency_cap) wait with
# backoff instead of failing the step. $CM5_GRID_BACKEND overrides the backend for a
# non-dispatch host the operator names; a failed submit is reported, never replaced by a
# local grid.
cm5_grid_submit() {
  local tag="$1" request="$2" outdir="$3" envelope="$4" errlog="$5"
  CM5_BACKEND="${CM5_GRID_BACKEND:-batch}"
  CM5_KLT_RC=0
  echo "${tag}: klt sim --backend ${CM5_BACKEND} (grid; --wait-for-capacity 600)" >&2
  klt sim --backend "${CM5_BACKEND}" --wait-for-capacity 600 --format json \
      -o "${outdir}" "${request}" > "${envelope}" 2>"${errlog}" || CM5_KLT_RC=$?
  if (( CM5_KLT_RC != 0 )); then
    echo "${tag}: klt sim exited ${CM5_KLT_RC}; tail of stderr:" >&2
    tail -20 "${errlog}" >&2 || true
  fi
}
