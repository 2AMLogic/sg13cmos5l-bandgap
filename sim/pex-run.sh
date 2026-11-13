#!/usr/bin/env bash
# sg13cmos5l-bandgap -- the T1-item-7 (post-layout verification) extraction runner,
# issue #32, Part of #5. Cold start:
#
#   source sim/env.sh && sim/pex-run.sh
#
# One invocation runs ONE `klt pex` request over the committed top-cell GDS at the klt
# version sim/pex-bandgap-top/pex.json pins, then writes three append-only artifacts:
#
#   <bench>/envelopes/<UTC>-<short sha>.json   the raw `klt pex --format json` envelope.
#                                              THIS is what manifests/ cites for T1 item 7.
#   <bench>/extracted/<UTC>-<short sha>.spice  the extracted netlist that envelope's
#                                              `extraction.netlist_sha256` names, committed so
#                                              the device inventory below is auditable offline.
#   <bench>/records/<UTC>-<short sha>.json     the repo's own record: the pins, the layout and
#                                              netlist hashes, the extraction model and
#                                              body-bias blocks quoted from the envelope, and
#                                              the schematic-vs-extracted device inventory.
#
# WHY `--extract-only` AND NOT A DELTA GRID. Item 7 wants the spec suite re-run against the
# extracted netlist. The curated `sg13cmos5l` extraction deck declares no bipolar device
# class, so the three `pnpMPA` devices of the bandgap core are not recognised and are simply
# ABSENT from every netlist `klt extract` produces for this layout -- which
# sim/tools/pex_device_inventory.py measures here rather than asserting. An extracted leg
# simulated on that netlist still converges and still reports numbers, so running the 45-point
# grids against it would manufacture deltas between two different circuits. The extraction
# report plus the inventory is the honest artifact; see sim/pex-bandgap-top/README.md and
# spec/decision-records/0012-post-layout-pex-extraction-gap.md. `klt pex`'s extraction-only
# mode is klayout-tools#3739, which spec/target-spec.md §Signoff named as the item-7 gate.
#
# Nothing here is simulated: every figure is layout-derived (geometry and deck coefficients).
#
# Exit: 0 the extraction ran and the device inventory MATCHES (a delta run would compare like
# with like); 2 bad usage / malformed bench directory; 3 missing prerequisite; 4 an artifact
# path exists (append-only); 5 the extraction ran but the device inventory does not match, or
# `klt pex` failed (an envelope and a record stating it are written either way); 6 the DUT
# netlist, the layout or the pin is missing.
set -euo pipefail

SIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SIM_DIR}/.." && pwd)"
BENCH="pex-bandgap-top"
BENCH_DIR="${SIM_DIR}/${BENCH}"
TAG="pex-run.sh[${BENCH}]"

if [[ $# -ne 0 ]]; then
  echo "usage: source sim/env.sh && sim/pex-run.sh   (no arguments)" >&2
  exit 2
fi
[[ -f "${BENCH_DIR}/pex.json" ]] \
  || { echo "${TAG}: ${BENCH_DIR}/pex.json is missing." >&2; exit 2; }

# shellcheck source=env.sh
source "${SIM_DIR}/env.sh" || { echo "${TAG}: sim/env.sh refused; see the error above." >&2; exit 3; }
# shellcheck source=runner-lib.sh
source "${SIM_DIR}/runner-lib.sh"

# No ngspice gate: `klt pex --extract-only` runs no simulator (so cm5_gate, which always
# version-checks ngspice, is deliberately not used here).
for tool in uvx python3 sha256sum git; do
  command -v "${tool}" >/dev/null 2>&1 \
    || { echo "${TAG}: ${tool} not on PATH." >&2; exit 3; }
done

read -r LAYOUT TOP_CELL DECK PDK PINS RENAME KLT_PIN DUT_REL < <(python3 -I -c '
import json, sys
c = json.load(open(sys.argv[1]))
missing = [k for k in ("layout", "top_cell", "deck", "pdk", "pins",
                       "rename_declared_pins", "klt_pin", "schematic_dut") if k not in c]
if missing:
    sys.exit("pex.json is missing %s" % ", ".join(missing))
print(c["layout"], c["top_cell"], c["deck"], c["pdk"], c["pins"],
      "1" if c["rename_declared_pins"] else "0", c["klt_pin"], c["schematic_dut"])
' "${BENCH_DIR}/pex.json") \
  || { echo "${TAG}: ${BENCH_DIR}/pex.json is not a readable config." >&2; exit 2; }

for rel in "${LAYOUT}" "${DUT_REL}"; do
  [[ -f "${REPO_DIR}/${rel}" ]] \
    || { echo "${TAG}: SOURCE_MISSING ${rel} is not in this tree." >&2; exit 6; }
done
cm5_pinned_source "${TAG}" "${REPO_DIR}"

# `uvx --from "klayout-tools==<pin>" klt` is the sanctioned way to run a pinned klt without
# touching the host tool install (CLAUDE.md, "Never change host-wide tools"). The pin is
# pex.json's, so the committed envelope is reproducible at the version manifests/ grades with.
# $CM5_KLT_CMD overrides it for an operator who already has that version resolved.
# shellcheck disable=SC2206  # deliberate word split: this is a command line, not one word.
KLT_CMD=(${CM5_KLT_CMD:-uvx --from "klayout-tools==${KLT_PIN}" klt})

WORK="${SIM_DIR}/build/${BENCH}"
rm -rf "${WORK}"; mkdir -p "${WORK}"
mkdir -p "${BENCH_DIR}/records" "${BENCH_DIR}/envelopes" "${BENCH_DIR}/extracted"
cm5_record_path "${TAG}" "${REPO_DIR}" "${BENCH_DIR}/records"
REC="${BENCH_DIR}/records/${STAMP}-${SHA}.json"
ENVELOPE_NAME="${STAMP}-${SHA}.json"
NETLIST_NAME="${STAMP}-${SHA}.spice"
ENVELOPE="${BENCH_DIR}/envelopes/${ENVELOPE_NAME}"
NETLIST="${BENCH_DIR}/extracted/${NETLIST_NAME}"
for p in "${REC}" "${ENVELOPE}" "${NETLIST}"; do
  [[ ! -e "${p}" ]] || { echo "${TAG}: ${p} exists; these artifacts are append-only." >&2; exit 4; }
done

PEX_ARGS=(
  pex "${REPO_DIR}/${LAYOUT}"
  --deck "${DECK}"
  --extract-only
  --top "${TOP_CELL}"
  --pdk "${PDK}"
  --pdk-root "${PDK_ROOT}"
  --pins "${PINS}"
  -o "${WORK}/extracted.spice"
  --outdir "${WORK}/out"
  --format json
)
[[ "${RENAME}" == "1" ]] && PEX_ARGS+=(--rename-declared-pins)

echo "${TAG}: ${KLT_CMD[*]} pex --extract-only --deck ${DECK} --top ${TOP_CELL}" >&2
KLT_RC=0
"${KLT_CMD[@]}" "${PEX_ARGS[@]}" > "${WORK}/envelope.json" 2> "${WORK}/klt.err" || KLT_RC=$?
# `--extract-only` reports `status: not_checked` and exits 4 BY DESIGN (no measurement leg to
# pass or fail). Any other code is a real failure of the run.
if (( KLT_RC != 4 )); then
  echo "${TAG}: klt pex exited ${KLT_RC} (expected 4 for --extract-only); tail of stderr:" >&2
  tail -20 "${WORK}/klt.err" >&2 || true
fi

INV_RC=0
INVENTORY="${WORK}/inventory.json"
if [[ -s "${WORK}/extracted.spice" ]]; then
  cp "${WORK}/extracted.spice" "${NETLIST}"
  # Run from the repo root with repo-relative paths: the inventory report is committed
  # inside the record, so it must not carry this host's absolute paths.
  ( cd "${REPO_DIR}" && python3 -I sim/tools/pex_device_inventory.py \
      --schematic "${DUT_REL}" \
      --extracted "sim/${BENCH}/extracted/${NETLIST_NAME}" \
      --extracted-top "${TOP_CELL}" \
      --format json -o "${INVENTORY}" > /dev/null ) || INV_RC=$?
  if (( INV_RC > 1 )); then
    echo "${TAG}: pex_device_inventory.py exited ${INV_RC}." >&2
  fi
else
  INV_RC=2
  echo "${TAG}: klt pex wrote no extracted netlist; no device inventory to take." >&2
fi

set +e
python3 -I - "${WORK}/envelope.json" "${ENVELOPE}" "${REC}" "${ENVELOPE_NAME}" \
  "${BENCH_DIR}/pex.json" "${INVENTORY}" "${INV_RC}" "${KLT_RC}" \
  "${REPO_DIR}/${LAYOUT}" "${LAYOUT}" "${REPO_DIR}/${DUT_REL}" "${DUT_REL}" \
  "${NETLIST_NAME}" "${CM5_PDK_REVISION}" "${SHA}" "${STAMP}" "${SIM_DIR}/pdk.json" \
  "${SRC_REPO}" "${SRC_COMMIT}" "${KLT_PIN}" "${BENCH}" "${WORK}/klt.err" \
  "${SIM_DIR}/tools" <<'PY'
import json, os, sys
(env_p, envelope_out, rec_p, envelope_name, cfg_p, inv_p, inv_rc, klt_rc, layout_abs,
 layout_rel, dut_abs, dut_rel, netlist_name, pdk_rev, sha, stamp, pin_p, src_repo,
 src_commit, klt_pin, bench, klt_err_p, tools_dir) = sys.argv[1:]
sys.path.insert(0, tools_dir)
from cm5_record import sha256, write_record

cfg = json.load(open(cfg_p))
pin = json.load(open(pin_p))
try:
    envelope = json.load(open(env_p))
except Exception:
    envelope = None
# The envelope is committed verbatim whatever it says -- it is the cited artifact, and a
# report that cannot grade the item is evidence of exactly that. Only an unparseable run has
# nothing to commit.
if envelope is not None:
    write_record(envelope_out, envelope)

inventory = None
if os.path.exists(inv_p):
    try:
        inventory = json.load(open(inv_p))
    except Exception:
        inventory = None

reason = None
if int(klt_rc) != 4:
    reason = "klt pex exited %s (expected 4 for --extract-only): %s" % (
        klt_rc, open(klt_err_p).read()[-600:].strip())
elif envelope is None:
    reason = "klt pex wrote no parseable JSON envelope"
elif envelope.get("status") != "not_checked":
    reason = "envelope status is %r, expected 'not_checked' for --extract-only" % (
        envelope.get("status"),)
elif inventory is None:
    reason = "no device inventory was taken (pex_device_inventory.py exited %s)" % inv_rc
elif inventory["difference"]["status"] != "match":
    d = inventory["difference"]
    reason = ("device inventory %s (%s): schematic-only %s, extracted-only %s" % (
        d["status"], d["kind"],
        {k: v["units"] for k, v in d["schematic_only"].items()} or "{}",
        {k: v["units"] for k, v in d["extracted_only"].items()} or "{}"))

extraction = (envelope or {}).get("extraction") or {}
record = {
    "schema_version": 1,
    "kind": cfg["kind"],
    # Not SIMULATED: nothing here runs a simulator. Every figure is layout-derived --
    # geometry out of the committed GDS, R/C out of the deck's own coefficients.
    "label": "LAYOUT-DERIVED (extraction only; no simulation leg)",
    "status": "failed" if reason else "ok",
    "bench": bench,
    "t1_item": 7,
    "mode": cfg.get("mode"),
    "spec_rows": cfg["spec_rows"],
    "criteria": cfg["criteria"],
    "timestamp_utc": stamp,
    "repo_git_sha": sha,
    "pdk_revision": pdk_rev,
    "pdk": {"name": pin["pdk"], "pin_file": "sim/pdk.json"},
    "source_repo": src_repo,
    "source_commit": src_commit,
    "layout": {"path": layout_rel, "sha256": sha256(layout_abs), "top_cell": cfg["top_cell"]},
    "schematic_dut": {"path": dut_rel, "sha256": sha256(dut_abs)},
    "tool": {"klt_pin": klt_pin, "klt_version": (envelope or {}).get("provenance", {})
             .get("klt_version"), "deck": cfg["deck"],
             "deck_content_hash": (envelope or {}).get("provenance", {})
             .get("deck", {}).get("content_hash")},
    "extraction": {
        "device_count": extraction.get("device_count"),
        "net_count": extraction.get("net_count"),
        "netlist_sha256": extraction.get("netlist_sha256"),
        # Quoted verbatim: T1 item 7 names `extraction.model` as the machine-checkable
        # statement of what the lumped-RC model does and does not account for.
        "model": extraction.get("model"),
        "pins": cfg["pins"],
        "rename_declared_pins": extraction.get("rename_declared_pins"),
    },
    # Also quoted verbatim: item 7's own note requires a claim citing it to read this field
    # and say whether the numbers were taken on a properly-biased netlist.
    "body_bias": (envelope or {}).get("body_bias"),
    "measurement": (envelope or {}).get("measurement"),
    "delta": (envelope or {}).get("delta"),
    "envelope": "sim/%s/envelopes/%s" % (bench, envelope_name) if envelope is not None else None,
    # Written only when `klt pex` produced a netlist to commit (see NETLIST above).
    "extracted_netlist": None if inventory is None else "sim/%s/extracted/%s" % (
        bench, netlist_name),
    "device_inventory": inventory,
}
if reason:
    record["failure_reason"] = reason
write_record(rec_p, record)
print("%s: wrote %s" % (bench, rec_p))
if envelope is not None:
    print("%s: wrote %s" % (bench, envelope_out))
if inventory is not None:
    d = inventory["difference"]
    print("  device inventory: %s; schematic %s cards/%s units vs extracted %s/%s" % (
        d["status"], inventory["schematic"]["device_cards"],
        inventory["schematic"]["device_units"], inventory["extracted"]["device_cards"],
        inventory["extracted"]["device_units"]))
    for name, c in d["schematic_only"].items():
        print("  NOT EXTRACTED: %s -- %s card(s), %s unit(s)" % (
            "/".join(c["names"]), c["instances"], c["units"]))
if reason:
    print("%s: NOT GRADEABLE: %s" % (bench, reason), file=sys.stderr)
    sys.exit(5)
print("  extraction ran and the device inventory matches (layout-derived, extract-only)")
PY
exit $?
