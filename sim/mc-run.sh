#!/usr/bin/env bash
# sg13cmos5l-bandgap -- runner for the statistical Monte Carlo campaigns of
# sim/closed-loop-vref-mc (issue #31, T1 item 6). Cold start:
#
#   source sim/env.sh && sim/mc-run.sh line        # or zero | inflated | families
#
# One invocation runs ONE campaign named by sim/closed-loop-vref-mc/bench.json over the
# whole axis set its committed request declares, on the Spot batch fleet, and writes two
# append-only artifacts, exactly as sim/grid-run.sh does for the item-5 grids:
#
#   <bench>/envelopes/<UTC>-<short sha>.<campaign>.json   the raw `klt sim --format json`
#                                                         envelope. This is the artifact
#                                                         manifests/ cites and `klt yield`
#                                                         consumes.
#   <bench>/records/<UTC>-<short sha>.<campaign>.json     the repo's own record: the pin,
#                                                         the DUT/deck/template/request
#                                                         hashes, the seed, N, the per-point
#                                                         statistics and the control verdict.
#
# Why a second runner and not sim/grid-run.sh: a Monte Carlo campaign differs from a corner
# grid in three ways that are not parameters of the grid runner. It is a SET of campaigns
# (a population plus its controls) rather than one run; a campaign may have to render its
# deck with scaled statistical magnitudes read out of the pinned libraries; and its pass
# condition is a statement about the SPREAD (the zero-spread control must report exactly
# zero), not about limits. Everything the two runners do share -- the tool and OSDI gates,
# the pin, staging the migrated DUT, the one way a request reaches the fleet, the
# append-only record path -- is sim/runner-lib.sh's and is used unchanged here.
#
# $CM5_MC_DRY_RUN=1 renders the deck and request, prints the deck, runs `klt sim --dry-run`
# over the result and exits without submitting or writing anything.
#
# Figures are SIMULATED. Campaigns go to the batch fleet, never to a local ngspice loop; a
# failed submit is recorded and reported, never replaced by a local run (sim/README.md,
# CLAUDE.md). $CM5_GRID_BACKEND overrides the backend for a non-dispatch host an operator
# names, the same variable the grid runner reads.
#
# Exit: 0 the campaign ran and met its expectation; 2 bad usage / malformed bench directory;
# 3 missing prerequisite; 4 record or envelope exists (append-only); 5 the submit failed or
# the run did not pass; 6 DUT or pin missing; 7 the campaign ran but contradicted its
# declared `expect` (a zero-spread control that was not zero, or a spread campaign with none).
set -euo pipefail

SIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SIM_DIR}/.." && pwd)"
BENCH="closed-loop-vref-mc"
BENCH_DIR="${SIM_DIR}/${BENCH}"

if [[ $# -ne 1 || "$1" == -* ]]; then
  echo "usage: source sim/env.sh && sim/mc-run.sh <campaign>" >&2
  echo "  campaigns: $(python3 -I -c '
import json,sys
print(" ".join(c["name"] for c in json.load(open(sys.argv[1]))["campaigns"]))' \
    "${BENCH_DIR}/bench.json" 2>/dev/null || echo "see ${BENCH}/bench.json")" >&2
  exit 2
fi
CAMPAIGN="$1"
TAG="mc-run.sh[${CAMPAIGN}]"

[[ -f "${BENCH_DIR}/bench.json" ]] \
  || { echo "${TAG}: ${BENCH_DIR}/bench.json is missing." >&2; exit 2; }
read -r TMPL_NAME REQUEST_NAME STAT_SCALE EXPECT ROLE < <(python3 -I - \
    "${BENCH_DIR}/bench.json" "${CAMPAIGN}" <<'PY'
import json, sys
b = json.load(open(sys.argv[1]))
for c in b["campaigns"]:
    if c["name"] == sys.argv[2]:
        print(b["deck_template"], c["request"], c["stat_scale"], c["expect"], c["role"])
        break
else:
    sys.exit("no campaign %r in bench.json (have: %s)"
             % (sys.argv[2], ", ".join(c["name"] for c in b["campaigns"])))
PY
) || { echo "${TAG}: ${BENCH_DIR}/bench.json does not declare this campaign." >&2; exit 2; }

TMPL="${BENCH_DIR}/${TMPL_NAME}"
REQUEST_SRC="${BENCH_DIR}/${REQUEST_NAME}"
for f in "${TMPL}" "${REQUEST_SRC}"; do
  [[ -f "${f}" ]] || { echo "${TAG}: ${f} (named by bench.json) is missing." >&2; exit 2; }
done

# shellcheck source=env.sh
source "${SIM_DIR}/env.sh" || { echo "${TAG}: sim/env.sh refused; see the error above." >&2; exit 3; }
# shellcheck source=runner-lib.sh
source "${SIM_DIR}/runner-lib.sh"

cm5_gate "${TAG}" ngspice klt python3 sha256sum git
read -r -a BENCH_OSDI < <(python3 -I -c '
import json, sys
print(" ".join(json.load(open(sys.argv[1]))["osdi"]))' "${BENCH_DIR}/bench.json") \
  || { echo "${TAG}: bench.json has no readable 'osdi' list." >&2; exit 2; }
cm5_osdi_gate "${TAG}" "${BENCH_OSDI[@]}"
cm5_pinned_source "${TAG}" "${REPO_DIR}"

WORK="${SIM_DIR}/build/${BENCH}"
rm -rf "${WORK}"; mkdir -p "${WORK}/out"
cm5_stage_dut "${TAG}" "${REPO_DIR}" "${WORK}"

# ---- the statistical-magnitude scale block, generated from the PIN --------------------
# A campaign with stat_scale 1 gets an empty block and runs the pinned libraries exactly as
# they are. A campaign that scales reads each magnitude's nominal value out of the pinned
# library bench.json names for it and writes `<name> = <nominal * scale>`; a name that
# cannot be read at the pin is a hard error (exit 3), because an inflated control that
# silently failed to inflate would come back as a `not_detected` negative control and read
# as a finding about the design.
SCALE_BLOCK="${WORK}/stat-scale.inc"
python3 -I - "${BENCH_DIR}/bench.json" "${STAT_SCALE}" "${CM5_NGSPICE_MODELS}" "${SCALE_BLOCK}" <<'PY'
import json, re, sys
bench_p, scale, models_dir, out_p = sys.argv[1:]
scale = float(scale)
spec = json.load(open(bench_p))["stat_scale_params"]
lines = []
if scale != 1.0:
    missing = []
    for name, where in sorted(spec.items()):
        if name.startswith("_"):
            continue
        path = "%s/%s" % (models_dir, where["file"])
        try:
            text = open(path).read()
        except OSError as exc:
            missing.append("%s: %s" % (name, exc))
            continue
        # `.param <name> = <number>` at the pin; the statistical libraries state plain
        # numeric magnitudes, never expressions, so anything else is a pin change and
        # must stop the run rather than be guessed at.
        m = re.search(r"^\s*\.param\s+%s\s*=\s*([-+0-9.eE]+)\s*(?:;.*)?$" % re.escape(name),
                      text, re.MULTILINE)
        if not m:
            missing.append("%s: no plain numeric `.param %s = <number>` in %s"
                           % (name, name, where["file"]))
            continue
        lines.append(".param %s = %s ; %s x %g (pinned %s)"
                     % (name, "%.12g" % (float(m.group(1)) * scale), where["file"],
                        scale, m.group(1)))
    if missing:
        sys.exit("stat_scale %g cannot be applied at the pin:\n  %s"
                 % (scale, "\n  ".join(missing)))
with open(out_p, "w") as f:
    f.write("\n".join(lines) + ("\n" if lines else ""))
print("stat_scale %g: %d parameter(s) scaled" % (scale, len(lines)), file=sys.stderr)
PY
[[ -f "${SCALE_BLOCK}" ]] || { echo "${TAG}: could not build the scale block from the pin." >&2; exit 3; }

# ---- deck: the bench fixture, with @@WORK@@, bench.json's substitutions and the block ---
# Line 1 is a generated `*` comment on purpose (issue #19), as for the grid benches.
DECK="${WORK}/deck.cir"
python3 -I - "${TMPL}" "${BENCH_DIR}/bench.json" "${WORK}" "${SCALE_BLOCK}" "${DECK}" <<'PY'
import json, sys
tmpl_p, bench_p, work, block_p, out = sys.argv[1:]
subs = dict(json.load(open(bench_p)).get("deck_substitutions") or {})
subs["WORK"] = work
subs["STAT_SCALE_BLOCK"] = open(block_p).read().rstrip("\n")
text = open(tmpl_p).read()
for key, value in subs.items():
    text = text.replace("@@%s@@" % key, str(value))
left = [l for l in text.splitlines() if "@@" in l]
if left:
    sys.exit("deck template still has an unsubstituted placeholder: %s" % left[0].strip())
body = [l for l in text.splitlines() if not l.startswith("*")]
with open(out, "w") as f:
    f.write("* sg13cmos5l closed-loop-vref-mc deck -- generated by sim/mc-run.sh from\n"
            "* vref-mc.cir.tmpl and the pinned model libraries; do not edit.\n"
            "* klt sim .include's this file, so this deck carries no SPICE title line.\n")
    f.write("\n".join(body).rstrip() + "\n")
PY

# ---- request: the committed campaign request, with `netlist` pointed at the deck -------
# Nothing else is rewritten, for the same reason as the grid runner: the model sections stay
# PDK-relative and the osdi_preload entries stay `$PDK_ROOT/...`, so the fleet runner
# resolves both on its own box.
REQUEST="${WORK}/request.json"
python3 -I - "${REQUEST_SRC}" "${REQUEST}" "${DECK}" <<'PY'
import json, sys
src, dst, deck = sys.argv[1:]
r = json.load(open(src))
r["netlist"] = deck
json.dump(r, open(dst, "w"), indent=2)
PY

# $CM5_MC_DRY_RUN=1 stops here and validates the rendered request instead of submitting
# it: `klt sim --dry-run` resolves the backend, expands the unit list, derives the
# per-sample seeds and checks the staging closure without running ngspice or touching S3.
# Nothing is written under the bench directory, so a dry run never consumes an
# append-only artifact name. This is how the deck, the generated scale block and the
# request shape are checked before any fleet time is spent on them.
if [[ "${CM5_MC_DRY_RUN:-0}" == "1" ]]; then
  echo "${TAG}: CM5_MC_DRY_RUN=1 -- validating only, nothing is submitted or written." >&2
  echo "--- generated deck (${DECK}) ---" >&2
  cat "${DECK}" >&2
  klt sim --dry-run --backend "${CM5_GRID_BACKEND:-batch}" "${REQUEST}"
  exit $?
fi

mkdir -p "${BENCH_DIR}/records" "${BENCH_DIR}/envelopes"
cm5_record_path "${TAG}" "${REPO_DIR}" "${BENCH_DIR}/records"
NAME="${STAMP}-${SHA}.${CAMPAIGN}.json"
REC="${BENCH_DIR}/records/${NAME}"
ENVELOPE="${BENCH_DIR}/envelopes/${NAME}"
for p in "${REC}" "${ENVELOPE}"; do
  [[ ! -e "${p}" ]] || { echo "${TAG}: ${p} exists; artifacts are append-only." >&2; exit 4; }
done

cm5_grid_submit "${TAG}" "${REQUEST}" "${WORK}/out" "${WORK}/envelope.json" "${WORK}/klt.err"

set +e
python3 -I - "${WORK}/envelope.json" "${ENVELOPE}" "${REC}" "${NAME}" "${BENCH_DIR}/bench.json" \
  "${DECK}" "${TMPL}" "${REQUEST_SRC}" "${CM5_DUT_FETCHED}" "${CM5_DUT_SOURCE_PATH}" \
  "${NGSPICE_VERSION}" "${CM5_PDK_REVISION}" "${SHA}" "${STAMP}" "${SIM_DIR}/pdk.json" \
  "${SRC_REPO}" "${SRC_COMMIT}" "${CM5_KLT_RC}" "${CM5_BACKEND}" "${WORK}/klt.err" \
  "${BENCH}" "${SIM_DIR}/tools" "${CAMPAIGN}" "${ROLE}" "${EXPECT}" "${STAT_SCALE}" \
  "${SCALE_BLOCK}" <<'PY'
import json, sys
(env_p, envelope_out, rec_p, envelope_name, bench_p, deck_p, tmpl_p, request_p, dut_p,
 dut_rel, ngspice, pdk_rev, sha, stamp, pin_p, src_repo, src_commit, klt_rc, backend,
 klt_err_p, bench, tools_dir, campaign, role, expect, stat_scale, block_p) = sys.argv[1:]
sys.path.insert(0, tools_dir)
from cm5_record import klt_version as get_klt_version, sha256, write_record

bench_meta = json.load(open(bench_p))
pin = json.load(open(pin_p))
try:
    envelope = json.load(open(env_p))
except Exception:
    envelope = None

# The envelope is committed verbatim whatever it says -- it is the cited artifact, and a
# campaign that failed is evidence of a campaign that failed. Only an unparseable submit
# has nothing to commit.
if envelope is not None:
    write_record(envelope_out, envelope)

MEAS = bench_meta["yield"]["measurement"]


def statistics(env):
    """The per-point statistics of the graded measurement, straight out of klt sim's own
    Monte Carlo rollup. Nothing is recomputed here: `by_corner` IS the per-point
    population, and re-deriving it from corners[] would be a second implementation of a
    statistic the envelope already publishes."""
    if env is None:
        return None
    for m in env.get("measurements") or []:
        if m.get("name") != MEAS:
            continue
        mc = m.get("monte_carlo")
        if not mc:
            return None
        return {
            "measurement": MEAS,
            "unit": m.get("unit"),
            "pooled": {k: mc.get(k) for k in
                       ("n", "errored", "inconclusive", "mean", "stddev", "min", "max",
                        "quantiles", "sigma_window")},
            "by_point": [
                {k: c.get(k) for k in ("corner_id", "n", "errored", "inconclusive",
                                       "mean", "stddev", "min", "max", "quantiles",
                                       "sigma_window")}
                for c in (mc.get("by_corner") or [])],
        }
    return None


stats = statistics(envelope)
env_mc = ((envelope or {}).get("environment") or {}).get("monte_carlo") or {}

# ---- the declared expectation --------------------------------------------------------
# `zero_spread`: EVERY point must report a sample standard deviation of exactly 0.0 and
# min == max. Not "small": exactly zero. The deterministic sections contain no gauss or
# agauss call at all, so any non-zero spread means the control did not control anything.
# `spread`: every point must report a non-zero, finite stddev -- a campaign that asked for
# variation and got none is not evidence of a tight design, it is a dead sampler.
expectation = {"expect": expect, "met": None, "offending_points": [], "detail": None}
if stats is not None:
    bad = []
    for p in stats["by_point"]:
        sd, lo, hi = p.get("stddev"), p.get("min"), p.get("max")
        if expect == "zero_spread":
            if sd != 0.0 or lo != hi:
                bad.append({"corner_id": p.get("corner_id"), "stddev": sd,
                            "min": lo, "max": hi})
        elif expect == "spread":
            if not sd:
                bad.append({"corner_id": p.get("corner_id"), "stddev": sd})
    expectation["met"] = not bad and bool(stats["by_point"])
    expectation["offending_points"] = bad
    expectation["detail"] = (
        "every point reports stddev exactly 0.0 and min == max"
        if expect == "zero_spread" and not bad else
        "every point reports a non-zero stddev" if expect == "spread" and not bad else
        "%d point(s) contradict the declared expectation" % len(bad))

reason = None
if int(klt_rc) != 0:
    reason = "klt sim exited %s: %s" % (klt_rc, open(klt_err_p).read()[-600:].strip())
elif envelope is None:
    reason = "klt sim wrote no parseable JSON envelope"
elif stats is None:
    reason = "the envelope carries no monte_carlo rollup for %r" % MEAS
elif envelope.get("status") != "pass":
    reason = "campaign status %r: %s/%s units passed" % (
        envelope.get("status"), envelope.get("passed"), envelope.get("corner_count"))

staged = ((envelope or {}).get("environment") or {}).get("staged_model_inputs") or []
remote = ((envelope or {}).get("environment") or {}).get("remote") or {}

# A campaign large enough to be split (batch.job_ceiling_check "split") comes back as
# SEVERAL fleet jobs, and `klt sim` reports them as a list under `environment.remote.fleet`
# rather than as the flat single-job block a 45-point grid gets. Read both shapes: the
# per-job `runner_model_inputs` is the only thing that binds the models the workers
# actually loaded to sim/pdk.json's pin, and a campaign that silently stopped reporting it
# because it grew past one job would quietly lose that binding (sim/README.md "What the
# fleet runner cannot prove").
jobs = remote.get("fleet")
if not isinstance(jobs, list):
    jobs = [remote] if remote.get("job_id") else []


def models_match(job):
    got = job.get("runner_model_inputs")
    if not staged or got is None:
        return None
    return ({s["name"]: s["sha256"] for s in staged}
            == {s["name"]: s["sha256"] for s in got})


per_job = [{"job_id": j.get("job_id"),
            "state": j.get("state"),
            "exit_code": j.get("exit_code"),
            "instance_type": j.get("instance_type"),
            "lifecycle": j.get("lifecycle"),
            "elapsed_seconds": j.get("elapsed_seconds"),
            "runner_klt_version": j.get("runner_klt_version"),
            "runner_compatibility": j.get("runner_compatibility"),
            "runner_model_input_count": (None if j.get("runner_model_inputs") is None
                                         else len(j["runner_model_inputs"])),
            "staged_models_hashes_match": models_match(j)}
           for j in jobs]
verdicts = [j["staged_models_hashes_match"] for j in per_job]
# True only when EVERY job that ran reported back the hashes this host staged. One job
# that did not report them leaves the whole campaign unbound, so the aggregate is null or
# False rather than "mostly true".
all_match = (True if (per_job and all(v is True for v in verdicts))
             else False if any(v is False for v in verdicts)
             else None)
record = {
    "schema_version": 1,
    "kind": bench_meta["kind"],
    "label": "SIMULATED",
    "status": "failed" if reason else ("ok" if expectation["met"] else "expectation_failed"),
    "bench": bench,
    "campaign": campaign,
    "campaign_role": role,
    "testbench": bench_meta["testbench"],
    "spec_rows": bench_meta["spec_rows"],
    "criteria": bench_meta["criteria"],
    "timestamp_utc": stamp,
    "repo_git_sha": sha,
    "pdk_revision": pdk_rev,
    "pdk": {"name": pin["pdk"], "pin_file": "sim/pdk.json"},
    "source_repo": src_repo,
    "source_commit": src_commit,
    "source_path": dut_rel,
    "source_file_sha256": sha256(dut_p),
    "simulator": {"ngspice": ngspice, "klt": get_klt_version(), "backend": backend},
    "deck_sha256": sha256(deck_p),
    "template_sha256": sha256(tmpl_p),
    "request_sha256": sha256(request_p),
    "osdi_preload": bench_meta["osdi"],
    "envelope": "sim/%s/envelopes/%s" % (bench, envelope_name) if envelope is not None else None,
    # The seed, N and sampling axis T1 item 6 asks a Monte Carlo record to state, quoted
    # from the envelope's own echo rather than from the request, so the record describes
    # what RAN.
    "monte_carlo": {
        "n": env_mc.get("n"),
        "seed": env_mc.get("seed"),
        "vary": env_mc.get("vary"),
        "seed_scope": env_mc.get("seed_scope"),
        "k_sigma": env_mc.get("k_sigma"),
        "quantiles": env_mc.get("quantiles"),
        "family_mismatch": env_mc.get("family_mismatch"),
        "unseeded_sources": env_mc.get("unseeded_sources"),
        "points": len((stats or {}).get("by_point") or []),
        "units": (envelope or {}).get("corner_count"),
    },
    "stat_scale": float(stat_scale),
    "stat_scale_block": open(block_p).read(),
    "expectation": expectation,
    "statistics": stats,
    # What binds the models that RAN to sim/pdk.json's pin; see sim/grid-run.sh and
    # sim/README.md "What the fleet runner cannot prove".
    "models_staged": {
        "count": len(staged),
        "jobs_reporting": sum(1 for v in verdicts if v is not None),
        "hashes_match": all_match,
        "files": [{"name": s["name"], "kind": s["kind"], "sha256": s["sha256"]} for s in staged],
    },
    # The fleet jobs this campaign actually ran as, by id -- the out-of-band handle for
    # anyone re-reading a run against the fleet's own logs. A split campaign has several.
    "fleet_jobs": per_job,
}
if reason:
    record["failure_reason"] = reason
write_record(rec_p, record)
print("%s/%s: wrote %s" % (bench, campaign, rec_p))
if envelope is not None:
    print("%s/%s: wrote %s" % (bench, campaign, envelope_out))
if reason:
    print("%s/%s: NOT PASSED: %s" % (bench, campaign, reason), file=sys.stderr)
    sys.exit(5)
pooled = stats["pooled"]
print("  %s fleet job(s): %s" % (
    len(per_job), ", ".join(j["job_id"] or "?" for j in per_job) or "(none reported)"))
print("  staged models bound to the pin by hash on every job: %s" % all_match)
print("  %s units, %s points, seed %s, N %s per point (simulated, %s backend)" % (
    envelope.get("corner_count"), record["monte_carlo"]["points"],
    record["monte_carlo"]["seed"], record["monte_carlo"]["n"], backend))
print("  %s pooled: mean %s  sigma %s  min %s  max %s" % (
    MEAS, pooled["mean"], pooled["stddev"], pooled["min"], pooled["max"]))
if pooled.get("sigma_window"):
    w = pooled["sigma_window"]
    print("  %s pooled mean +/- %s sigma: [%s, %s]" % (MEAS, w.get("k"), w.get("low"),
                                                       w.get("high")))
if not expectation["met"]:
    print("%s/%s: EXPECTATION %r NOT MET: %s" % (bench, campaign, expect,
                                                 expectation["detail"]), file=sys.stderr)
    for b in expectation["offending_points"][:10]:
        print("    %s" % json.dumps(b), file=sys.stderr)
    sys.exit(7)
print("  expectation %r met: %s" % (expect, expectation["detail"]))
PY
exit $?
