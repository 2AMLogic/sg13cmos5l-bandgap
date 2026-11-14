#!/usr/bin/env python3
"""Compare a committed xschem netlist against a freshly regenerated one, tolerating
exactly two classified, non-topological differences and nothing else.

This is the freshness predicate T1 item 1 is attested on for this block
(spec/decision-records/0015-item1-netlist-freshness-gate.md). A raw byte compare --
`klt netlist --check` -- cannot be used here, for two reasons neither of which is a
schematic change:

1. **Provenance header comments.** xschem writes `** sch_path:` / `** sym_path:`
   lines holding the *absolute* path of the generating checkout, and `klt netlist`
   prepends its own `** klt-netlist-inputs:` line. All three differ on every
   checkout and every tool revision, so a byte compare can never report in sync.

2. **The `mm_ok=1` PDK-pin delta.** The committed netlists were exported against the
   archived PDK revision `607e18d4`; this repo pins the `dev` revision
   `f7bca32694fe` (sim/pdk.json), whose device symbols emit an extra `mm_ok=1`
   instance parameter. `mm_ok` gates per-instance mismatch `agauss()` spread in the
   PDK's `*_mismatch` model sections and is an inert accepted parameter in the
   non-mismatch sections this block's corner runs use. `2AMLogic/sg13g2-bandgap`
   owns these cells by lineage and ratified (its #405/#406) keeping the archived-pin
   bytes and classifying this token as the expected delta, with regeneration
   deferred to its #322.

Everything else is compared verbatim: every device card, model name, net name,
device size and multiplier, every `.subckt` / `**.subckt` port list (so the xschem
3.4.4-vs-3.4.7 port-order export difference the operator ruled on in
sg13g2-bandgap#441/#442 would still be caught if it returned), every `*.iopin`
declaration, every blank line and every other comment.

The tolerance is narrow by construction. ` mm_ok=1` is removed ONLY from an instance
card (`X...`) naming one of the four classified device models, and only at exactly
that value: `mm_ok=0`, `mm_ok=2` or `mm_ok=1` on any other model is a difference and
fails. Removal is symmetric (either side may carry it) and the per-side token counts
are reported, so the tolerance that was applied is always visible in the output and
in the attestation envelope's check record.

Exit status: 0 the two agree under the normalization, 1 they do not (a real drift),
2 usage/IO error. Reads files only; runs nothing.
"""

from __future__ import annotations

import argparse
import difflib
import json
import re
import sys

#: xschem / klt provenance comment lines. Checkout- and tool-revision-specific, never
#: circuit content. Dropped from both sides before comparing.
HEADER_COMMENT = re.compile(r"^\*\* (?:sch_path|sym_path|klt-netlist-inputs):")

#: The device models whose symbols emit `mm_ok` at this repo's PDK pin but did not at
#: the archived pin the committed netlists were exported against. Classified in
#: 2AMLogic/sg13g2-bandgap#405; any model outside this set is NOT tolerated.
PIN_DELTA_MODELS = ("sg13_hv_nmos", "sg13_hv_pmos", "rppd", "rhigh")

#: An instance card of a classified model carrying exactly ` mm_ok=1`.
_MODELS = "|".join(PIN_DELTA_MODELS)
PIN_DELTA_CARD = re.compile(
    r"^X\S+\s.*\s(?:" + _MODELS + r")\s",
)
PIN_DELTA_TOKEN = re.compile(r" mm_ok=1(?= |$)")


def normalize(text: str) -> tuple[list[str], int]:
    """Return (normalized lines, number of tolerated `mm_ok=1` tokens removed)."""
    lines: list[str] = []
    tokens = 0
    for line in text.splitlines():
        if HEADER_COMMENT.match(line):
            continue
        if PIN_DELTA_CARD.match(line):
            line, n = PIN_DELTA_TOKEN.subn("", line)
            tokens += n
        lines.append(line)
    return lines, tokens


def read(path: str) -> str:
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read()
    except OSError as exc:
        # Exit 2, never 1: "I could not read a side" must not be reportable as "drift".
        print(
            "netlist_pin_delta: cannot read %s: %s" % (path, exc.strerror or exc),
            file=sys.stderr,
        )
        raise SystemExit(2)


def compare(committed_path: str, regenerated_path: str) -> dict:
    committed, committed_tokens = normalize(read(committed_path))
    regenerated, regenerated_tokens = normalize(read(regenerated_path))
    diff = list(
        difflib.unified_diff(
            committed,
            regenerated,
            fromfile="committed:" + committed_path,
            tofile="regenerated:" + regenerated_path,
            lineterm="",
        )
    )
    return {
        "status": "fresh" if not diff else "drifted",
        "committed": committed_path,
        "regenerated": regenerated_path,
        "normalization": {
            "dropped_header_comments": ["** sch_path:", "** sym_path:", "** klt-netlist-inputs:"],
            "tolerated_parameter": "mm_ok=1",
            "tolerated_on_models": list(PIN_DELTA_MODELS),
            "tolerated_tokens": {
                "committed": committed_tokens,
                "regenerated": regenerated_tokens,
            },
        },
        "diff": diff,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--committed", required=True, help="the committed netlist in git")
    parser.add_argument("--regenerated", required=True, help="a freshly exported netlist")
    parser.add_argument("--format", choices=("text", "json"), default="text")
    args = parser.parse_args(argv)

    result = compare(args.committed, args.regenerated)

    if args.format == "json":
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        tol = result["normalization"]["tolerated_tokens"]
        print("status: %s" % result["status"])
        print(
            "tolerated mm_ok=1 tokens: committed=%d regenerated=%d"
            % (tol["committed"], tol["regenerated"])
        )
        if result["diff"]:
            print()
            print("\n".join(result["diff"]))
    return 0 if result["status"] == "fresh" else 1


if __name__ == "__main__":
    sys.exit(main())
