#!/usr/bin/env python3
"""Device inventory of a schematic DUT netlist against a `klt extract` netlist (issue #32).

T1 item 7 is graded on a `klt pex` schematic-vs-extracted delta. A delta row only
means something if both legs instantiate the same devices: a device the extraction
deck does not recognise is not flagged, it is simply **absent** from the extracted
netlist, and the extracted leg then simulates a different circuit that still
converges and still reports numbers. `klt pex` has its own `model_mismatch` block for
this, but it is only computed when a measurement leg runs -- an
`--extract-only` report (klayout-tools#3739) carries no reference netlist at all, so
nothing in that envelope compares the two device sets.

This tool makes that comparison from the two committed netlists alone: no PDK, no
simulator, no klt, no network. It tallies the leaf-device instances each side
instantiates, per model/subcircuit name, and reports the multiset difference.

    python3 -I sim/tools/pex_device_inventory.py \
        --schematic design/sg13cmos5l/netlist/bandgap_top.spice \
        --extracted sim/pex-bandgap-top/extracted/<utc>-<sha>.spice \
        --extracted-top sg13cmos5l_bandgap_top

Exit 0 = the two device multisets agree (a delta run compares like with like).
Exit 1 = they differ (named in the report; the delta would not be comparable).
Exit 2 = usage error or a netlist that cannot be read.

Scope of the parser, stated rather than implied. It is a deliberately narrow
SPICE-card reader, not a netlister: `*`/`;` comments and blank lines are dropped,
`+` continuations are joined, directives are matched case-insensitively, and
`.subckt`/`.ends` blocks are tracked. A device card's model name is its last token
that is not `key=value`. An `X` call naming a `.subckt` defined in the same file is
expanded recursively (so a hierarchical schematic export is counted per physical
instance, the way a flat extraction is -- the hierarchy false-positive
`docs/cli/pex.md` warns about for `model_mismatch`); any other call is a leaf
device. `m=<int>` multiplies the instance count into a unit count; a non-integer
`m=` (an expression) counts as 1 and is named in `warnings`. Sources
(`V/I/E/F/G/H`) and bare `R`/`C`/`L` primitives with a numeric value -- which is
what `klt extract --parasitics` writes for every parasitic -- are not devices and
are tallied separately.
"""
import argparse
import hashlib
import json
import re
import sys

#: Card prefixes whose last bare token is a model or subcircuit name.
MODEL_CARD_PREFIXES = ("X", "M", "Q", "D", "J", "Z")
#: Card prefixes that are stimulus, never a device under comparison.
SOURCE_CARD_PREFIXES = ("V", "I", "E", "F", "G", "H")
#: Card prefixes that are a device only when they carry a model/subckt token.
PASSIVE_CARD_PREFIXES = ("R", "C", "L")

_KV = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*\s*=")
_NUMERIC = re.compile(r"^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?[tgmkunpfa]?(eg|il|eil)?$")


def _sha256(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def _logical_lines(text):
    """Comment-stripped, continuation-joined cards, in file order."""
    out = []
    for raw in text.splitlines():
        line = raw.split(";", 1)[0].rstrip()
        if not line.strip() or line.lstrip().startswith("*"):
            continue
        if line.lstrip().startswith("+"):
            if out:
                out[-1] = out[-1] + " " + line.lstrip()[1:].strip()
            continue
        out.append(line.strip())
    return out


def _tokens(card):
    """Split a card, keeping `{...}` expressions as one token."""
    toks, buf, depth = [], "", 0
    for ch in card:
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth = max(0, depth - 1)
        if ch.isspace() and depth == 0:
            if buf:
                toks.append(buf)
                buf = ""
            continue
        buf += ch
    if buf:
        toks.append(buf)
    return toks


def parse_netlist(path):
    """-> (blocks, top_cards). `blocks` maps lowercased .subckt name -> card list."""
    with open(path) as f:
        text = f.read()
    blocks, top_cards, stack = {}, [], []
    for card in _logical_lines(text):
        low = card.lower()
        if low.startswith(".subckt"):
            toks = _tokens(card)
            if len(toks) < 2:
                raise ValueError("%s: malformed .subckt card: %r" % (path, card))
            name = toks[1].lower()
            blocks[name] = []
            stack.append(name)
            continue
        if low.startswith(".ends") or low.startswith(".eom"):
            if stack:
                stack.pop()
            continue
        if low.startswith("."):
            continue
        (blocks[stack[-1]] if stack else top_cards).append(card)
    return blocks, top_cards


def _model_of(card):
    """The model/subcircuit name a card instantiates, or None if it has none."""
    toks = _tokens(card)
    bare = [t for t in toks[1:] if not _KV.match(t)]
    if not bare:
        return None
    return bare[-1]


def _multiplier(card):
    """`m=<int>` as an int, or (1, False) when absent/non-integer."""
    for tok in _tokens(card)[1:]:
        if tok.lower().startswith("m=") and _KV.match(tok):
            value = tok.split("=", 1)[1]
            try:
                m = int(value)
            except ValueError:
                return 1, False
            return (m, True) if m > 0 else (1, False)
    return 1, True


def tally(path, entry=None):
    """Leaf-device inventory of one netlist, expanding in-file `.subckt` calls."""
    blocks, top_cards = parse_netlist(path)
    if entry is not None:
        key = entry.lower()
        if key not in blocks:
            raise ValueError("%s: no `.subckt %s` in this netlist (have: %s)"
                             % (path, entry, ", ".join(sorted(blocks)) or "none"))
        cards, entry_name = blocks[key], entry
    else:
        cards, entry_name = top_cards, "<top level>"

    devices, warnings = {}, []
    passives = {"resistor_cards": 0, "capacitor_cards": 0, "inductor_cards": 0}
    sources = 0

    def bump(name, mult):
        slot = devices.setdefault(name, {"instances": 0, "units": 0})
        slot["instances"] += 1
        slot["units"] += mult

    def walk(cards, mult, path_names):
        nonlocal sources
        for card in cards:
            prefix = card[0].upper()
            if prefix in SOURCE_CARD_PREFIXES:
                sources += 1
                continue
            model = _model_of(card)
            if prefix in PASSIVE_CARD_PREFIXES and (model is None or _NUMERIC.match(model)):
                passives[{"R": "resistor_cards", "C": "capacitor_cards",
                          "L": "inductor_cards"}[prefix]] += 1
                continue
            if model is None:
                warnings.append("card has no model/subcircuit token: %r" % card)
                continue
            m, exact = _multiplier(card)
            if not exact:
                warnings.append("non-integer m= on %r: counted as m=1" % card.split()[0])
            key = model.lower()
            if prefix == "X" and key in blocks:
                if key in path_names:
                    raise ValueError("%s: recursive .subckt call %s" % (path, model))
                walk(blocks[key], mult * m, path_names | {key})
                continue
            bump(model, mult * m)

    walk(cards, 1, set())
    return {
        "netlist": path,
        "sha256": _sha256(path),
        "entry": entry_name,
        "devices": dict(sorted(devices.items(), key=lambda kv: kv[0].lower())),
        "device_cards": sum(d["instances"] for d in devices.values()),
        "device_units": sum(d["units"] for d in devices.values()),
        "parasitic_and_primitive_cards": passives,
        "source_cards": sources,
        "warnings": warnings,
    }


def compare(schematic, extracted):
    """Multiset difference of the two device inventories, lowercase-keyed.

    ngspice is case-insensitive about model and subcircuit names, so the comparison
    is too; each side's own spelling is reported beside its counts.
    """
    def fold(side):
        folded = {}
        for name, counts in side["devices"].items():
            slot = folded.setdefault(name.lower(), {"instances": 0, "units": 0, "names": []})
            slot["instances"] += counts["instances"]
            slot["units"] += counts["units"]
            if name not in slot["names"]:
                slot["names"].append(name)
        return folded

    s, e = fold(schematic), fold(extracted)
    schematic_only = {k: s[k] for k in sorted(set(s) - set(e))}
    extracted_only = {k: e[k] for k in sorted(set(e) - set(s))}
    count_only = {
        k: {"schematic": s[k], "extracted": e[k]}
        for k in sorted(set(s) & set(e))
        if (s[k]["instances"], s[k]["units"]) != (e[k]["instances"], e[k]["units"])
    }
    if schematic_only or extracted_only:
        status, kind = "mismatch", "model_set"
    elif count_only:
        status, kind = "mismatch", "count_only"
    else:
        status, kind = "match", None
    detail = {
        "model_set": "the extracted netlist does not instantiate every device model the "
                     "schematic DUT does (or instantiates one it does not): a `klt pex` "
                     "delta computed from these two netlists would compare different "
                     "circuits, not a parasitic effect.",
        "count_only": "both netlists instantiate the same device models but not the same "
                      "number of instances; check finger/multiplier decomposition before "
                      "reading any delta row.",
        None: "both netlists instantiate the same device models the same number of times.",
    }[kind]
    return {"status": status, "kind": kind, "schematic_only": schematic_only,
            "extracted_only": extracted_only, "count_only": count_only, "detail": detail}


def render_text(report):
    out = []
    for side in ("schematic", "extracted"):
        s = report[side]
        out.append("%s: %s" % (side, s["netlist"]))
        out.append("  entry: %s   sha256: %s" % (s["entry"], s["sha256"][:16] + "..."))
        for name, c in s["devices"].items():
            out.append("  %-18s %3d card(s)  %3d unit(s)" % (name, c["instances"], c["units"]))
        out.append("  %-18s %3d card(s)  %3d unit(s)" % ("TOTAL", s["device_cards"],
                                                         s["device_units"]))
        p = s["parasitic_and_primitive_cards"]
        out.append("  parasitic/primitive cards: R=%d C=%d L=%d; sources: %d"
                   % (p["resistor_cards"], p["capacitor_cards"], p["inductor_cards"],
                      s["source_cards"]))
        for w in s["warnings"]:
            out.append("  WARNING: " + w)
    d = report["difference"]
    out.append("difference: %s%s" % (d["status"], " (%s)" % d["kind"] if d["kind"] else ""))
    for label, key in (("schematic only", "schematic_only"), ("extracted only", "extracted_only")):
        for name, c in d[key].items():
            out.append("  %s: %s  %d card(s), %d unit(s)"
                       % (label, "/".join(c["names"]), c["instances"], c["units"]))
    for name, c in d["count_only"].items():
        out.append("  count differs: %s  schematic %d/%d vs extracted %d/%d (cards/units)"
                   % (name, c["schematic"]["instances"], c["schematic"]["units"],
                      c["extracted"]["instances"], c["extracted"]["units"]))
    out.append("  " + d["detail"])
    return "\n".join(out)


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Compare the device inventory of a schematic DUT netlist against a "
                    "`klt extract` netlist (T1 item 7 prerequisite, issue #32).")
    ap.add_argument("--schematic", required=True, help="the schematic DUT netlist")
    ap.add_argument("--schematic-top", default=None,
                    help="`.subckt` to enter on the schematic side (default: top-level cards)")
    ap.add_argument("--extracted", required=True, help="the `klt extract` netlist")
    ap.add_argument("--extracted-top", default=None,
                    help="`.subckt` to enter on the extracted side (default: top-level cards)")
    ap.add_argument("--format", choices=("text", "json"), default="text")
    ap.add_argument("-o", "--output", default=None, help="also write the JSON report here")
    args = ap.parse_args(argv)

    try:
        report = {
            "schema_version": 1,
            "kind": "pex-device-inventory",
            "schematic": tally(args.schematic, args.schematic_top),
            "extracted": tally(args.extracted, args.extracted_top),
        }
    except (OSError, ValueError) as exc:
        print("pex_device_inventory: %s" % exc, file=sys.stderr)
        return 2
    report["difference"] = compare(report["schematic"], report["extracted"])

    text = json.dumps(report, indent=2, sort_keys=True)
    if args.output:
        with open(args.output, "w") as f:
            f.write(text + "\n")
    print(text if args.format == "json" else render_text(report))
    return 0 if report["difference"]["status"] == "match" else 1


if __name__ == "__main__":
    sys.exit(main())
