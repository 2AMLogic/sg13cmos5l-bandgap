#!/usr/bin/env bash
# Offline consistency test for the five T1-item-5 PVT-grid benches (issue #30). Needs only bash
# and python3: no PDK, no ngspice, no klt, no network. Run: bash sim/tests/test-grid-benches.sh
#
# What it guards, and why each one can break silently:
#
#  1. Every bench directory sim/grid-run.sh can be pointed at is well formed, and the deck
#     template and request bench.json names really exist.
#  2. A bench's `spec_row` tags, its bench.json `spec_rows`, and the rows the manifest cites it
#     for all agree. If they drift, `klt signoff` reports the row `uncovered` and item 5 silently
#     loses coverage -- a manifest-only edit is enough to cause it.
#  3. Every row the manifest declares under `spec_rows.5` is either cited or a declared gap, and
#     every row id appears in spec/target-spec.md's Row id column. A typo'd row id would
#     otherwise read as an uncovered row with no hint of where it came from.
#  4. Every graded (`limits`-bearing) measurement tagged with a spec row is reachable: derived
#     coverage needs a PASSING, limits-bearing, tagged measurement, so a tag on a measurement
#     with no `limits` covers nothing.
#  5. No committed request names a path that only exists on the submitting host: `klt sim`
#     refuses those on `batch` (`models_lib_host_path`), and the point of the shape is that one
#     request serves a local probe and the fleet grid.
#  6. The deck templates carry no SPICE title line and no `.control` block (issue #19: `klt sim`
#     `.include`s the generated deck, so line 1 is not in title position and a `.control` block
#     would never run), and every `@@PLACEHOLDER@@` a template uses is one bench.json supplies.
#  7. Every committed envelope a manifest citation names exists, is graded exactly as the
#     bench declares (passing, or failing with the declared row set and point count -- see
#     `expected_failure` in bench.json), returns a verdict for every expanded point with no
#     errored or inconclusive ones, and is append-only paired with a record of the same name
#     that carries `schema_version`.
#
# Negative controls (each run while writing it, decision record 0011): retagging one manifest
# citation's `rows` to `psrr_dc_typo` fails check 2 ("closed-loop-psrr manifest rows equal
# bench.json's spec_rows") AND check 3 ("every declared row is cited or a declared gap:
# unaccounted: ['psrr_dc']"); changing closed-loop-psrr's declared `failing_points` from 24 to
# 23 fails check 7 ("failing point count equals the declared 23: 24 failing"); deleting its
# `expected_failure` block altogether fails check 7 twice ("cited envelope status is pass as
# declared: fail", "record status is ok as declared: failed"). All exit 1. Inventoried as a T1 item-10 hygiene check (attest/item10.json), so CI
# re-runs it through `klt signoff --attest 10 --check`.
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python3 -I - "${root}" <<'PY'
import json, os, re, sys

root = sys.argv[1]
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


BENCHES = [
    "closed-loop-vref-pvt",
    "closed-loop-vref-pvt-boxtc",
    "closed-loop-psrr",
    "closed-loop-iq",
    "closed-loop-startup",
]

manifest = load("manifests/sg13cmos5l-bandgap.json")

# ---- 1. bench directories are well formed -----------------------------------------------
meta, requests = {}, {}
for b in BENCHES:
    try:
        m = load("sim/%s/bench.json" % b)
    except Exception as exc:                                    # noqa: BLE001
        check("%s bench.json readable" % b, False, str(exc))
        continue
    meta[b] = m
    missing = [k for k in ("bench", "kind", "testbench", "spec_rows", "criteria", "osdi",
                           "deck_substitutions", "deck_template", "request") if k not in m]
    check("%s bench.json has every key grid-run.sh reads" % b, not missing, str(missing))
    check("%s bench.json 'bench' matches its directory" % b, m.get("bench") == b, m.get("bench"))
    for key in ("deck_template", "request"):
        rel = "sim/%s/%s" % (b, m.get(key, ""))
        check("%s %s exists (%s)" % (b, key, m.get(key)),
              os.path.isfile(os.path.join(root, rel)))
    try:
        requests[b] = load("sim/%s/%s" % (b, m["request"]))
    except Exception as exc:                                    # noqa: BLE001
        check("%s request readable" % b, False, str(exc))

# ---- 2/4. spec_row tags vs bench.json vs the manifest -----------------------------------
cited = {}
for entry in manifest["evidence"]["5"]:
    bench = entry["file"].split("/")[1]
    cited[bench] = entry

check("manifest item 5 cites exactly the five grid benches",
      sorted(cited) == sorted(BENCHES), "%s vs %s" % (sorted(cited), sorted(BENCHES)))

for b in BENCHES:
    req = requests.get(b)
    if req is None:
        continue
    tagged, graded_tagged = set(), set()
    for m in req.get("measurements", []):
        row = m.get("spec_row")
        if row:
            tagged.add(row)
            if m.get("limits"):
                graded_tagged.add(row)
    # step measurements may not carry spec_row at all; only top-level rows are claimed
    for step in req.get("analysis_steps", []):
        for m in step.get("measurements", []):
            check("%s step measurement %r carries no spec_row" % (b, m.get("name")),
                  "spec_row" not in m)
    declared = set(meta.get(b, {}).get("spec_rows", []))
    check("%s request tags exactly bench.json's spec_rows" % b, tagged == declared,
          "tagged %s vs bench.json %s" % (sorted(tagged), sorted(declared)))
    check("%s every tagged row has a limits-bearing measurement" % b,
          tagged == graded_tagged, "ungraded: %s" % sorted(tagged - graded_tagged))
    check("%s manifest rows equal bench.json's spec_rows" % b,
          set(cited.get(b, {}).get("rows", [])) == declared,
          "manifest %s vs bench.json %s" % (sorted(cited.get(b, {}).get("rows", [])),
                                            sorted(declared)))

# ---- 3. the declared row set, and the spec's own Row id column ---------------------------
spec_rows = manifest["spec_rows"]["5"]
ids = [r["id"] for r in spec_rows]
check("spec_rows.5 has no duplicate row id", len(ids) == len(set(ids)))
gaps = {r["id"] for r in spec_rows if r.get("gap")}
covered = {row for e in manifest["evidence"]["5"] for row in e["rows"]}
check("every declared row is cited or a declared gap", covered | gaps == set(ids),
      "unaccounted: %s" % sorted(set(ids) - (covered | gaps)))
check("no row is both cited and a declared gap", not (covered & gaps), sorted(covered & gaps))

with open(os.path.join(root, "spec/target-spec.md")) as f:
    spec_text = f.read()
spec_ids = set()
for line in spec_text.splitlines():
    if not line.startswith("| "):
        continue
    cells = re.split(r"(?<!\\)\|", line)
    if len(cells) >= 3:
        for token in re.findall(r"`([a-z0-9_]+)`", cells[2]):
            spec_ids.add(token)
for rid in ids:
    check("row id %r appears in spec/target-spec.md's Row id column" % rid, rid in spec_ids)

# ---- 5. no host-local path in a committed request ---------------------------------------
for b, req in requests.items():
    blob = json.dumps({k: v for k, v in req.items() if k != "_comment"})
    for bad in ("/home/", "/Users/", os.path.expanduser("~")):
        check("%s request has no %s path" % (b, bad), bad not in blob)
    for proc in req.get("corners", {}).get("process", []):
        for sec in proc.get("sections", []):
            lib = sec.get("lib", "") if isinstance(sec, dict) else ""
            check("%s corner lib %r is PDK-relative" % (b, lib),
                  bool(lib) and not lib.startswith("/") and not lib.startswith("$"))
    check("%s request declares models.pdk" % b, "pdk" in req.get("models", {}))
    check("%s request stages its model inputs" % b,
          req.get("options", {}).get("stage_model_inputs") is True)
    for entry in req.get("options", {}).get("osdi_preload", []):
        check("%s osdi_preload %r is runner-resolvable" % (b, entry),
              entry.startswith("$PDK_ROOT/"))
    check("%s request declares netlist_source schematic" % b,
          req.get("netlist_source") == "schematic", req.get("netlist_source"))

# ---- 6. deck templates ------------------------------------------------------------------
for b in BENCHES:
    m = meta.get(b)
    if not m:
        continue
    with open(os.path.join(root, "sim/%s/%s" % (b, m["deck_template"]))) as f:
        tmpl = f.read()
    body = [l for l in tmpl.splitlines() if l and not l.startswith("*")]
    check("%s deck template line 1 is a comment" % b, tmpl.splitlines()[0].startswith("*"))
    check("%s deck template has no .control block" % b,
          not any(l.lower().startswith(".control") for l in body))
    check("%s deck template has no .end card" % b,
          not any(l.strip().lower() == ".end" for l in body))
    placeholders = set(re.findall(r"@@([A-Z_]+)@@", tmpl))
    supplied = set(m["deck_substitutions"]) | {"WORK"}
    check("%s every deck placeholder is supplied" % b, placeholders <= supplied,
          "unsupplied: %s" % sorted(placeholders - supplied))

# ---- 7. cited envelopes exist, are graded as declared, and are paired with a record ------
# An envelope that FAILS is still valid evidence -- since decision record 0011 §2 the grids
# are graded at the ratified Target, and `psrr_dc` misses it. What must never pass silently
# is an UNDECLARED failure, so a bench that expects one declares it in bench.json
# (`expected_failure`) with the exact point count. Any drift in that count, a failure on a
# bench that declares none, or a declared failure that stops happening, fails this test.
for b, entry in cited.items():
    rel = entry["file"]
    path = os.path.join(root, rel)
    if not os.path.isfile(path):
        check("%s cited envelope exists (%s)" % (b, rel), False)
        continue
    env = load(rel)
    exp = (meta.get(b) or {}).get("expected_failure")
    want_status = "fail" if exp else "pass"
    check("%s cited envelope status is %s as declared" % (b, want_status),
          env.get("status") == want_status, str(env.get("status")))
    check("%s cited envelope graded at least one limit" % b,
          (env.get("coverage") or {}).get("measurements_with_limits", 0) > 0)
    # Coverage is "every expanded point returned a verdict", pass or fail -- not "every point
    # passed". An errored or inconclusive point is a hole in the grid and is never allowed.
    passed, failed = env.get("passed") or 0, env.get("failed") or 0
    check("%s cited envelope covers every expanded point" % b,
          passed + failed == env.get("corner_count") and not env.get("errored")
          and not env.get("inconclusive"),
          "%s pass + %s fail of %s (errored %s, inconclusive %s)"
          % (passed, failed, env.get("corner_count"), env.get("errored"),
             env.get("inconclusive")))
    if exp:
        check("%s declared failing rows equal bench.json's spec_rows" % b,
              exp.get("rows") == meta[b]["spec_rows"],
              "%s vs %s" % (exp.get("rows"), meta[b]["spec_rows"]))
        check("%s failing point count equals the declared %s" % (b, exp.get("failing_points")),
              failed == exp.get("failing_points"),
              "%s failing, declared %s" % (failed, exp.get("failing_points")))
        check("%s declared grid size equals the envelope's" % b,
              exp.get("of") == env.get("corner_count"),
              "%s vs %s" % (exp.get("of"), env.get("corner_count")))
    name = os.path.basename(rel)
    rec_rel = "sim/%s/records/%s" % (b, name)
    if not os.path.isfile(os.path.join(root, rec_rel)):
        check("%s cited envelope has a record of the same name" % b, False, rec_rel)
        continue
    rec = load(rec_rel)
    check("%s record carries schema_version 1" % b, rec.get("schema_version") == 1,
          str(rec.get("schema_version")))
    check("%s record names its own envelope" % b, rec.get("envelope") == rel, str(rec.get("envelope")))
    want_rec = "failed" if (meta.get(b) or {}).get("expected_failure") else "ok"
    check("%s record status is %s as declared" % (b, want_rec),
          rec.get("status") == want_rec, str(rec.get("status")))
    check("%s record binds the staged models by hash" % b,
          (rec.get("models_staged") or {}).get("hashes_match") is True,
          json.dumps((rec.get("models_staged") or {}).get("hashes_match")))
    check("%s record spec_rows equal bench.json's" % b,
          rec.get("spec_rows") == meta.get(b, {}).get("spec_rows"))

print("" if fails else "all grid-bench consistency checks passed")
if fails:
    print("%d failure(s)" % len(fails))
sys.exit(1 if fails else 0)
PY
