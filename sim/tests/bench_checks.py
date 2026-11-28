"""Shared offline bench checks (issue #192). Stdlib only; import with
sys.path.insert(0, <this dir>) because the suites run python3 -I.

sim/tests/test-grid-benches.sh and sim/tests/test-mc-bench.sh enforce the same
invariants on their committed `klt sim` benches. Each used to carry its own
inline copy, and the copies drifted: a check reached one suite and not the
other, and one copy guarded malformed input where the other raised. This module
is the one copy. Assertion names are the grid suite's, which the negative
controls in its header quote byte for byte; a suite that checks a single bench
passes no path and its assertions name only the thing checked.
"""
import json
import os
import re


class CheckRunner:
    """PASS/FAIL lines, failure tracking and repo-relative file reads for one suite."""

    def __init__(self, root):
        self.root = root
        self.fails = []

    def check(self, name, ok, detail=""):
        if ok:
            print("PASS " + name)
        else:
            print("FAIL %s%s" % (name, (": " + detail) if detail else ""))
            self.fails.append(name)

    def load(self, rel):
        with open(os.path.join(self.root, rel)) as f:
            return json.load(f)

    def text(self, rel):
        with open(os.path.join(self.root, rel)) as f:
            return f.read()

    def exists(self, rel):
        return os.path.isfile(os.path.join(self.root, rel))

    def finish(self, ok_message):
        """Print the suite's closing lines and return its exit code."""
        print("" if self.fails else ok_message)
        if self.fails:
            print("%d failure(s)" % len(self.fails))
        return 1 if self.fails else 0


def check_request_portability(checks, label, req):
    """No host-local path in a committed request, and it stages its model inputs.

    `klt sim` refuses a request naming a path that only exists on the submitting
    host when run on `batch` (`models_lib_host_path`), and the point of the request
    shape is that one request serves a local probe and the fleet grid. A malformed
    request fails these checks instead of raising.
    """
    blob = json.dumps({k: v for k, v in req.items() if k != "_comment"})
    for bad in ("/home/", "/Users/", os.path.expanduser("~")):
        checks.check("%s request has no %s path" % (label, bad), bad not in blob)
    for proc in req.get("corners", {}).get("process", []):
        for sec in proc.get("sections", []):
            lib = sec.get("lib", "") if isinstance(sec, dict) else ""
            checks.check("%s corner lib %r is PDK-relative" % (label, lib),
                         bool(lib) and not lib.startswith("/") and not lib.startswith("$"))
    checks.check("%s request declares models.pdk" % label, "pdk" in req.get("models", {}))
    checks.check("%s request stages its model inputs" % label,
                 req.get("options", {}).get("stage_model_inputs") is True)
    for entry in req.get("options", {}).get("osdi_preload", []):
        checks.check("%s osdi_preload %r is runner-resolvable" % (label, entry),
                     entry.startswith("$PDK_ROOT/"))
    checks.check("%s request declares netlist_source schematic" % label,
                 req.get("netlist_source") == "schematic", req.get("netlist_source"))


def read_runner_dut_contract(checks):
    """Read the staged DUT's cell name and pin order from sim/runner-lib.sh.

    cm5_stage_dut emits the staged `.subckt` header and every deck instantiates it, so
    the cell name and the pin order live in TWO places that must agree. They are read
    from runner-lib.sh rather than retyped: a drift between the staging header and an
    `Xdut` card would otherwise surface as an "unknown subckt" at load time on the
    fleet, one submitted run later, instead of failing offline. Returns
    `(dut_subckt, dut_pins, want_xdut)`, the last being the card a deck must carry.
    """
    runner_lib = checks.text("sim/runner-lib.sh")

    def shvar(name):
        m = re.search(r'^%s="([^"]*)"$' % name, runner_lib, re.M)
        return m.group(1) if m else None

    dut_subckt, dut_pins = shvar("CM5_DUT_SUBCKT"), shvar("CM5_DUT_PINS")
    checks.check("sim/runner-lib.sh declares CM5_DUT_SUBCKT and CM5_DUT_PINS",
                 bool(dut_subckt) and bool(dut_pins), "%r %r" % (dut_subckt, dut_pins))
    want_xdut = ["Xdut"] + (dut_pins or "").split() + [dut_subckt or ""]
    return dut_subckt, dut_pins, want_xdut


def check_deck_template(checks, path, tmpl, want_xdut):
    """Assert the deck-template contract on one template's text; return its card body.

    `path` is the template's repo-relative path, or None for a suite's only template;
    it names the assertions. The returned body is the template's card lines (non-blank,
    non-comment), for a caller that compares templates against each other.

    No SPICE title line and no `.control` block (issue #19: `klt sim` `.include`s the
    generated deck, so line 1 is not in title position and a `.control` block would
    never run) and no `.end` card. The substrate tie (issue #83, decision record 0014):
    a deck that drives `sub!` with `Vsub` only ties the DUT's rppd/rhigh bulks if
    `sub!` is an ngspice GLOBAL net, and no measured value looks wrong without one.
    The DUT wrapper (issue #80, decision record 0013): instantiated exactly once,
    after the `.include` that defines it, with runner-lib.sh's cell name and pin order.
    """
    def n(words):
        return "%s %s" % (path, words) if path else words

    body = [l for l in tmpl.splitlines() if l and not l.startswith("*")]
    checks.check(n("deck template line 1 is a comment"), tmpl.splitlines()[0].startswith("*"))
    checks.check(n("deck template has no .control block"),
                 not any(l.lower().startswith(".control") for l in body))
    checks.check(n("deck template has no .end card"),
                 not any(l.strip().lower() == ".end" for l in body))
    globals_ = [l.split() for l in body if l.split()[:1] == [".global"]]
    vsub_sub = [l for l in body
                if l.split()[:1] and l.split()[0].lower().startswith("vsub")
                and "sub!" in l.lower()]
    sub_global = [g for g in globals_ if "sub!" in g[1:]]
    checks.check(n("deck template drives sub! with a Vsub card"), len(vsub_sub) == 1,
                 "%d Vsub cards naming sub!" % len(vsub_sub))
    checks.check(n("deck template declares sub! global where it drives it"),
                 len(sub_global) == 1 if vsub_sub else not sub_global,
                 "%d .global cards naming sub! for %d Vsub sub! cards"
                 % (len(sub_global), len(vsub_sub)))
    checks.check(n("deck template's .global cards name only sub!"),
                 all(g[1:] == ["sub!"] for g in globals_), str(globals_))
    includes = [i for i, l in enumerate(body) if l.lower().startswith(".include")]
    xduts = [i for i, l in enumerate(body) if l.split()[:1] == ["Xdut"]]
    checks.check(n("deck template instantiates the staged DUT exactly once"), len(xduts) == 1,
                 "%d Xdut cards" % len(xduts))
    if len(xduts) == 1 and len(includes) == 1:
        checks.check(n("instantiates the DUT after the .include that defines it"),
                     xduts[0] > includes[0], "Xdut at %d, .include at %d" % (xduts[0], includes[0]))
    if xduts:
        card = body[xduts[0]].split()
        checks.check(n("Xdut card is runner-lib.sh's cell name and pin order"),
                     card == want_xdut, "%s vs %s" % (card, want_xdut))
    return body


def check_deck_path_agreement(checks, bench, meta):
    """A bench.json's `deck_template` and `testbench` resolve to the same file.

    The runner substitutes the first and `klt sim` is pointed at the second, so a
    bench repointed on one key alone could commit records citing a testbench that is
    not the file whose bytes its `template_sha256` hashes (issue #119). Normalised
    repo-relative paths are compared, never raw strings.
    """
    tpl_rel = os.path.normpath(os.path.join("sim", bench, meta.get("deck_template", "")))
    tb_rel = os.path.normpath(meta.get("testbench", ""))
    checks.check("%s deck_template and testbench resolve to the same file" % bench,
                 tpl_rel == tb_rel, "deck_template->%s vs testbench->%s" % (tpl_rel, tb_rel))


def _spec_row_ids(spec_text):
    """Every `code` token in the Row id column of spec/target-spec.md's tables."""
    spec_ids = set()
    for line in spec_text.splitlines():
        if not line.startswith("| "):
            continue
        cells = re.split(r"(?<!\\)\|", line)
        if len(cells) >= 3:
            spec_ids.update(re.findall(r"`([a-z0-9_]+)`", cells[2]))
    return spec_ids


def check_manifest_spec_rows(checks, manifest, item_key, require_citations_exist=False):
    """The manifest's `spec_rows.<item_key>` declaration is accounted for and spelled right.

    Every declared row is cited under `evidence.<item_key>` or a declared gap, no row is
    both, and every row id appears in spec/target-spec.md's Row id column: a typo'd row
    id would otherwise read as an uncovered row with no hint of where it came from.
    With `require_citations_exist`, every citation must also name a committed file.
    """
    rows = manifest.get("spec_rows", {}).get(item_key)
    checks.check("the manifest declares an item-%s row set" % item_key,
                 isinstance(rows, list) and bool(rows))
    if not isinstance(rows, list):
        return
    ids = [r["id"] for r in rows]
    checks.check("spec_rows.%s has no duplicate row id" % item_key, len(ids) == len(set(ids)))
    gaps = {r["id"] for r in rows if r.get("gap")}
    evidence = manifest.get("evidence", {}).get(item_key) or []
    covered = {row for e in evidence for row in e.get("rows", [])}
    checks.check("every declared row is cited or a declared gap", covered | gaps == set(ids),
                 "unaccounted: %s" % sorted(set(ids) - (covered | gaps)))
    checks.check("no row is both cited and a declared gap", not (covered & gaps),
                 str(sorted(covered & gaps)))
    if require_citations_exist:
        for e in evidence:
            checks.check("item-%s citation %s is committed" % (item_key, e.get("file")),
                         checks.exists(e.get("file", "")))
    spec_ids = _spec_row_ids(checks.text("spec/target-spec.md"))
    for rid in ids:
        checks.check("row id %r appears in spec/target-spec.md's Row id column" % rid,
                     rid in spec_ids)


def check_envelope_coverage(checks, label, env):
    """An envelope returns a verdict for every expanded point, none errored or inconclusive.

    Coverage is "every expanded point returned a verdict", pass or fail -- not "every
    point passed". An errored or inconclusive point is a hole in the grid and is never
    allowed. `label` names the envelope in the assertion.
    """
    passed, failed = env.get("passed") or 0, env.get("failed") or 0
    checks.check(label, passed + failed == env.get("corner_count") and not env.get("errored")
                 and not env.get("inconclusive"),
                 "%s pass + %s fail of %s (errored %s, inconclusive %s)"
                 % (passed, failed, env.get("corner_count"), env.get("errored"),
                    env.get("inconclusive")))
