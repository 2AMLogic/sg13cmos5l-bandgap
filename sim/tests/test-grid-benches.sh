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
#  8. The five benches' `corners.process` tables are identical to each other, and the
#     (corner file, section) pairs they select are exactly `REQUIRED` in
#     sim/tools/check-model-sections.py minus the one non-corner entry
#     (`cornerPNP.lib` `stat`). That checker exists to prove at pin time that the
#     sections the benches select resolve in the PDK, but it proves it for its own
#     hand-written list: edit a request's `section` -- or a `REQUIRED` entry -- alone and
#     every offline test stayed green while "12/12 required sections found" described
#     sections no bench uses. `REQUIRED` is imported from the checker here, never retyped.
#
# Negative controls (each run while writing it, decision record 0011): retagging one manifest
# citation's `rows` to `psrr_dc_typo` fails check 2 ("closed-loop-psrr manifest rows equal
# bench.json's spec_rows") AND check 3 ("every declared row is cited or a declared gap:
# unaccounted: ['psrr_dc']"); changing closed-loop-psrr's declared `failing_points` from 24 to
# 23 fails check 7 ("failing point count equals the declared 23: 24 failing"); deleting its
# `expected_failure` block altogether fails check 7 twice ("cited envelope status is pass as
# declared: fail", "record status is ok as declared: failed"). All exit 1.
#
# Negative controls for check 8 (issue #61), each run while writing it and reverted before
# commit: (a) changing closed-loop-psrr's `wcs` MOS `section` from `mos_ss` to `mos_zz` fails
# twice -- "closed-loop-psrr corners.process equals closed-loop-vref-pvt's: corner 2: ('wcs',
# [... ('cornerMOShv.lib', 'mos_zz') ...]) vs ('wcs', [... ('cornerMOShv.lib', 'mos_ss')
# ...])" and "closed-loop-psrr selects exactly REQUIRED minus cornerPNP.lib:stat: missing
# [('cornerMOShv.lib', 'mos_ss')]; unexpected [('cornerMOShv.lib', 'mos_zz')]". (b) deleting
# the ("cornerRES.lib", "res_wcs") entry from the checker's `REQUIRED` fails once per bench --
# "<bench> selects exactly REQUIRED minus cornerPNP.lib:stat: missing []; unexpected
# [('cornerRES.lib', 'res_wcs')]". Both exit 1. Edge case, same method: replacing one
# closed-loop-iq `sections` entry with the string "cornerRES.lib:res_wcs" is reported as
# "closed-loop-iq corner 'wcs' sections entry is an object: 'cornerRES.lib:res_wcs'" (exit 1),
# not a Python traceback. Inventoried as a T1 item-10 hygiene check (attest/item10.json), so CI
# re-runs it through `klt signoff --attest 10 --check`.
#
# Negative controls for the substrate-tie half of check 6 (issue #83), each run while writing
# it and reverted before commit: (a) deleting the `.global sub!` card from
# closed-loop-startup's template fails once -- "closed-loop-startup deck template declares
# sub! global where it drives it: 0 .global cards naming sub! for 1 Vsub sub! cards", which
# is the exact pre-#83 state of all five decks and the thing no simulated value reveals.
# (b) widening closed-loop-iq's card to `.global sub! vdd` fails once -- "closed-loop-iq deck
# template's .global cards name only sub!: [['.global', 'sub!', 'vdd']]" -- so the card
# cannot quietly globalise a second net. (c) deleting closed-loop-psrr's `Vsub sub! vss dc 0`
# card fails TWICE -- "closed-loop-psrr deck template drives sub! with a Vsub card: 0 Vsub
# cards naming sub!" and "...declares sub! global where it drives it: 1 .global cards naming
# sub! for 0 Vsub sub! cards" -- so dropping the tie is caught as well as dropping the card,
# and a card left with nothing to make true is reported too. All exit 1.
#
# Negative controls for the DUT-wrapper half of check 6 (issue #80), each run while writing it
# and reverted before commit: (a) flipping sim/runner-lib.sh's CM5_DUT_PINS to the schematic
# export's own "vdd vss vref" order fails SIX times -- once per bench ("<bench> Xdut card is
# runner-lib.sh's cell name and pin order: ['Xdut', 'vdd', 'vref', 'vss', ...] vs ['Xdut',
# 'vdd', 'vss', 'vref', ...]") and once on the extraction tie ("...extracted/20261113T123950Z-
# 8422e4d.spice header equals the staged wrapper's cell name and pin order"), which is exactly
# the `pin_order_mismatch` klt would report one submitted grid later. (b) deleting the `Xdut`
# card from closed-loop-iq's template fails once ("closed-loop-iq deck template instantiates
# the staged DUT exactly once: 0 Xdut cards"). Both exit 1.
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python3 -I - "${root}" <<'PY'
import glob, importlib.util, json, os, re, sys

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
# The DUT wrapper (issue #80, decision record 0013): cm5_stage_dut emits the staged
# `.subckt` header and each deck instantiates it, so the cell name and the pin order live in
# TWO places that must agree. They are read from sim/runner-lib.sh here rather than retyped,
# the same discipline check 8 applies to the checker's REQUIRED: a drift between the staging
# header and an `Xdut` card would otherwise surface as an "unknown subckt" at load time on
# the fleet, one submitted grid later, instead of failing offline here.
with open(os.path.join(root, "sim/runner-lib.sh")) as f:
    runner_lib = f.read()


def shvar(name):
    m = re.search(r'^%s="([^"]*)"$' % name, runner_lib, re.M)
    return m.group(1) if m else None


dut_subckt, dut_pins = shvar("CM5_DUT_SUBCKT"), shvar("CM5_DUT_PINS")
check("sim/runner-lib.sh declares CM5_DUT_SUBCKT and CM5_DUT_PINS",
      bool(dut_subckt) and bool(dut_pins), "%r %r" % (dut_subckt, dut_pins))
want_xdut = ["Xdut"] + (dut_pins or "").split() + [dut_subckt or ""]

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
    # The substrate tie (issue #83, decision record 0014): a deck that drives `sub!` with
    # `Vsub` only ties the DUT's rppd/rhigh bulks if `sub!` is an ngspice GLOBAL net. `!` is
    # an xschem marker and the migrated netlist carries no `.global` card, so without one
    # here the bulk terminals stay per-instance local nodes (`xdut.xx1.sub!`) resolved by
    # `.options rshunt` alone -- the deck's own comment would describe a tie it does not
    # make, and no measured value would look wrong. Checked per deck, not centrally,
    # because each template carries its own fixture cards.
    globals_ = [l.split() for l in body if l.split()[:1] == [".global"]]
    vsub_sub = [l for l in body
                if l.split()[:1] and l.split()[0].lower().startswith("vsub")
                and "sub!" in l.lower()]
    sub_global = [g for g in globals_ if "sub!" in g[1:]]
    check("%s deck template drives sub! with a Vsub card" % b, len(vsub_sub) == 1,
          "%d Vsub cards naming sub!" % len(vsub_sub))
    check("%s deck template declares sub! global where it drives it" % b,
          len(sub_global) == 1 if vsub_sub else not sub_global,
          "%d .global cards naming sub! for %d Vsub sub! cards"
          % (len(sub_global), len(vsub_sub)))
    check("%s deck template's .global cards name only sub!" % b,
          all(g[1:] == ["sub!"] for g in globals_), str(globals_))
    placeholders = set(re.findall(r"@@([A-Z_]+)@@", tmpl))
    supplied = set(m["deck_substitutions"]) | {"WORK"}
    check("%s every deck placeholder is supplied" % b, placeholders <= supplied,
          "unsupplied: %s" % sorted(placeholders - supplied))
    includes = [i for i, l in enumerate(body) if l.lower().startswith(".include")]
    xduts = [i for i, l in enumerate(body) if l.split()[:1] == ["Xdut"]]
    check("%s deck template instantiates the staged DUT exactly once" % b, len(xduts) == 1,
          "%d Xdut cards" % len(xduts))
    if len(xduts) == 1 and len(includes) == 1:
        check("%s instantiates the DUT after the .include that defines it" % b,
              xduts[0] > includes[0], "Xdut at %d, .include at %d" % (xduts[0], includes[0]))
    if xduts:
        card = body[xduts[0]].split()
        check("%s Xdut card is runner-lib.sh's cell name and pin order" % b,
              card == want_xdut, "%s vs %s" % (card, want_xdut))

# The wrapper's pin ORDER is only correct relative to the extracted netlist: `klt pex` reuses
# the bench's positional Xdut line on both legs and fires pin_order_mismatch when the two
# headers hold the same pins in a different order (and flat_dut_mismatch with no wrapper at
# all). Every committed extracted netlist is checked, so a re-extraction that reorders the
# pins fails here offline rather than at the item-7 delta run (#32).
extracted = sorted(glob.glob(os.path.join(root, "sim/pex-bandgap-top/extracted/*.spice")))
check("a committed extracted netlist exists to check the wrapper against", bool(extracted))
for path in extracted:
    rel = os.path.relpath(path, root)
    with open(path) as f:
        heads = [l.split() for l in f if l.upper().startswith(".SUBCKT ")]
    check("%s declares exactly one top .SUBCKT" % rel, len(heads) == 1, str(len(heads)))
    if len(heads) == 1:
        want_head = [dut_subckt] + (dut_pins or "").split()
        check("%s header equals the staged wrapper's cell name and pin order" % rel,
              heads[0][1:] == want_head, "%s vs %s" % (heads[0][1:], want_head))

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

# ---- 8. the five corner tables agree, and agree with the checker's REQUIRED --------------
# sim/tools/check-model-sections.py is what proves (at the pin, against the real PDK) that
# every section these benches select is defined. It checks its own hand-written REQUIRED
# list, so nothing tied that list to the sections the committed requests actually select:
# a request edited to a new section name, or a REQUIRED entry edited alone, left every
# offline test green and the checker's "12/12 required sections found" then described
# sections no bench uses. The pairs are compared by basename because a request names the
# lib PDK-relative (checked in 5 above) while REQUIRED names the file only.
STAT_EXEMPT = ("cornerPNP.lib", "stat")   # mismatch section; no PVT grid corner selects it


def corner_pairs(bench, req):
    """{(basename(lib), section)} a request selects. Malformed entries fail, never raise."""
    pairs = set()
    for proc in (req.get("corners") or {}).get("process") or []:
        if not isinstance(proc, dict):
            check("%s corners.process entry is an object" % bench, False, repr(proc))
            continue
        for sec in proc.get("sections") or []:
            if not isinstance(sec, dict):
                check("%s corner %r sections entry is an object" % (bench, proc.get("name")),
                      False, repr(sec))
                continue
            lib, section = sec.get("lib"), sec.get("section")
            if not isinstance(lib, str) or not isinstance(section, str):
                check("%s corner %r section entry names a lib and a section"
                      % (bench, proc.get("name")), False, json.dumps(sec))
                continue
            pairs.add((os.path.basename(lib), section))
    return pairs


def corner_summary(proc):
    """Compact [(name, [(lib basename, section), ...]), ...], for difference reporting."""
    out = []
    for c in proc if isinstance(proc, list) else []:
        if not isinstance(c, dict):
            out.append((None, repr(c)))
            continue
        out.append((c.get("name"), [(os.path.basename(s.get("lib", "")), s.get("section"))
                                    for s in c.get("sections") or [] if isinstance(s, dict)]))
    return out


def first_difference(got, ref_):
    """Name the first corner at which two corners.process lists differ."""
    a, b = corner_summary(got), corner_summary(ref_)
    for i in range(max(len(a), len(b))):
        x = a[i] if i < len(a) else None
        y = b[i] if i < len(b) else None
        if x != y:
            return "corner %d: %s vs %s" % (i, x, y)
    return "lists differ outside the (name, sections) summary"


ref = BENCHES[0]
ref_proc = (requests.get(ref) or {}).get("corners", {}).get("process")
check("%s declares a non-empty corners.process" % ref,
      isinstance(ref_proc, list) and bool(ref_proc), json.dumps(ref_proc))
for b in BENCHES[1:]:
    if b not in requests or ref not in requests:
        continue
    this_proc = requests[b].get("corners", {}).get("process")
    check("%s corners.process equals %s's" % (b, ref), this_proc == ref_proc,
          first_difference(this_proc, ref_proc))

# REQUIRED is imported from the checker by path -- the file name has a hyphen so it cannot be
# named by a plain import, and it is `__main__`-guarded so executing the module runs nothing.
required = None
checker_rel = "sim/tools/check-model-sections.py"
try:
    _spec = importlib.util.spec_from_file_location("cm5_check_model_sections",
                                                   os.path.join(root, checker_rel))
    _mod = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(_mod)
    required = {tuple(pair) for pair in _mod.REQUIRED}
except Exception as exc:                                        # noqa: BLE001
    check("%s is importable and exports REQUIRED" % checker_rel, False, str(exc))

if required is not None:
    check("%s REQUIRED keeps the %s:%s exemption" % ((checker_rel,) + STAT_EXEMPT),
          STAT_EXEMPT in required, sorted(required))
    want = required - {STAT_EXEMPT}
    for b in BENCHES:
        if b not in requests:
            continue
        got = corner_pairs(b, requests[b])
        check("%s selects exactly REQUIRED minus %s:%s" % ((b,) + STAT_EXEMPT), got == want,
              "missing %s; unexpected %s" % (sorted(want - got), sorted(got - want)))

print("" if fails else "all grid-bench consistency checks passed")
if fails:
    print("%d failure(s)" % len(fails))
sys.exit(1 if fails else 0)
PY
