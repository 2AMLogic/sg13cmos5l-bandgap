#!/usr/bin/env bash
# sg13cmos5l-bandgap -- closed-loop vref bench runner (issue #14, Part of #5). Cold-start:
#
#   source sim/env.sh && sim/closed-loop-vref-pvt/run.sh   # prerequisites: sim/README.md
#
# One corner (typ / 27 C / 3.30 V), one `klt sim --backend local` unit. Reads the DUT
# netlist from design/sg13cmos5l/netlist/ (migrated from the commit in reuse.lock.json, record 0006),
# then writes sim/closed-loop-vref-pvt/records/<UTC timestamp>-<short git sha>.json and
# never overwrites an existing record. Scratch: sim/build/closed-loop-vref-pvt/
# (gitignored). Figures are SIMULATED. The 45-point grid is NOT run here: see README.md.
#
# Exit: 0 record with vref_v; 3 missing prerequisite; 4 record exists; 5 simulation or
# measurement failed (a record stating the failure is written); 6 source netlist or pin missing/refused.
set -euo pipefail

BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIM_DIR="$(cd "${BENCH_DIR}/.." && pwd)"
REPO_DIR="$(cd "${SIM_DIR}/.." && pwd)"
TAG="closed-loop-vref-pvt/run.sh"

# shellcheck source=../env.sh
source "${SIM_DIR}/env.sh" || { echo "${TAG}: sim/env.sh refused; see the error above." >&2; exit 3; }

# shellcheck source=../runner-lib.sh
source "${SIM_DIR}/runner-lib.sh"
cm5_gate "${TAG}" ngspice klt python3 sha256sum gh git
# psp103 for the MOS devices; r3_cmc for rppd/rhigh (sim/pdk.json lists it as built by the OSDI step).
cm5_osdi_gate "${TAG}" psp103 r3_cmc

# ---- pinned source: repo and commit from reuse.lock.json (first non-block `pin` source) ----
read -r SRC_REPO SRC_COMMIT < <(python3 -I - "${REPO_DIR}/reuse.lock.json" <<'PY'
import json, re, sys
for s in json.load(open(sys.argv[1]))["sources"]:
    if s.get("mode") == "pin" and "block" not in s:
        if not re.fullmatch(r"[0-9a-f]{40}", s["commit"]):
            sys.exit("reuse.lock.json commit is not a 40-hex sha: %r" % s["commit"])
        print(s["repo"], s["commit"]); break
else:
    sys.exit("reuse.lock.json has no pinned design source")
PY
) || { echo "${TAG}: cannot read the pinned source from reuse.lock.json." >&2; exit 6; }

WORK="${SIM_DIR}/build/closed-loop-vref-pvt"
rm -rf "${WORK}"; mkdir -p "${WORK}"

SRC_PATH="design/sg13cmos5l/netlist/bandgap_top.spice"
# Migrated byte-for-byte from ${SRC_REPO}@${SRC_COMMIT} (decision record 0006): read the in-repo copy.
[[ -f "${REPO_DIR}/${SRC_PATH}" ]] \
  || { echo "${TAG}: SOURCE_MISSING ${SRC_PATH} is not in this tree (decision record 0006)." >&2; exit 6; }
cp "${REPO_DIR}/${SRC_PATH}" "${WORK}/bandgap_top.fetched.spice"
grep -q '^\.subckt bandgap_core ' "${WORK}/bandgap_top.fetched.spice" \
  || { echo "${TAG}: fetched ${SRC_PATH} has no 'bandgap_core' subckt; not the expected netlist." >&2; exit 6; }
# Only transformation of the DUT: drop the final `.end` card. Nothing else is edited.
grep -v -x '\.end' "${WORK}/bandgap_top.fetched.spice" > "${WORK}/bandgap_top.spice"

# ---- corner bundle: section per spec/target-spec.md §PVT, selected by the request's process label ----
BUNDLE="${WORK}/corners.lib"
python3 -I - "${BUNDLE}" "${CM5_NGSPICE_MODELS}" <<'PY'
import sys
out, models = sys.argv[1:]
table = {  # label: (cornerPNP, cornerMOShv, cornerRES)
    "typ": ("typ", "mos_tt", "res_typ"), "bcs": ("bcs", "mos_ff", "res_bcs"),
    "wcs": ("wcs", "mos_ss", "res_wcs"), "sf": ("typ", "mos_sf", "res_typ"),
    "fs": ("typ", "mos_fs", "res_typ"),
}
with open(out, "w") as f:
    for label, (pnp, mos, res) in table.items():
        f.write(".lib %s\n" % label)
        f.write('.lib "%s/cornerPNP.lib" %s\n' % (models, pnp))
        f.write('.lib "%s/cornerMOShv.lib" %s\n' % (models, mos))
        f.write('.lib "%s/cornerRES.lib" %s\n' % (models, res))
        f.write(".endl %s\n" % label)
PY

DECK="${WORK}/deck.cir"
sed -e 's|@@VDD@@|3.3|' -e "s|@@WORK@@|${WORK}|" "${BENCH_DIR}/vref.cir.tmpl" | grep -v '^\*' > "${DECK}"

# One point of the committed 45-point request: same measurements and analysis, narrowed to typ/27/3.30.
python3 -I - "${BENCH_DIR}/request-45pt.json" "${WORK}/request.json" "${DECK}" "${BUNDLE}" "${CM5_OSDI_DIR}" <<'PY'
import json, sys
src, dst, deck, bundle, osdi_dir = sys.argv[1:]
r = json.load(open(src))
r["netlist"], r["models"] = deck, {"lib": bundle}
r["corners"] = {"process": ["typ"], "supply_v": {"Vvdd": [3.3]}, "temperature_c": [27]}
r["options"]["timeout_s"] = 300  # narrowed from the request file's 600 for the single unit
r["options"]["osdi_preload"] = [osdi_dir + "/psp103.osdi", osdi_dir + "/r3_cmc.osdi"]
json.dump(r, open(dst, "w"), indent=2)
PY

cm5_record_path "${TAG}" "${REPO_DIR}" "${BENCH_DIR}/records"

KLT_RC=0
klt sim --backend local --format json -o "${WORK}/out" "${WORK}/request.json" > "${WORK}/envelope.json" 2>"${WORK}/klt.err" || KLT_RC=$?

set +e
python3 -I - "${WORK}/envelope.json" "${REC}" "${DECK}" "${BENCH_DIR}/vref.cir.tmpl" "${WORK}/bandgap_top.fetched.spice" \
  "${NGSPICE_VERSION}" "${CM5_PDK_REVISION}" "${SHA}" "${STAMP}" "${SIM_DIR}/pdk.json" \
  "${SRC_REPO}" "${SRC_COMMIT}" "${KLT_RC}" "${WORK}/klt.err" "${SIM_DIR}/tools" <<'PY'
import json, sys
(env_p, rec_p, deck_p, tmpl_p, fetched_p, ngspice, pdk_rev, sha, stamp, pin_p,
 src_repo, src_commit, klt_rc, klt_err_p, tools_dir) = sys.argv[1:]
sys.path.insert(0, tools_dir)
from cm5_record import collect, klt_version as get_klt_version, sha256, write_record
pin = json.load(open(pin_p))
klt_version = get_klt_version()
try:
    envelope = json.load(open(env_p))
except Exception:
    envelope = None

NAMES = ("vref_v", "vref_prev_v", "fb_v", "sns1_v", "sns2_v")
values = collect(envelope, NAMES)

SETTLE_V = 1e-3  # settle criterion: |vref(2.0 ms) - vref(1.5 ms)| < 1 mV
reason = None
if int(klt_rc) != 0:
    reason = "klt sim exited %s: %s" % (klt_rc, open(klt_err_p).read()[-400:].strip())
elif not set(NAMES) <= set(values):
    reason = "klt envelope has no value for: %s" % ", ".join(sorted(set(NAMES) - set(values)))
elif abs(values["vref_v"] - values["vref_prev_v"]) >= SETTLE_V:
    reason = "vref not settled: |vref(2.0ms)-vref(1.5ms)| = %.3g V >= %.0e V" % (
        abs(values["vref_v"] - values["vref_prev_v"]), SETTLE_V)

record = {
    "kind": "closed-loop-vref",
    "label": "SIMULATED",
    "status": "failed" if reason else "ok",
    "testbench": "sim/closed-loop-vref-pvt/vref.cir.tmpl",
    "corner": {"process": "typ", "vdd_v": 3.3, "temperature_c": 27},
    "timestamp_utc": stamp,
    "repo_git_sha": sha,
    "pdk_revision": pdk_rev,
    "pdk": {"name": pin["pdk"], "pin_file": "sim/pdk.json"},
    "source_repo": src_repo,
    "source_commit": src_commit,
    "source_path": "design/sg13cmos5l/netlist/bandgap_top.spice",
    "source_file_sha256": sha256(fetched_p),
    "simulator": {"ngspice": ngspice, "klt": klt_version, "backend": "local"},
    "deck_sha256": sha256(deck_p),
    "template_sha256": sha256(tmpl_p),
    "osdi_preload": ["psp103.osdi", "r3_cmc.osdi"],
    "settle_criterion": "abs(vref at 2.0 ms - vref at 1.5 ms) < 1 mV; vref_v read at 2.0 ms of a 2 ms transient",
    "measurements": values,
    "klt_envelope": envelope,
}
if reason:
    record["failure_reason"] = reason
else:
    record["vref_v"] = values["vref_v"]
write_record(rec_p, record)
print("closed-loop-vref-pvt/run.sh: wrote", rec_p)
if reason:
    print("closed-loop-vref-pvt/run.sh: FAILED:", reason, file=sys.stderr)
    sys.exit(5)
print("  vref_v = %.6g V (simulated, typ/27C/3.30V, closed loop)" % values["vref_v"])
PY
exit $?
