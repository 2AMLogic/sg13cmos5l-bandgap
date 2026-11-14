#!/usr/bin/env python3
"""Measure whether a SG13CMOS5L statistical/mismatch model section varies a device
PER INSTANCE or GLOBALLY (issue #31, T1 item 6).

Why this exists. A Monte Carlo campaign's claim depends entirely on which of the two a
section does, and the question is not answerable by reading the libraries: the PDK's own
comments call `nsig_*` a "global number of standard deviations", but `nsig_*` sits on a
`.model` card, and whether ngspice re-evaluates a model-card `agauss` per instantiation
is an engine behaviour, not a library statement. `klt sim`'s
`environment.monte_carlo.family_mismatch` report would answer it, but its curated table
covers sky130 and gf180mcu only, so every family of an `ihp-sg13cmos5l` request comes
back `active: null` -- "not independently verified". This script verifies it.

Method, one probe per case: instantiate the SAME device TWICE, identically sized, in one
deck under one model section, force a fixed current through each, and compare the two
terminal voltages.

    identical  -> the section's draw is shared by every instance (GLOBAL / lot-level)
    different  -> the section's draw is re-evaluated per instance (LOCAL / mismatch-like)

Each probe is one `.op` solve of a two-device deck. That is a single-unit debug run, so
it runs locally by design (CLAUDE.md: a single operating point may run locally); nothing
here is a grid and nothing here goes to the fleet.

Usage (from the repo root):

    source sim/env.sh && python3 -I sim/tools/stat_locality.py [-o <record.json>]

Exit 0 when every probe resolved to one of the two verdicts and every section that
declares statistics was reached, 1 when a probe could not be solved or a section is
missing, 2 when the environment is not set up (run `source sim/env.sh` first).
"""
import argparse
import datetime
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

# Each probe: a label, the corner libraries/sections to select, and the two-device
# fixture. `expect` is what the bench's reading of the PDK says should happen; the probe
# reports what it MEASURED and whether the two agree, so a PDK revision that changes the
# mechanism shows up as a disagreement rather than being silently absorbed.
PROBES = [
    {
        "name": "pnpMPA/typ",
        "device": "pnpMPA",
        "sections": [("cornerPNP.lib", "typ")],
        "expect": "identical",
        "why": "the deterministic typ section draws nothing at all",
    },
    {
        "name": "pnpMPA/stat",
        "device": "pnpMPA",
        "sections": [("cornerPNP.lib", "stat")],
        "expect": "identical",
        "why": ("cornerPNP.lib `stat` varies top-level `.param`s (sgp_mpa_is, _bf, ...) "
                "through gauss(); a `.param` is evaluated once for the whole deck, so "
                "every pnpMPA instance shares one draw. pnpMPA has no per-instance "
                "mismatch hook anywhere in the PDK"),
    },
    {
        "name": "sg13_hv_nmos/mos_tt",
        "device": "nmos",
        "sections": [("cornerMOShv.lib", "mos_tt")],
        "expect": "identical",
        "why": "the deterministic typ section draws nothing at all",
    },
    {
        "name": "sg13_hv_nmos/mos_tt_stat",
        "device": "nmos",
        "sections": [("cornerMOShv.lib", "mos_tt_stat")],
        "expect": "identical",
        "why": ("cornerMOShv.lib `mos_tt_stat` includes sg13g2_moshv_stat.lib, which "
                "varies top-level `.param`s, plus the NON-mismatch device library "
                "sg13g2_moshv_mod.lib"),
    },
    {
        "name": "sg13_hv_nmos/mos_tt_mismatch",
        "device": "nmos",
        "sections": [("cornerMOShv.lib", "mos_tt_mismatch")],
        "expect": "identical",
        "why": ("the per-instance agauss calls in sg13g2_moshv_mod_mismatch.lib are "
                "gated on the subcircuit parameter `mm_ok`, whose default is 0 and "
                "which this probe (like the migrated DUT netlist) does not set"),
    },
    {
        "name": "sg13_hv_nmos/mos_tt_mismatch+mm_ok",
        "device": "nmos",
        "sections": [("cornerMOShv.lib", "mos_tt_mismatch")],
        "params": "mm_ok=1",
        "expect": "different",
        "why": ("the same section with the gate opened by hand, which is what shows the "
                "mechanism is present and merely unreachable from a `klt sim` request"),
    },
    {
        "name": "rppd/res_typ",
        "device": "rppd",
        "sections": [("cornerRES.lib", "res_typ")],
        "expect": "identical",
        "why": "res_typ zeroes drsh_*/dl_*/dw_*, so the model card's nsig_* scale nothing",
    },
    {
        "name": "rppd/res_stat",
        "device": "rppd",
        "sections": [("cornerRES.lib", "res_stat")],
        "expect": "different",
        "why": ("resistors_stat.lib gives drsh_*/dl_*/dw_* non-zero magnitudes and the "
                "r3_cmc `.model` card carries nsig_*='agauss(0,1,1)'. Despite the "
                "library comment calling nsig_* global, ngspice re-evaluates the model "
                "card expression per instantiation, so res_stat is LOCAL variation"),
    },
]

FIXTURES = {
    # A pnpMPA diode-connected into a 1 uA source: v(a) is the base-emitter voltage.
    "pnpMPA": """I1 0 a dc 1u
I2 0 b dc 1u
XQA 0 0 a pnpMPA a={{1u*2u}} p={{(1u+2u)*2}} m=1 {params}
XQB 0 0 b pnpMPA a={{1u*2u}} p={{(1u+2u)*2}} m=1 {params}
""",
    # Two identical nmos at a fixed bias: i(VdA)/i(VdB) is the drain current.
    "nmos": """Vg g 0 dc 1.0
VdA da 0 dc 1.0
VdB db 0 dc 1.0
XMA da g 0 0 sg13_hv_nmos w=10u l=1u ng=1 m=1 {params}
XMB db g 0 0 sg13_hv_nmos w=10u l=1u ng=1 m=1 {params}
""",
    # Two identical rppd carrying 1 uA each: v(a)/v(b) is I*R.
    "rppd": """Vs sub! 0 dc 0
I1 0 a dc 1u
I2 0 b dc 1u
XRA a 0 sub! rppd w=2u l=85.1u m=1 b=0 {params}
XRB b 0 sub! rppd w=2u l=85.1u m=1 b=0 {params}
""",
}
READOUT = {"pnpMPA": ("v(a)", "v(b)"), "nmos": ("i(vda)", "i(vdb)"), "rppd": ("v(a)", "v(b)")}
# Relative difference below this counts as "identical": two instances of one shared draw
# are solved by the same code path and agree to the solver's own tolerance, so anything
# above it is a different draw, not round-off.
IDENTICAL_REL = 1e-9


def ngspice_version():
    """The same `ngspice-<n>` token sim/runner-lib.sh records: the banner's first line
    is a rule of asterisks, so the version has to be matched, not read positionally."""
    out = subprocess.run(["ngspice", "--version"], capture_output=True, text=True)
    m = re.search(r"ngspice-[0-9]+(\.[0-9]+)*", out.stdout + out.stderr)
    return m.group(0) if m else None


def run_probe(probe, models_dir, osdi_dir, workdir):
    device = probe["device"]
    libs = "\n".join(".lib %s/%s %s" % (models_dir, f, s) for f, s in probe["sections"])
    body = FIXTURES[device].format(params=probe.get("params", ""))
    pre = "\n".join("pre_osdi %s/%s.osdi" % (osdi_dir, o)
                    for o in (["psp103"] if device == "nmos" else
                              ["r3_cmc"] if device == "rppd" else []))
    a, b = READOUT[device]
    deck = ("* stat-locality probe: %s\n%s\n%s\n.control\n%s\nop\nprint %s %s\nquit\n"
            ".endc\n.end\n" % (probe["name"], libs, body, pre, a, b))
    path = os.path.join(workdir, "probe.cir")
    with open(path, "w") as f:
        f.write(deck)
    out = subprocess.run(["ngspice", "-b", path], capture_output=True, text=True).stdout
    values = {}
    for line in out.splitlines():
        parts = [p.strip() for p in line.split("=")]
        if len(parts) == 2 and parts[0].lower() in (a, b):
            try:
                values[parts[0].lower()] = float(parts[1])
            except ValueError:
                pass
    if len(values) != 2:
        return {"name": probe["name"], "error": "probe produced no two readings",
                "stdout_tail": out[-400:]}
    va, vb = values[a], values[b]
    scale = max(abs(va), abs(vb), 1e-30)
    rel = abs(va - vb) / scale
    verdict = "identical" if rel <= IDENTICAL_REL else "different"
    return {
        "name": probe["name"],
        "device": device,
        "sections": ["%s:%s" % (f, s) for f, s in probe["sections"]],
        "instance_params": probe.get("params") or None,
        "readout": [a, b],
        "values": [va, vb],
        "relative_difference": rel,
        "verdict": verdict,
        "locality": "local (per instance)" if verdict == "different" else "global (shared)",
        "expected": probe["expect"],
        "agrees_with_expectation": verdict == probe["expect"],
        "why": probe["why"],
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("-o", "--out", help="write the JSON record here (default: stdout only)")
    ap.add_argument("--models-dir", default=os.environ.get("CM5_NGSPICE_MODELS"))
    ap.add_argument("--osdi-dir", default=os.environ.get("CM5_OSDI_DIR"))
    args = ap.parse_args()

    if not args.models_dir or not os.path.isdir(args.models_dir):
        print("stat_locality: no models directory; run `source sim/env.sh` first "
              "(or pass --models-dir)", file=sys.stderr)
        return 2
    if not args.osdi_dir or not os.path.isdir(args.osdi_dir):
        print("stat_locality: no OSDI directory; run `source sim/env.sh` first "
              "(or pass --osdi-dir)", file=sys.stderr)
        return 2
    if not shutil.which("ngspice"):
        print("stat_locality: ngspice is not on PATH", file=sys.stderr)
        return 2

    results, problems = [], []
    workdir = tempfile.mkdtemp(prefix="cm5-stat-locality-")
    try:
        for probe in PROBES:
            lib_path = os.path.join(args.models_dir, probe["sections"][0][0])
            if not os.path.isfile(lib_path):
                problems.append("%s: %s is not at the pin" % (probe["name"], lib_path))
                continue
            r = run_probe(probe, args.models_dir, args.osdi_dir, workdir)
            results.append(r)
            if r.get("error"):
                problems.append("%s: %s" % (r["name"], r["error"]))
            elif not r["agrees_with_expectation"]:
                problems.append("%s: measured %r, this bench's reading of the PDK says %r"
                                % (r["name"], r["verdict"], r["expected"]))
    finally:
        shutil.rmtree(workdir, ignore_errors=True)

    record = {
        "schema_version": 1,
        "kind": "stat-locality-probe",
        "label": "SIMULATED",
        "tool": "sim/tools/stat_locality.py",
        "timestamp_utc": datetime.datetime.now(datetime.timezone.utc)
                                 .strftime("%Y%m%dT%H%M%SZ"),
        "pdk_revision": os.environ.get("CM5_PDK_REVISION"),
        "ngspice": ngspice_version(),
        "identical_relative_threshold": IDENTICAL_REL,
        "status": "ok" if not problems else "problems",
        "problems": problems,
        "probes": results,
    }
    text = json.dumps(record, indent=2, sort_keys=True) + "\n"
    if args.out:
        with open(args.out, "w") as f:
            f.write(text)
    for r in results:
        if r.get("error"):
            print("%-36s ERROR %s" % (r["name"], r["error"]))
        else:
            print("%-36s %-9s (%s)  rel=%.3g  %s" % (
                r["name"], r["verdict"], r["locality"], r["relative_difference"],
                "as expected" if r["agrees_with_expectation"] else "UNEXPECTED"))
    for p in problems:
        print("problem: %s" % p, file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
