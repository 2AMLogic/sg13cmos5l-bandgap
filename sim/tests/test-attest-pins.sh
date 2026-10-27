#!/usr/bin/env bash
# Pin-consistency test for attest/item9.json (T1 item 9). The inventory repeats the PDK pin and the
# OSDI build commit; this fails if they drift from sim/pdk.json and reuse.lock.json. Needs only bash
# and python3. Run: bash sim/tests/test-attest-pins.sh
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python3 -I - "${root}" <<'PY'
import json, sys, os
root = sys.argv[1]
load = lambda p: json.load(open(os.path.join(root, p)))
inv, pdk, lock = load("attest/item9.json"), load("sim/pdk.json"), load("reuse.lock.json")
fails = []
want = {"name": pdk["pdk"], "revision": pdk["revision"]}
if inv["pins"]["pdk"] != want:
    fails.append("pins.pdk %r != sim/pdk.json %r" % (inv["pins"]["pdk"], want))
osdi = [s["commit"] for s in lock["sources"] if s.get("block") == "osdi_build"]
if len(osdi) != 1:
    fails.append("reuse.lock.json has %d osdi_build sources, expected 1" % len(osdi))
elif not inv["pins"]["tools"].get("osdi_build", "").endswith("@" + osdi[0]):
    fails.append("pins.tools.osdi_build does not end in @%s" % osdi[0])
for f in inv["testbenches"]:
    if not os.path.isfile(os.path.join(root, f)):
        fails.append("testbench missing: " + f)
for f in fails:
    print("FAIL", f)
if not fails:
    print("PASS attest/item9.json pins match sim/pdk.json and reuse.lock.json")
sys.exit(1 if fails else 0)
PY
