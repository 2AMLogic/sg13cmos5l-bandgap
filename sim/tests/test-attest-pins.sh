#!/usr/bin/env bash
# Cross-check test for the attestation inventories (T1 items 9 and 10). Two independent
# assertions, both offline, needing only bash and python3:
#
#   1. attest/item9.json repeats the PDK pin and the OSDI build commit; this fails if they
#      drift from sim/pdk.json and reuse.lock.json, or if an inventoried testbench is gone.
#   2. attest/item10.json is a hand-written enumeration of the offline suites under
#      sim/tests/, while package.json's `test` script globs them. The two lists drifted at
#      the first opportunity: test-smoke-request.sh was added four hours after the inventory
#      was last edited and never reached it, so CI never ran the one suite guarding a
#      provenance mislabel that had actually shipped (issue #90). This fails if any
#      sim/tests/test-*.sh suite is absent from every attest/item10.json checks[].argv, so
#      adding a suite without attesting it is a CI failure instead of a silent gap.
#
# test-attest-pins.sh itself is the one documented exception to assertion 2: it is not
# inventoried under item 10 because .github/workflows/signoff.yml invokes it directly, as its
# own step. That exemption is not taken on trust -- it is granted only while signoff.yml
# really does name the file, so retiring the step without inventorying the suite fails too.
#
# Run: bash sim/tests/test-attest-pins.sh
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python3 -I - "${root}" <<'PY'
import glob, json, os, sys

root = sys.argv[1]
load = lambda p: json.load(open(os.path.join(root, p)))

# ---- 1. item-9 inventory pins -----------------------------------------------------------
pin_fails = []
inv, pdk, lock = load("attest/item9.json"), load("sim/pdk.json"), load("reuse.lock.json")
want = {"name": pdk["pdk"], "revision": pdk["revision"]}
if inv["pins"]["pdk"] != want:
    pin_fails.append("pins.pdk %r != sim/pdk.json %r" % (inv["pins"]["pdk"], want))
osdi = [s["commit"] for s in lock["sources"] if s.get("block") == "osdi_build"]
if len(osdi) != 1:
    pin_fails.append("reuse.lock.json has %d osdi_build sources, expected 1" % len(osdi))
elif not inv["pins"]["tools"].get("osdi_build", "").endswith("@" + osdi[0]):
    pin_fails.append("pins.tools.osdi_build does not end in @%s" % osdi[0])
for f in inv["testbenches"]:
    if not os.path.isfile(os.path.join(root, f)):
        pin_fails.append("testbench missing: " + f)

# ---- 2. every offline suite is inventoried under item 10 --------------------------------
# Exempt because .github/workflows/signoff.yml runs it as its own step (asserted below).
EXEMPT = "test-attest-pins.sh"
cov_fails = []
checks = load("attest/item10.json").get("checks") or []
if not checks:
    cov_fails.append("attest/item10.json has no checks[] -- inventory shape changed")
attested = set()
for chk in checks:
    for arg in chk.get("argv", []):
        attested.add(os.path.normpath(arg))

suites = sorted(os.path.basename(p)
                for p in glob.glob(os.path.join(root, "sim", "tests", "test-*.sh")))
if not suites:
    cov_fails.append("no sim/tests/test-*.sh suites found -- glob or layout changed")

wf = os.path.join(root, ".github", "workflows", "signoff.yml")
wf_src = open(wf).read() if os.path.isfile(wf) else ""

for name in suites:
    rel = "sim/tests/" + name
    if rel in attested:
        continue
    if name == EXEMPT:
        if rel not in wf_src:
            cov_fails.append(
                "%s is exempt from attest/item10.json only because signoff.yml runs it "
                "directly, but signoff.yml no longer names it -- inventory the suite or "
                "restore the step" % rel)
        continue
    cov_fails.append(
        "%s runs under package.json's test glob but appears in no attest/item10.json "
        "checks[].argv, so CI never runs it (issue #90)" % rel)

# ---- report ------------------------------------------------------------------------------
for f in pin_fails:
    print("FAIL", f)
if not pin_fails:
    print("PASS attest/item9.json pins match sim/pdk.json and reuse.lock.json")
for f in cov_fails:
    print("FAIL", f)
if not cov_fails:
    print("PASS all %d sim/tests/test-*.sh suites are attested under attest/item10.json "
          "(%s exempted: signoff.yml runs it directly)" % (len(suites), EXEMPT))

sys.exit(1 if (pin_fails or cov_fails) else 0)
PY
