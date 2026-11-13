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
#     stages its model inputs -- the same portability contract the item-5 grids have
#     (sim/tests/test-grid-benches.sh check 5), for the same reason.
#  6. The deck template carries no SPICE title line, no `.control` block and no `.end`
#     card (issue #19), and every @@PLACEHOLDER@@ it uses is one the runner supplies.
#  7. Every committed envelope is paired with a record of the same name that carries
#     schema_version 1, names its own envelope, names the fleet job(s) it ran as, binds
#     the staged models by hash on every one of them, and reports its expectation as met -- and the zero control's record shows
#     stddev exactly 0.0 at EVERY point, which is the whole of its evidential value.
#  8. The committed `klt yield` report is internally consistent with the bench: it grades
#     the bench's measurement, its sample-set document is committed beside it, that
#     document's `derivation` names the two committed envelopes, and its negative control
#     reached a verdict rather than being absent.
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
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python3 -I - "${root}" <<'PY'
import json, os, re, sys

root = sys.argv[1]
BENCH = "closed-loop-vref-mc"
BD = "sim/%s" % BENCH
fails = []


def check(name, ok, detail=""):
    if ok:
        print("PASS " + name)
    else:
        print("FAIL %s%s" % (name, (": " + detail) if detail else ""))
        fails.append(name)


def load(rel):
    with open(os.path.join(root, rel)) as f:
        return json.load(f)


def exists(rel):
    return os.path.isfile(os.path.join(root, rel))


# ---- 1. the bench directory is well formed ----------------------------------------------
meta = load("%s/bench.json" % BD)
missing = [k for k in ("bench", "kind", "testbench", "spec_rows", "criteria", "osdi",
                       "deck_substitutions", "deck_template", "campaigns",
                       "stat_scale_params", "yield") if k not in meta]
check("bench.json has every key mc-run.sh and mc-yield.sh read", not missing, str(missing))
check("bench.json 'bench' matches its directory", meta.get("bench") == BENCH, meta.get("bench"))
check("deck template exists (%s)" % meta.get("deck_template"),
      exists("%s/%s" % (BD, meta.get("deck_template", ""))))

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


def sections(req):
    return [s["section"] for p in req["corners"]["process"] for s in p["sections"]]


def axes(req):
    c = req["corners"]
    return (sorted(c["supply_v"]["Vvdd"]), sorted(c["temperature_c"]),
            sorted(p["name"] for p in c["process"]))


if "zero" in requests:
    secs = sections(requests["zero"])
    check("zero campaign selects no statistical section",
          not any(STAT.search(s) for s in secs), str(sorted(set(secs))))
for name in ("line", "inflated", "families"):
    if name in requests:
        secs = sections(requests[name])
        check("%s campaign selects at least one statistical section" % name,
              any(STAT.search(s) for s in secs), str(sorted(set(secs))))
if "line" in requests and "zero" in requests:
    check("zero control runs the same axes as the line campaign",
          axes(requests["zero"])[:2] == axes(requests["line"])[:2])
if "line" in requests and "inflated" in requests:
    ln, inf = requests["line"], requests["inflated"]
    check("negative control runs the same axes as the line campaign",
          axes(inf)[:2] == axes(ln)[:2])
    check("negative control declares the same measurements as the line campaign",
          [m["name"] for m in inf["measurements"]] == [m["name"] for m in ln["measurements"]])
    check("negative control is the inflated campaign and line is not",
          campaigns["inflated"]["stat_scale"] > campaigns["line"]["stat_scale"] == 1)
if "line" in requests:
    mc = requests["line"]["monte_carlo"]
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
    blob = json.dumps({k: v for k, v in req.items() if k != "_comment"})
    for bad in ("/home/", "/Users/", os.path.expanduser("~")):
        check("%s request has no %s path" % (name, bad), bad not in blob)
    for p in req["corners"]["process"]:
        for sec in p["sections"]:
            lib = sec.get("lib", "")
            check("%s corner lib %r is PDK-relative" % (name, lib),
                  bool(lib) and not lib.startswith("/") and not lib.startswith("$"))
    check("%s request declares models.pdk" % name, "pdk" in req.get("models", {}))
    check("%s request stages its model inputs" % name,
          req.get("options", {}).get("stage_model_inputs") is True)
    for entry in req.get("options", {}).get("osdi_preload", []):
        check("%s osdi_preload %r is runner-resolvable" % (name, entry),
              entry.startswith("$PDK_ROOT/"))
    check("%s request declares netlist_source schematic" % name,
          req.get("netlist_source") == "schematic", req.get("netlist_source"))

# ---- 6. the deck template ----------------------------------------------------------------
with open(os.path.join(root, BD, meta["deck_template"])) as f:
    tmpl = f.read()
body = [l for l in tmpl.splitlines() if l and not l.startswith("*")]
check("deck template line 1 is a comment", tmpl.splitlines()[0].startswith("*"))
check("deck template has no .control block",
      not any(l.lower().startswith(".control") for l in body))
check("deck template has no .end card", not any(l.strip().lower() == ".end" for l in body))
placeholders = set(re.findall(r"@@([A-Z_]+)@@", tmpl))
supplied = set(meta["deck_substitutions"]) | {"WORK", "STAT_SCALE_BLOCK"}
check("every deck placeholder is supplied", placeholders <= supplied,
      "unsupplied: %s" % sorted(placeholders - supplied))
for token in placeholders:
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
    check("%s covers every expanded unit with a verdict" % name,
          (env.get("passed") or 0) + (env.get("failed") or 0) == env.get("corner_count")
          and not env.get("errored") and not env.get("inconclusive"),
          "%s pass + %s fail of %s (errored %s, inconclusive %s)"
          % (env.get("passed"), env.get("failed"), env.get("corner_count"),
             env.get("errored"), env.get("inconclusive")))
    if rec.get("campaign") == "zero":
        pts = (rec.get("statistics") or {}).get("by_point") or []
        bad = [p["corner_id"] for p in pts if p.get("stddev") != 0.0 or p.get("min") != p.get("max")]
        check("zero control reports stddev exactly 0.0 at every one of its %d points" % len(pts),
              bool(pts) and not bad, str(bad))
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
rows6 = manifest.get("spec_rows", {}).get("6")
check("the manifest declares an item-6 row set", isinstance(rows6, list) and bool(rows6))
if isinstance(rows6, list):
    ids = [r["id"] for r in rows6]
    check("spec_rows.6 has no duplicate row id", len(ids) == len(set(ids)))
    gaps = {r["id"] for r in rows6 if r.get("gap")}
    ev6 = manifest.get("evidence", {}).get("6") or []
    covered = {row for e in ev6 for row in e.get("rows", [])}
    check("every declared item-6 row is cited or a declared gap",
          covered | gaps == set(ids), "unaccounted: %s" % sorted(set(ids) - (covered | gaps)))
    check("no item-6 row is both cited and a declared gap", not (covered & gaps),
          str(sorted(covered & gaps)))
    for e in ev6:
        check("item-6 citation %s is committed" % e.get("file"), exists(e.get("file", "")))
    with open(os.path.join(root, "spec/target-spec.md")) as f:
        spec_text = f.read()
    spec_ids = set()
    for line in spec_text.splitlines():
        if line.startswith("| "):
            cells = re.split(r"(?<!\\)\|", line)
            if len(cells) >= 3:
                spec_ids.update(re.findall(r"`([a-z0-9_]+)`", cells[2]))
    for rid in ids:
        check("item-6 row id %r appears in spec/target-spec.md's Row id column" % rid,
              rid in spec_ids)

print("" if fails else "all Monte Carlo bench consistency checks passed")
if fails:
    print("%d failure(s)" % len(fails))
sys.exit(1 if fails else 0)
PY
