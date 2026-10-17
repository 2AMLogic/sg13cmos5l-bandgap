#!/usr/bin/env bash
# sg13cmos5l-bandgap -- PDK smoke bench runner (issue #4). Cold-start:
#
#   source sim/env.sh && sim/smoke/run_smoke.sh      # see sim/README.md for prerequisites
#
# One corner (typ / 27 C / 3.3 V), one `klt sim --backend local` unit. Writes
#   sim/smoke/records/<UTC timestamp>-<short git sha>.json
# and never overwrites an existing record (append-only evidence). Scratch goes
# to sim/build/smoke/ (gitignored). The figures are SIMULATED.
set -euo pipefail

SMOKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIM_DIR="$(cd "${SMOKE_DIR}/.." && pwd)"
REPO_DIR="$(cd "${SIM_DIR}/.." && pwd)"

# shellcheck source=../env.sh
source "${SIM_DIR}/env.sh" || { echo "run_smoke.sh: sim/env.sh refused; see the error above." >&2; exit 3; }

for tool in ngspice klt python3 sha256sum; do
  command -v "${tool}" >/dev/null 2>&1 || { echo "run_smoke.sh: ${tool} not on PATH." >&2; exit 3; }
done
NGSPICE_VERSION="$(ngspice --version 2>&1 | grep -m1 -oE 'ngspice-[0-9]+(\.[0-9]+)*')"
NGSPICE_MAJOR="${NGSPICE_VERSION#ngspice-}"; NGSPICE_MAJOR="${NGSPICE_MAJOR%%.*}"
if (( NGSPICE_MAJOR < 43 )); then
  echo "run_smoke.sh: ${NGSPICE_VERSION} cannot load the OSDI v0.4 objects the pinned openvaf-r builds (needs >= 43; sim/pdk.json 'simulator')." >&2
  exit 3
fi
OSDI="${CM5_OSDI_DIR}/psp103.osdi"
[[ -f "${OSDI}" ]] || { echo "run_smoke.sh: ${OSDI} missing; build it first (sim/README.md 'OSDI build')." >&2; exit 3; }

WORK="${SIM_DIR}/build/smoke"
rm -rf "${WORK}"; mkdir -p "${WORK}"
DECK="${WORK}/deck.cir"
BUNDLE="${WORK}/corners.lib"   # klt selects the `typ` section by the request's process label
{
  echo ".lib typ"
  echo ".lib \"${CM5_NGSPICE_MODELS}/cornerPNP.lib\" typ"
  echo ".lib \"${CM5_NGSPICE_MODELS}/cornerMOShv.lib\" mos_tt"
  echo ".endl typ"
} > "${BUNDLE}"
grep -v '^\*' "${SMOKE_DIR}/smoke.cir" > "${DECK}"

cat > "${WORK}/request.json" <<EOF
{
  "engine": "ngspice",
  "netlist": "${DECK}",
  "netlist_source": "extracted",
  "models": { "lib": "${BUNDLE}" },
  "corners": { "process": ["typ"], "supply_v": { "Vdd": [3.3] }, "temperature_c": [27] },
  "analysis": { "kind": "tran", "args": "10n 50n" },
  "measurements": [
    { "name": "v_drain_v", "spice": ".meas tran v_drain_v find v(d) at=40n" },
    { "name": "v_emitter_v", "spice": ".meas tran v_emitter_v find v(e) at=40n" },
    { "name": "i_vdd_a", "spice": ".meas tran i_vdd_a find i(Vdd) at=40n" }
  ],
  "options": { "timeout_s": 120, "keep_artifacts": true, "osdi_preload": ["${OSDI}"] }
}
EOF

# ngspice has no .MEASURE OP, so the DC operating point is a short transient with
# only DC sources, read at 40 ns. -o keeps klt's envelope; its exit status is the gate.
klt sim --backend local --format json -o "${WORK}/out" "${WORK}/request.json" > "${WORK}/envelope.json"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
SHA="$(git -C "${REPO_DIR}" rev-parse --short HEAD)"
REC="${SMOKE_DIR}/records/${STAMP}-${SHA}.json"
[[ ! -e "${REC}" ]] || { echo "run_smoke.sh: ${REC} exists; records are append-only." >&2; exit 4; }

python3 -I - "${WORK}/envelope.json" "${REC}" "${DECK}" "${SMOKE_DIR}/smoke.cir" "${NGSPICE_VERSION}" \
  "${CM5_PDK_REVISION}" "${SHA}" "${STAMP}" "${SIM_DIR}/pdk.json" <<'PY'
import hashlib, json, subprocess, sys
env_p, rec_p, deck_p, src_p, ngspice, pdk_rev, sha, stamp, pin_p = sys.argv[1:]
envelope = json.load(open(env_p))
sha256 = lambda p: hashlib.sha256(open(p, "rb").read()).hexdigest()
pin = json.load(open(pin_p))
klt_version = subprocess.run(["klt", "--version"], capture_output=True, text=True).stdout.strip()

def walk(o):
    if isinstance(o, dict):
        yield o
        for v in o.values():
            yield from walk(v)
    elif isinstance(o, list):
        for v in o:
            yield from walk(v)

values = {}
for d in walk(envelope):
    for k in ("v_drain_v", "v_emitter_v", "i_vdd_a"):
        if isinstance(d.get(k), (int, float)):
            values[k] = d[k]
        elif isinstance(d.get("name"), str) and d["name"] == k and isinstance(d.get("value"), (int, float)):
            values[k] = d["value"]
if set(values) != {"v_drain_v", "v_emitter_v", "i_vdd_a"}:
    sys.exit("run_smoke.sh: klt envelope has no value for every measurement; refusing to write a record. Found: %r" % values)

record = {
    "kind": "pdk-smoke",
    "label": "SIMULATED",
    "testbench": "sim/smoke/smoke.cir",
    "corner": {"process": "typ", "vdd_v": 3.3, "temperature_c": 27},
    "timestamp_utc": stamp,
    "repo_git_sha": sha,
    "pdk": {"name": pin["pdk"], "revision": pdk_rev, "pin_file": "sim/pdk.json"},
    "simulator": {"ngspice": ngspice, "klt": klt_version, "backend": "local"},
    "deck_sha256": sha256(deck_p),
    "source_deck_sha256": sha256(src_p),
    "osdi_preload": ["psp103.osdi"],
    "measurements": values,
    "klt_envelope": envelope,
}
open(rec_p, "x").write(json.dumps(record, indent=2, sort_keys=True) + "\n")
print("run_smoke.sh: wrote", rec_p)
for k, v in values.items():
    print("  %s = %.6g (simulated, typ/27C/3.3V)" % (k, v))
PY
