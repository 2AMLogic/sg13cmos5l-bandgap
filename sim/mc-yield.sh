#!/usr/bin/env bash
# sg13cmos5l-bandgap -- turn the committed Monte Carlo envelopes of
# sim/closed-loop-vref-mc into the committed `klt yield` evidence T1 item 6 is graded on
# (issue #31). Run from the repo root:
#
#   sim/mc-yield.sh <nominal-envelope> <negative-control-envelope>
#
# e.g. sim/mc-yield.sh sim/closed-loop-vref-mc/envelopes/<utc>-<sha>.line.json \
#                      sim/closed-loop-vref-mc/envelopes/<utc>-<sha>.inflated.json
#
# Both arguments are REPO-RELATIVE paths and are recorded as given: `klt yield-samples`
# writes them, with the sha256 of the exact bytes it parsed, into the derived sample set's
# `derivation` block, and a committed artifact must not carry this host's absolute paths
# (klayout-tools docs/json-contract.md's committed-artifact rule).
#
# Two steps, both of them klt's:
#
#   1. `klt yield-samples <nominal> --negative-control <known-bad>` derives ONE sample-set
#      document carrying both populations. This is the only supported way to attach a
#      second campaign's draws to the first; hand-editing a committed response to add a
#      negative control is explicitly not it.
#   2. `klt yield <sample-set> --limits yield-limits.json` grades it: yield with its
#      confidence interval, the distribution fit and its normality verdict, Cpk /
#      sigma-to-spec, the sample-size verdict, and the negative control's own verdict.
#
# Three artifacts land under sim/closed-loop-vref-mc/yield/, named after the nominal
# envelope so the chain is readable off the filenames alone, and append-only like every
# other piece of evidence in this tree:
#
#   <name>.samples.json   the derived two-population sample set (what klt signoff hashes)
#   <name>.yield.json     the `klt yield --format json` report -- the cited artifact
#   <name>.yield.txt      the same run's text output, for a human reading the diff
#
# THE YIELD EXTRA. `klt yield` needs the klt_yield_native Rust extension, which a plain
# klayout-tools install does not carry and which must NOT be installed into this host's
# shared toolchain (CLAUDE.md). $CM5_KLT_YIELD overrides the command; the default is a
# throwaway `uvx --from 'klayout-tools[yield]' klt`, which is the sanctioned way to reach
# a capability the host tool lacks. The resolved version is recorded in the run record.
#
# Exit: 0 both steps succeeded; 2 bad usage; 3 missing prerequisite; 4 an output exists
# (append-only); 5 a klt step failed; 6 the yield report contradicts the campaign's own
# premise (no negative control reached a verdict, or the measurement is missing).
set -euo pipefail

SIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SIM_DIR}/.." && pwd)"
BENCH="closed-loop-vref-mc"
BENCH_DIR="${SIM_DIR}/${BENCH}"
TAG="mc-yield.sh"

if [[ $# -ne 2 || "$1" == -* ]]; then
  echo "usage: sim/mc-yield.sh <nominal-envelope> <negative-control-envelope>" >&2
  echo "  both repo-relative, e.g. sim/${BENCH}/envelopes/<utc>-<sha>.line.json" >&2
  exit 2
fi
NOMINAL_REL="$1"
CONTROL_REL="$2"
for rel in "${NOMINAL_REL}" "${CONTROL_REL}"; do
  case "${rel}" in
    /*) echo "${TAG}: ${rel} is absolute; pass a repo-relative path (the derived document records it)." >&2; exit 2 ;;
  esac
  [[ -f "${REPO_DIR}/${rel}" ]] || { echo "${TAG}: ${rel} is not in this tree." >&2; exit 2; }
done

read -r LIMITS MEASUREMENT < <(python3 -I -c '
import json, sys
y = json.load(open(sys.argv[1]))["yield"]
print(y["limits"], y["measurement"])' "${BENCH_DIR}/bench.json") \
  || { echo "${TAG}: bench.json has no readable 'yield' block." >&2; exit 2; }
LIMITS_REL="sim/${BENCH}/${LIMITS}"
[[ -f "${REPO_DIR}/${LIMITS_REL}" ]] || { echo "${TAG}: ${LIMITS_REL} is missing." >&2; exit 3; }

KLT_YIELD=${CM5_KLT_YIELD:-uvx --from klayout-tools[yield] klt}
command -v "${KLT_YIELD%% *}" >/dev/null 2>&1 \
  || { echo "${TAG}: ${KLT_YIELD%% *} is not on PATH (set \$CM5_KLT_YIELD)." >&2; exit 3; }

BASE="$(basename "${NOMINAL_REL}")"; BASE="${BASE%.json}"
OUT_DIR="${BENCH_DIR}/yield"
mkdir -p "${OUT_DIR}"
SAMPLES="${OUT_DIR}/${BASE}.samples.json"
REPORT="${OUT_DIR}/${BASE}.yield.json"
TEXT="${OUT_DIR}/${BASE}.yield.txt"
for p in "${SAMPLES}" "${REPORT}" "${TEXT}"; do
  [[ ! -e "${p}" ]] || { echo "${TAG}: ${p} exists; artifacts are append-only." >&2; exit 4; }
done

cd "${REPO_DIR}"
echo "${TAG}: ${KLT_YIELD} --version" >&2
YIELD_VERSION="$(${KLT_YIELD} --version 2>&1 | tail -1)"
echo "${TAG}: using ${YIELD_VERSION}" >&2

echo "${TAG}: klt yield-samples ${NOMINAL_REL} --negative-control ${CONTROL_REL}" >&2
# --measurement restricts the derivation to the one measurement the spec row is about.
# The campaigns also carry the settle criterion and four node voltages; those are graded
# per unit by `klt sim` and are not populations anyone is making a yield claim about, and
# a yield report that silently graded them would be claiming more than the bench does.
${KLT_YIELD} yield-samples "${NOMINAL_REL}" --negative-control "${CONTROL_REL}" \
    --measurement "${MEASUREMENT}" \
    --description "the same campaign with every pinned statistical magnitude tripled (sim/closed-loop-vref-mc/bench.json campaign 'inflated')" \
    --format json > "${SAMPLES}" || {
  rc=$?; echo "${TAG}: klt yield-samples exited ${rc}" >&2; rm -f "${SAMPLES}"; exit 5; }

echo "${TAG}: klt yield ${SAMPLES#"${REPO_DIR}/"} --limits ${LIMITS_REL}" >&2
# `klt yield` exits 4 for `insufficient_evidence` and 3 for a failing measurement; both
# write a report and both are outcomes worth committing, so only a hard error (1/2) is
# treated as a failed step here. The verdict itself is read back below and recorded.
YIELD_RC=0
${KLT_YIELD} yield "${SAMPLES#"${REPO_DIR}/"}" --limits "${LIMITS_REL}" \
    --format json > "${REPORT}" 2>"${OUT_DIR}/.yield.err" || YIELD_RC=$?
if (( YIELD_RC == 1 || YIELD_RC == 2 )); then
  echo "${TAG}: klt yield exited ${YIELD_RC}:" >&2
  cat "${OUT_DIR}/.yield.err" >&2
  rm -f "${REPORT}" "${OUT_DIR}/.yield.err"
  exit 5
fi
${KLT_YIELD} yield "${SAMPLES#"${REPO_DIR}/"}" --limits "${LIMITS_REL}" \
    --format text > "${TEXT}" 2>>"${OUT_DIR}/.yield.err" || true
rm -f "${OUT_DIR}/.yield.err"

python3 -I - "${REPORT}" "${MEASUREMENT}" "${YIELD_RC}" "${YIELD_VERSION}" \
    "${NOMINAL_REL}" "${CONTROL_REL}" "${LIMITS_REL}" <<'PY'
import json, sys
report_p, meas, rc, version, nominal, control, limits = sys.argv[1:]
r = json.load(open(report_p))
entry = None
for m in r.get("measurements") or []:
    if m.get("name") == meas:
        entry = m
        break
if entry is None:
    sys.exit("%s: the yield report carries no measurement %r" % (report_p, meas))
y = entry.get("yield") or {}
emp = y.get("empirical") or {}
ss = entry.get("sample_size") or {}
nc = entry.get("negative_control") or {}
d = entry.get("distribution") or {}
cap = entry.get("capability") or {}
print("  klt:               %s" % version)
print("  samples            %s (nominal), negative control %s" % (emp.get("n"), nc.get("n")))
print("  %-18s mean %s  sigma %s" % (meas, d.get("mean"), d.get("stddev")))
if d.get("mean") is not None and d.get("stddev") is not None:
    print("  mean +/- 3 sigma   [%.6f, %.6f]  (width %.6f)" % (
        d["mean"] - 3 * d["stddev"], d["mean"] + 3 * d["stddev"], 6 * d["stddev"]))
ci = emp.get("confidence_interval") or {}
print("  yield (empirical)  %s  [%s, %s] at %s" % (
    emp.get("estimate"), ci.get("low"), ci.get("high"), emp.get("confidence")))
print("  capability         cpk %s  sigma_to_spec %s" % (cap.get("cpk"),
                                                         cap.get("sigma_to_spec")))
print("  sample size        %s (required_n %s)" % (ss.get("verdict"), ss.get("required_n")))
print("  negative control   %s" % nc.get("verdict"))
print("  report status      %s (klt yield exit %s)" % (r.get("status"), rc))
problems = []
if nc.get("verdict") not in ("detected", "not_detected", "not_applicable"):
    problems.append("the negative control reached no verdict (%r)" % nc.get("verdict"))
if problems:
    sys.exit("\n".join("mc-yield.sh: %s" % p for p in problems))
PY
status=$?

echo "${TAG}: wrote ${SAMPLES#"${REPO_DIR}/"}"
echo "${TAG}: wrote ${REPORT#"${REPO_DIR}/"}"
echo "${TAG}: wrote ${TEXT#"${REPO_DIR}/"}"
exit $(( status == 0 ? 0 : 6 ))
