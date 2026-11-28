#!/usr/bin/env bash
# Offline consistency test for the statistical Monte Carlo bench sim/closed-loop-vref-mc
# (issue #31, T1 item 6). Needs only bash and python3: no PDK, no ngspice, no klt, no
# network. Run: bash sim/tests/test-mc-bench.sh
#
# What it guards, and why each one can break silently:
#
#  1. The bench directory is well formed: every campaign bench.json declares has its
#     request, the deck template exists, and the `yield` block names a limits file that
#     exists and a measurement the requests actually declare.
#  2. THE EVIDENCE-REPORTING WINDOW IS QUOTED, NOT INVENTED. yield-limits.json's min and
#     max must still equal, to the digit, the smallest and largest `vref_v` in the
#     item-5 envelope the manifest cites for `vref_nominal`. This is the check that keeps
#     the one number in this bench that could be mistaken for a ratified bound tied to a
#     committed measurement -- edit the window and this test fails, which is the point.
#  3. The campaigns are comparable and are what they claim to be: the zero control selects
#     no statistical section at all, the line and inflated campaigns do, and line /
#     inflated run the same axes and the same measurements, because `klt yield-samples`
#     pairs them as nominal and negative control.
#  4. The line campaign really does draw N >= 300 per point, which is the sample size
#     the issue and T1 item 6 ask a statistical claim to carry.
#  5. No committed request names a path that only exists on the submitting host, and each
#     stages its model inputs -- the same portability contract the item-5 grids have, for
#     the same reason.
#  6. The deck template carries no SPICE title line, no `.control` block and no `.end`
#     card (issue #19), every @@PLACEHOLDER@@ it uses is one the runner supplies, and it
#     instantiates the wrapped staged DUT exactly once with runner-lib.sh's cell name and
#     pin order, with `sub!` declared `.global` where it drives it (issues #80/#83,
#     decision records 0013 and 0014-substrate-net-global).
#  7. Every committed envelope is paired with a record of the same name that carries
#     schema_version 1, names its own envelope, names the fleet job(s) it ran as, binds
#     the staged models by hash on every one of them, and reports its expectation as met -- and the zero control's record shows
#     stddev exactly 0.0 at EVERY point, which is the whole of its evidential value.
#  8. The committed `klt yield` report is internally consistent with the bench: it grades
#     the bench's measurement, its sample-set document is committed beside it, that
#     document's `derivation` names the two committed envelopes, the yield-step record
#     beside it names the klt build that produced the report and hashes every input,
#     and its negative control reached a verdict rather than being absent.
#  9. The manifest's item-6 declaration agrees with all of it: every declared row appears
#     in spec/target-spec.md's Row id column, every declared row is cited or a declared
#     gap, no row is both, and every citation names a committed file.
#
# Negative controls (each run while writing it): changing yield-limits.json's `max` by one
# digit fails check 2 ("yield window max equals the item-5 envelope's measured max");
# adding `res_stat` to the zero campaign's sections fails check 3 ("zero campaign selects
# no statistical section"); dropping the line campaign's n to 299 fails check 4; deleting
# the record beside an envelope fails check 7. All exit 1. Inventoried as a T1 item-10
# hygiene check (attest/item10.json), so CI re-runs it through `klt signoff --attest 10`.
#
# Malformed-request controls (issue #194), run by sim/tests/test-malformed-request.sh rather
# than by hand: a campaign request whose `corners` is missing or wrong-typed, whose
# `sections` is an object or a string, whose `supply_v` has no `Vvdd`, whose `temperature_c`
# is not a list, whose `measurements` or `monte_carlo` is absent, or whose `netlist_source`
# is not a string is reported as FAIL lines naming the campaign and the key ("zero request
# declares a corners mapping: None"), and the suite still runs to its closing "N failure(s)"
# line. Before issue #194 the same input raised out of sections()/axes() or
# check_request_portability, printed no FAIL line, and skipped every check after it.
#
# Check 5, the deck-template half of check 6, check 7's point coverage, check 9 and the
# deck_template/testbench path agreement are shared with sim/tests/test-grid-benches.sh
# through sim/tests/bench_checks.py (issue #192), which also owns this suite's
# `check`/`load`/`exists` helpers.
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python3 -I - "${root}" "${root}/sim/tests" <<'PY'
import json, os, re, sys

root, libdir = sys.argv[1], sys.argv[2]
sys.path.insert(0, libdir)
from bench_checks import (CheckRunner, check_deck_path_agreement, check_deck_template,
                          check_envelope_coverage, check_manifest_spec_rows,
                          check_request_portability, read_runner_dut_contract)

BENCH = "closed-loop-vref-mc"
BD = "sim/%s" % BENCH
checks = CheckRunner(root)
check, load, exists = checks.check, checks.load, checks.exists


# ---- 1. the bench directory is well formed ----------------------------------------------
meta = load("%s/bench.json" % BD)
missing = [k for k in ("bench", "kind", "testbench", "spec_rows", "criteria", "osdi",
                       "deck_substitutions", "deck_template", "campaigns",
                       "stat_scale_params", "yield") if k not in meta]
check("bench.json has every key mc-run.sh and mc-yield.sh read", not missing, str(missing))
check("bench.json 'bench' matches its directory", meta.get("bench") == BENCH, meta.get("bench"))
check("deck template exists (%s)" % meta.get("deck_template"),
      exists("%s/%s" % (BD, meta.get("deck_template", ""))))
check_deck_path_agreement(checks, BENCH, meta)

campaigns = {c["name"]: c for c in meta.get("campaigns", [])}
requests = {}
for name, c in campaigns.items():
    rel = "%s/%s" % (BD, c["request"])
    if not exists(rel):
        check("%s campaign request exists (%s)" % (name, c["request"]), False)
        continue
    check("%s campaign request exists (%s)" % (name, c["request"]), True)
    requests[name] = load(rel)
    check("%s campaign declares a stat_scale" % name,
          isinstance(c.get("stat_scale"), (int, float)) and c["stat_scale"] > 0,
          repr(c.get("stat_scale")))
    check("%s campaign declares an expectation mc-run.sh can grade" % name,
          c.get("expect") in ("spread", "zero_spread"), repr(c.get("expect")))

ycfg = meta["yield"]
limits_rel = "%s/%s" % (BD, ycfg["limits"])
check("yield limits file exists (%s)" % ycfg["limits"], exists(limits_rel))
for role in ("nominal_campaign", "negative_control_campaign"):
    check("yield %s names a declared campaign" % role, ycfg.get(role) in campaigns,
          repr(ycfg.get(role)))
MEAS = ycfg["measurement"]
for name, req in requests.items():
    check("%s request declares the graded measurement %r" % (name, MEAS),
          any(m.get("name") == MEAS for m in req.get("measurements", [])))

# ---- 2. the evidence-reporting window is quoted from committed item-5 evidence ----------
# The window is the one number in this bench a reader could mistake for a ratified bound.
# spec/target-spec.md ratifies NO number for this row, so the window has to be traceable
# to a measurement rather than chosen -- and this check is what keeps it traceable.
limits = load(limits_rel)
window = (limits.get("measurements") or {}).get(MEAS) or {}
manifest = load("manifests/sg13cmos5l-bandgap.json")
item5 = {e["file"]: e for e in manifest["evidence"]["5"]}
src = [f for f, e in item5.items() if "vref_nominal" in e.get("rows", [])]
check("the item-5 manifest still cites exactly one envelope for vref_nominal",
      len(src) == 1, str(src))
if len(src) == 1 and exists(src[0]):
    vals = [m["value"] for c in load(src[0])["corners"] for m in c["measurements"]
            if m["name"] == MEAS and m.get("value") is not None]
    check("the cited item-5 envelope reports %r at every one of its points" % MEAS,
          len(vals) == load(src[0])["corner_count"],
          "%d of %d" % (len(vals), load(src[0])["corner_count"]))
    if vals:
        check("yield window min equals the item-5 envelope's measured min",
              window.get("min") == min(vals), "%r vs %r" % (window.get("min"), min(vals)))
        check("yield window max equals the item-5 envelope's measured max",
              window.get("max") == max(vals), "%r vs %r" % (window.get("max"), max(vals)))
elif len(src) == 1:
    check("the cited item-5 envelope is in this tree (%s)" % src[0], False)
check("the yield limits declare no target_yield (the row ratifies none)",
      "target_yield" not in window and "target_yield" not in limits,
      "a target_yield would make an unratified row pass or fail a claim nobody ratified")
check("the yield limits tag the measurement with the spec row it is about",
      window.get("spec_row") == "vref_untrimmed_line_3sigma", repr(window.get("spec_row")))

# ---- 3/4. the campaigns are what they claim to be ---------------------------------------
STAT = re.compile(r"stat|mismatch")


def sections_and_axes(name, req):
    """(section names, (Vvdd, temperature_c)) a campaign's request declares, each axis
    sorted. A missing or wrong-typed `corners`, `process`, `sections`, `supply_v` or
    `temperature_c` fails by name and reads empty, so a malformed request is reported and
    the checks after it still run instead of a traceback (issue #194)."""
    c = req.get("corners")
    if not isinstance(c, dict):
        check("%s request declares a corners mapping" % name, False, repr(c))
        c = {}
    procs = c.get("process")
    if not isinstance(procs, list):
        check("%s request declares corners.process as a list" % name, False, repr(procs))
        procs = []
    secs = []
    for p in procs:
        if not isinstance(p, dict):
            check("%s corners.process entry is an object" % name, False, repr(p))
            continue
        entries = p.get("sections")
        if not isinstance(entries, list):
            check("%s corner %r sections is a list" % (name, p.get("name")), False, repr(entries))
            continue
        for s in entries:
            if not isinstance(s, dict):
                check("%s corner %r sections entry is an object" % (name, p.get("name")),
                      False, repr(s))
            elif not isinstance(s.get("section"), str):
                check("%s corner %r sections entry names a section" % (name, p.get("name")),
                      False, repr(s))
            else:
                secs.append(s["section"])
    supply = c.get("supply_v")
    if not isinstance(supply, dict):
        check("%s request declares a corners.supply_v mapping" % name, False, repr(supply))
        supply = {}
    axes = []
    for key, v in (("supply_v.Vvdd", supply.get("Vvdd")),
                   ("temperature_c", c.get("temperature_c"))):
        if not isinstance(v, list):
            check("%s request declares corners.%s as a list" % (name, key), False, repr(v))
            v = []
        axes.append(sorted(v, key=repr))
    return secs, tuple(axes)


def measurement_names(name, req):
    """A request's measurement names, in order. A missing or wrong-typed `measurements` or
    entry fails by name and reads empty (issue #194)."""
    ms = req.get("measurements")
    if not isinstance(ms, list):
        check("%s request declares measurements as a list" % name, False, repr(ms))
        return []
    names = []
    for m in ms:
        if not isinstance(m, dict):
            check("%s measurement entry is an object" % name, False, repr(m))
        elif not isinstance(m.get("name"), str):
            check("%s measurement entry names a measurement" % name, False, repr(m))
        else:
            names.append(m["name"])
    return names


secs, ax = {}, {}
for name, req in requests.items():
    secs[name], ax[name] = sections_and_axes(name, req)
if "zero" in requests:
    check("zero campaign selects no statistical section",
          not any(STAT.search(s) for s in secs["zero"]), str(sorted(set(secs["zero"]))))
for name in ("line", "inflated", "families"):
    if name in requests:
        check("%s campaign selects at least one statistical section" % name,
              any(STAT.search(s) for s in secs[name]), str(sorted(set(secs[name]))))
if "line" in requests and "zero" in requests:
    check("zero control runs the same axes as the line campaign", ax["zero"] == ax["line"])
if "line" in requests and "inflated" in requests:
    ln, inf = requests["line"], requests["inflated"]
    check("negative control runs the same axes as the line campaign", ax["inflated"] == ax["line"])
    check("negative control declares the same measurements as the line campaign",
          measurement_names("inflated", inf) == measurement_names("line", ln))
    check("negative control is the inflated campaign and line is not",
          campaigns["inflated"]["stat_scale"] > campaigns["line"]["stat_scale"] == 1)
if "line" in requests:
    mc = requests["line"].get("monte_carlo") or {}
    check("line campaign draws N >= 300 per point", mc.get("n", 0) >= 300, str(mc.get("n")))
    check("line campaign declares an integer seed", isinstance(mc.get("seed"), int),
          repr(mc.get("seed")))
    check("line campaign declares k_sigma 3 (the row is a 3 sigma claim)",
          mc.get("k_sigma") == 3, repr(mc.get("k_sigma")))
for name, req in requests.items():
    mc = req.get("monte_carlo") or {}
    check("%s request declares monte_carlo n/seed/vary" % name,
          all(k in mc for k in ("n", "seed", "vary")), str(sorted(mc)))

# ---- 5. no host-local path in a committed request ---------------------------------------
for name, req in requests.items():
    check_request_portability(checks, name, req)

# ---- 6. the deck template ----------------------------------------------------------------
# The staged DUT is wrapped in a subckt (issue #80, decision record 0013) and the deck
# instantiates it, so the cell name and pin order live in TWO places that must agree; the
# substrate tie (issue #83, decision record 0014-substrate-net-global) needs `sub!` to be
# an ngspice GLOBAL net, and no measured value would look wrong without one. Both are
# checked by the helper the grid benches share (sim/tests/bench_checks.py), so a drift
# between the staging header and an `Xdut` card fails offline here instead of as an
# "unknown subckt" at load time on the fleet, one submitted campaign later.
_, _, want_xdut = read_runner_dut_contract(checks)
with open(os.path.join(root, BD, meta["deck_template"])) as f:
    tmpl = f.read()
check_deck_template(checks, None, tmpl, want_xdut)
placeholders = set(re.findall(r"@@([A-Z_]+)@@", tmpl))
supplied = set(meta["deck_substitutions"]) | {"WORK", "STAT_SCALE_BLOCK"}
check("every deck placeholder is supplied", placeholders <= supplied,
      "unsupplied: %s" % sorted(placeholders - supplied))
for token in sorted(placeholders):
    check("placeholder %s appears exactly once (a comment holding it would expand into "
          "live cards)" % token, tmpl.count("@@%s@@" % token) == 1,
          str(tmpl.count("@@%s@@" % token)))

# ---- 7. committed envelopes, their records, and the controls' own evidence ---------------
env_dir = os.path.join(root, BD, "envelopes")
envelopes = sorted(os.listdir(env_dir)) if os.path.isdir(env_dir) else []
check("at least one campaign envelope is committed", bool(envelopes))
seen_campaigns = set()
for name in envelopes:
    rel = "%s/envelopes/%s" % (BD, name)
    rec_rel = "%s/records/%s" % (BD, name)
    if not exists(rec_rel):
        check("%s has a record of the same name" % name, False, rec_rel)
        continue
    check("%s has a record of the same name" % name, True)
    rec = load(rec_rel)
    seen_campaigns.add(rec.get("campaign"))
    check("%s record carries schema_version 1" % name, rec.get("schema_version") == 1)
    check("%s record names its own envelope" % name, rec.get("envelope") == rel,
          str(rec.get("envelope")))
    check("%s record binds the staged models by hash" % name,
          (rec.get("models_staged") or {}).get("hashes_match") is True,
          json.dumps((rec.get("models_staged") or {}).get("hashes_match")))
    # The fleet job ids are the out-of-band handle for re-reading a run against the
    # fleet's own logs, and a split campaign runs as several jobs, so "at least one id,
    # and an id for every job" is the check -- not "the job id", which only a one-job
    # run has.
    jobs = rec.get("fleet_jobs")
    check("%s record names the fleet job(s) it ran as" % name,
          isinstance(jobs, list) and bool(jobs) and all(j.get("job_id") for j in jobs),
          json.dumps(jobs)[:200])
    check("%s record states its seed and N" % name,
          isinstance((rec.get("monte_carlo") or {}).get("seed"), int)
          and isinstance((rec.get("monte_carlo") or {}).get("n"), int))
    check("%s record reports its declared expectation as met" % name,
          (rec.get("expectation") or {}).get("met") is True,
          json.dumps(rec.get("expectation")))
    check("%s record status is ok" % name, rec.get("status") == "ok", str(rec.get("status")))
    env = load(rel)
    check_envelope_coverage(checks, "%s covers every expanded unit with a verdict" % name, env)
    if rec.get("campaign") == "zero":
        pts = (rec.get("statistics") or {}).get("by_point") or []
        bad = [p["corner_id"] for p in pts if p.get("stddev") != 0.0 or p.get("min") != p.get("max")]
        check("zero control reports stddev exactly 0.0 at every one of its %d points" % len(pts),
              bool(pts) and not bad, str(bad))
        # And the stronger claim the same run supports for free: with its statistics off,
        # the Monte Carlo harness must land on the number the DETERMINISTIC item-5 grid
        # already recorded at the same point. Any difference means the two benches are
        # not solving the same circuit, which would invalidate every spread measured
        # against the item-5 envelope's window.
        if len(src) == 1 and exists(src[0]):
            grid = {c["corner_id"]: m["value"] for c in load(src[0])["corners"]
                    for m in c["measurements"] if m["name"] == MEAS}
            off = [(p["corner_id"], p.get("mean"), grid.get(p["corner_id"]))
                   for p in pts if grid.get(p["corner_id"]) != p.get("mean")]
            check("zero control reproduces the item-5 grid exactly at all %d shared points"
                  % len(pts), bool(pts) and not off, str(off[:4]))
for required in ("line", "zero", "inflated"):
    check("campaign %r has a committed envelope" % required, required in seen_campaigns,
          str(sorted(c for c in seen_campaigns if c)))

# ---- 8. the committed klt yield report ---------------------------------------------------
y_dir = os.path.join(root, BD, "yield")
reports = sorted(f for f in (os.listdir(y_dir) if os.path.isdir(y_dir) else [])
                 if f.endswith(".yield.json"))
check("a klt yield report is committed", bool(reports))
for name in reports:
    rel = "%s/yield/%s" % (BD, name)
    rep = load(rel)
    entry = next((m for m in rep.get("measurements") or [] if m.get("name") == MEAS), None)
    check("%s grades the bench's measurement %r" % (name, MEAS), entry is not None)
    if entry is None:
        continue
    samples_rel = "%s/yield/%s" % (BD, name.replace(".yield.json", ".samples.json"))
    check("%s has its sample-set document committed beside it" % name, exists(samples_rel),
          samples_rel)
    if exists(samples_rel):
        der = load(samples_rel).get("derivation") or {}
        for role in ("nominal", "negative_control"):
            p = (der.get(role) or {}).get("path")
            check("%s sample set's %s source is a committed envelope (%s)" % (name, role, p),
                  bool(p) and exists(p))
    rec_rel = "%s/yield/%s" % (BD, name.replace(".yield.json", ".yield-record.json"))
    check("%s has a yield-step record beside it" % name, exists(rec_rel), rec_rel)
    if exists(rec_rel):
        yr = load(rec_rel)
        # The report does not carry the klt build that produced it, and this host's own
        # `klt` cannot produce it (no klt_yield_native). The record is the only place the
        # build is written down, so an empty one would leave the cited artifact unattributed.
        check("%s yield record names the klt build that produced the report" % name,
              bool((yr.get("tool") or {}).get("version")),
              json.dumps(yr.get("tool")))
        for role in ("nominal_envelope", "negative_control_envelope", "limits", "sample_set"):
            src_ = (yr.get("inputs") or {}).get(role) or {}
            check("%s yield record hashes its %s input" % (name, role),
                  bool(src_.get("sha256")) and exists(src_.get("file", "")),
                  json.dumps(src_))
    nc = entry.get("negative_control") or {}
    check("%s negative control reached a verdict" % name,
          nc.get("verdict") in ("detected", "not_detected", "not_applicable"),
          repr(nc.get("verdict")))
    check("%s reports a sample-size verdict" % name,
          (entry.get("sample_size") or {}).get("verdict") in ("sufficient", "insufficient"),
          repr((entry.get("sample_size") or {}).get("verdict")))
    check("%s publishes a confidence interval with its yield" % name,
          ((entry.get("yield") or {}).get("empirical") or {}).get("confidence_interval")
          is not None)

# ---- 9. the manifest's item-6 declaration ------------------------------------------------
check_manifest_spec_rows(checks, manifest, "6", require_citations_exist=True)

sys.exit(checks.finish("all Monte Carlo bench consistency checks passed"))
PY
