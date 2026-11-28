#!/usr/bin/env bash
# Offline negative controls for a malformed committed `klt sim` request (issue #194). Needs
# only bash and python3: no PDK, no ngspice, no klt, no network.
# Run: bash sim/tests/test-malformed-request.sh
#
# What it guards, and why it can break silently:
#
# sim/tests/test-grid-benches.sh and sim/tests/test-mc-bench.sh are the offline gate on the
# committed benches, and each is one python3 heredoc: an uncaught exception anywhere in it
# ends the suite with a traceback, which both loses the FAIL line that names what is wrong
# and skips every assertion after it. A traceback is exit 1, so nothing downstream notices
# the difference -- only a reader does, and the reader sees a line number in a heredoc
# instead of the check that failed. Issue #192 consolidated the shared checks into
# sim/tests/bench_checks.py; issue #194 is the two sites that still raised on a malformed
# request: check_request_portability handing a non-string `netlist_source` to
# CheckRunner.check, which concatenates it, and the MC suite's sections()/axes()
# bare-indexing `corners` before any guarded check was reached.
#
# Method: copy sim/, manifests/ and spec/ to a temp tree (each suite locates its root from
# its own path), inject ONE malformed request, run the suite there, and assert four things
# -- exit 1, a FAIL line naming the malformed thing, the suite's own closing "%d failure(s)"
# line (printed only after its last assertion ran), and no "Traceback" anywhere in the
# output. The unmodified copy runs first as the control: a copy that failed for an unrelated
# reason would satisfy "exit 1 with a FAIL line" while proving nothing, so both suites must
# pass on the copy before any probe counts. Nothing here is committed to the bench trees:
# every mutation is written to the temp copy and discarded with it.
# set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python3 -I - "${root}" "${root}/sim/tests" <<'PY'
import json, os, shutil, subprocess, sys, tempfile

root, libdir = sys.argv[1], sys.argv[2]
sys.path.insert(0, libdir)
from bench_checks import CheckRunner

checks = CheckRunner(root)
check = checks.check

GRID, MC = "sim/tests/test-grid-benches.sh", "sim/tests/test-mc-bench.sh"
SUITES = {GRID: "grid-bench", MC: "mc-bench"}
GRID_REQ = "sim/closed-loop-vref-pvt/request-45pt.json"
MC_REQ = "sim/closed-loop-vref-mc/request-mc-%s.json"
DEL = object()

# (suite, request, what the probe breaks, where in the request, replacement (DEL = remove),
#  a word the FAIL line must carry). One entry per site issue #194 names: the non-string
# `netlist_source` in both suites, each of the five keys the MC suite's sections()/axes()
# read, missing and wrong-typed, and the two bare indexes the survey found below them.
CASES = [
    (GRID, GRID_REQ, "netlist_source is a list", ("netlist_source",), ["netlist"],
     "netlist_source"),
    (MC, MC_REQ % "line", "netlist_source is a list", ("netlist_source",), ["netlist"],
     "netlist_source"),
    (MC, MC_REQ % "zero", "process[0].sections is an object",
     ("corners", "process", 0, "sections"), {"section": "mos_tt"}, "sections"),
    (MC, MC_REQ % "zero", "corners is absent", ("corners",), DEL, "corners"),
    (MC, MC_REQ % "line", "supply_v has no Vvdd", ("corners", "supply_v", "Vvdd"), DEL,
     "Vvdd"),
    (MC, MC_REQ % "zero", "corners is a list", ("corners",), [1], "corners"),
    (MC, MC_REQ % "zero", "process is a string", ("corners", "process"), "mos_tt", "process"),
    (MC, MC_REQ % "line", "process[0].sections is a string",
     ("corners", "process", 0, "sections"), "cornerPNP.lib:stat", "sections"),
    (MC, MC_REQ % "line", "temperature_c is a number", ("corners", "temperature_c"), 27,
     "temperature_c"),
    (MC, MC_REQ % "inflated", "measurements is absent", ("measurements",), DEL, "measurements"),
    (MC, MC_REQ % "line", "monte_carlo is absent", ("monte_carlo",), DEL, "N >= 300"),
]


def run(tree, suite):
    """(exit code, whole output) of one suite run against the temp tree."""
    p = subprocess.run(["bash", os.path.join(tree, suite)], capture_output=True, text=True)
    out = p.stdout + p.stderr
    return p.returncode, out, (out.rstrip().splitlines() or [""])[-1]


def mutate(req, path, value):
    node = req
    for key in path[:-1]:
        node = node[key]
    if value is DEL:
        del node[path[-1]]
    else:
        node[path[-1]] = value


tree = tempfile.mkdtemp(prefix="malformed-request-")
try:
    for d in ("sim", "manifests", "spec"):
        shutil.copytree(os.path.join(root, d), os.path.join(tree, d), symlinks=True,
                        ignore=shutil.ignore_patterns("__pycache__"))

    # ---- 1. control: the copy is a faithful tree --------------------------------------------
    for suite, name in ((GRID, "grid-bench"), (MC, "mc-bench")):
        code, out, last = run(tree, suite)
        check("%s passes on the unmodified copy" % name,
              code == 0 and "FAIL " not in out and "Traceback" not in out,
              "exit %d, last line %r" % (code, last))

    # ---- 2. one malformed request per probe ---------------------------------------------------
    # Each probe restores the file's original bytes afterwards: the tree is shared, so a
    # mutation left behind would crash every later MC probe on someone else's bad input.
    for suite, req_rel, what, path, value, needle in CASES:
        with open(os.path.join(root, req_rel)) as f:
            original = f.read()
        req = json.loads(original)
        mutate(req, path, value)
        target = os.path.join(tree, req_rel)
        with open(target, "w") as f:
            json.dump(req, f, indent=2)
        try:
            code, out, last = run(tree, suite)
        finally:
            with open(target, "w") as f:
                f.write(original)
        fails = [l for l in out.splitlines() if l.startswith("FAIL ")]
        check("%s: %s is a FAIL line, not a traceback, and the suite runs to its end"
              % (SUITES[suite], what),
              code == 1 and any(needle in l for l in fails) and "Traceback" not in out
              and last.endswith(" failure(s)"),
              "exit %d, %d FAIL line(s)%s, last line %r"
              % (code, len(fails), " and a Traceback" if "Traceback" in out else "", last))
finally:
    shutil.rmtree(tree, ignore_errors=True)

sys.exit(checks.finish("all malformed-request probes reported FAIL and ran to the end"))
PY
