#!/usr/bin/env bash
# Offline provenance test for the smoke bench's `klt sim` request (issue #87). Needs only
# bash and python3: no PDK, no ngspice, no klt. Run: bash sim/tests/test-smoke-request.sh
#
# What it guards, and why it can break silently:
#
# The smoke request is an inline heredoc inside sim/smoke/run_smoke.sh, not a committed
# request file, so sim/tests/test-grid-benches.sh check 5 -- which reads the five committed
# request-*.json and enforces `netlist_source: "schematic"` on each -- never saw it. That is
# how the request kept `netlist_source: "extracted"` after decision record 0011 Section 8 ruled
# that value a provenance mislabel and corrected every request it could see: the one request
# the ruling missed was the one no test reads. `klt sim` takes the field as the caller's word
# and echoes it into `environment.netlist_source`, so a wrong value is copied into every
# record the bench appends, and run_smoke.sh is the T1 item-9 `cold_start` command.
#
# sim/smoke/smoke.cir is a hand-written bring-up deck ("NOT part of the design", its own
# header): it is neither extracted from layout nor an xschem export, so the honest request
# makes no provenance claim at all and omits the optional field. `schematic` is accepted here
# too -- it is the symmetry-with-the-grid-benches alternative the issue names -- but
# `extracted` is a false claim and fails.
#
# Negative control (run while writing it): restoring the `"netlist_source": "extracted",` line
# to run_smoke.sh fails check 2 with `got 'extracted'`.
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

python3 -I - "${root}" <<'PY'
import json, re, sys

root = sys.argv[1]
runner = root + "/sim/smoke/run_smoke.sh"
fails = []


def check(name, ok, detail=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else ": " + str(detail)))
    if not ok:
        fails.append(name)


with open(runner) as f:
    src = f.read()

# ---- 1. the request heredoc is present and is valid JSON -------------------------------
# Read the request the runner actually emits rather than a copy of it: the shell expansions
# are stubbed, so this parses the real heredoc body and fails if it stops being valid JSON.
m = re.search(r'cat > "\$\{WORK\}/request\.json" <<EOF\n(.*?)\nEOF\n', src, re.S)
check("run_smoke.sh writes request.json from a heredoc", bool(m))

if m:
    body = re.sub(r'\$\{[A-Za-z_][A-Za-z0-9_]*\}', "STUB", m.group(1))
    try:
        req = json.loads(body)
    except ValueError as exc:
        req = None
        check("the smoke request heredoc is valid JSON once expansions are stubbed",
              False, exc)
    if req is not None:
        check("the smoke request heredoc is valid JSON once expansions are stubbed", True)

        # ---- 2. no false post-layout provenance claim ----------------------------------
        src_val = req.get("netlist_source")
        check("the smoke request makes no `extracted` provenance claim "
              "(sim/smoke/smoke.cir is hand-written; decision record 0011 Section 8)",
              src_val in (None, "schematic"), "got %r" % (src_val,))

print("" if fails else "all smoke-request checks passed")
if fails:
    print("%d failure(s)" % len(fails))
sys.exit(1 if fails else 0)
PY
