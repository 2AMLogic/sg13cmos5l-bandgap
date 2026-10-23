#!/usr/bin/env python3
"""Check that the model-library sections spec/target-spec.md §PVT names exist.

Static parse of the corner files under the PDK's ngspice models directory
(no simulation). Run it after `source sim/env.sh`, which verifies the PDK
revision against sim/pdk.json and exports CM5_NGSPICE_MODELS:

    source sim/env.sh && python3 -I sim/tools/check-model-sections.py

Required sections are the §PVT table sections plus the `stat` section of
cornerPNP.lib. Mismatch candidates that exist (mos_*_stat, mos_*_mismatch,
res_stat, res_*_mismatch) are reported as informational and never affect the
exit code. `.include` lines inside a required section are followed one level,
only to name the file that defines it and to prove the target resolves.

Exit status: 0 every required section resolves; 1 a required section or an
included file is missing/unreadable; 2 usage or environment error.
"""
import argparse
import json
import os
import re
import sys

# (corner file, section) pairs from spec/target-spec.md §PVT.
REQUIRED = [
    ("cornerPNP.lib", s) for s in ("typ", "bcs", "wcs", "stat")
] + [
    ("cornerMOShv.lib", s) for s in ("mos_tt", "mos_ff", "mos_ss", "mos_sf", "mos_fs")
] + [
    ("cornerRES.lib", s) for s in ("res_typ", "res_bcs", "res_wcs")
]
CORNER_FILES = ("cornerPNP.lib", "cornerMOShv.lib", "cornerRES.lib")
MISMATCH_RE = re.compile(r"^(mos|res)_.*(stat|mismatch)$|^stat$", re.IGNORECASE)

LIB_RE = re.compile(r"^\s*\.lib\s+(\S+)\s*$", re.IGNORECASE)
ENDL_RE = re.compile(r"^\s*\.endl\b", re.IGNORECASE)
INC_RE = re.compile(r"""^\s*\.inc(?:lude)?\s+["']?([^"'\s]+)["']?""", re.IGNORECASE)


class FileProblem(Exception):
    pass


def parse_sections(path):
    """Return {section_name_lower: (name, [include targets])} for one .lib file."""
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            lines = fh.read().splitlines()
    except OSError as exc:
        why = "dangling symlink" if os.path.islink(path) and not os.path.exists(path) else exc.strerror
        raise FileProblem(f"cannot read {path}: {why}") from exc
    sections, current = {}, None
    for line in lines:
        m = LIB_RE.match(line)
        if m:
            current = (m.group(1), [])
            sections[m.group(1).lower()] = current
        elif ENDL_RE.match(line):
            current = None
        elif current is not None:
            m = INC_RE.match(line)
            if m:
                current[1].append(m.group(1))
    return sections


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--models-dir", default=os.environ.get("CM5_NGSPICE_MODELS"),
                    help="ngspice models directory (default: $CM5_NGSPICE_MODELS, exported by sim/env.sh)")
    ap.add_argument("--json", action="store_true", help="emit the report as JSON instead of text")
    args = ap.parse_args()
    if not args.models_dir:
        print("check-model-sections: ERROR CM5_NGSPICE_MODELS is unset and --models-dir not given; "
              "run `source sim/env.sh` first", file=sys.stderr)
        return 2
    if not os.path.isdir(args.models_dir):
        print(f"check-model-sections: ERROR not a directory: {args.models_dir}", file=sys.stderr)
        return 2

    parsed, file_errors = {}, {}
    for fname in CORNER_FILES:
        try:
            parsed[fname] = parse_sections(os.path.join(args.models_dir, fname))
        except FileProblem as exc:
            file_errors[fname] = str(exc)

    rows, failures = [], []
    for fname, section in REQUIRED:
        path = os.path.join(args.models_dir, fname)
        row = {"file": fname, "section": section, "defined_in": os.path.realpath(path),
               "found": False, "includes": []}
        if fname in file_errors:
            row["error"] = file_errors[fname]
            failures.append(f"{fname} {section}: {file_errors[fname]}")
        elif section.lower() not in parsed[fname]:
            row["error"] = "section not defined"
            failures.append(f"{fname} section '{section}' not defined")
        else:
            row["found"] = True
            for inc in parsed[fname][section.lower()][1]:
                target = os.path.join(args.models_dir, inc)
                ok = os.path.exists(target)
                row["includes"].append({"file": inc, "defined_in": os.path.realpath(target), "found": ok})
                if not ok:
                    failures.append(f"{fname} section '{section}' includes {inc}: file missing or dangling symlink")
        rows.append(row)

    info = [{"file": f, "section": name}
            for f in CORNER_FILES if f in parsed
            for key, (name, _) in parsed[f].items()
            if MISMATCH_RE.match(name) and (f, name) not in REQUIRED]

    if args.json:
        json.dump({"models_dir": args.models_dir, "required": rows, "informational_mismatch": info,
                   "failures": failures}, sys.stdout, indent=2)
        print()
    else:
        print(f"models dir: {args.models_dir}")
        for r in rows:
            status = "ok     " if r["found"] else "MISSING"
            print(f"{status} {r['file']}:{r['section']}  defined_in={r['defined_in']}")
            for i in r["includes"]:
                print(f"          include {i['file']} -> {i['defined_in']}{'' if i['found'] else '  (MISSING)'}")
        print("informational mismatch candidates (not required):")
        for i in info:
            print(f"  {i['file']}:{i['section']}")
        for msg in failures:
            print(f"ERROR: {msg}", file=sys.stderr)
        print(f"{len(rows) - sum(1 for r in rows if not r['found'])}/{len(rows)} required sections found; "
              f"{len(failures)} problem(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
