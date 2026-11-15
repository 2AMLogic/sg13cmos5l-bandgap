#!/usr/bin/env python3
"""Check annotated figures in documents against the committed envelopes they cite.

Every checkable figure in an in-scope document carries a JSON annotation in an
HTML comment immediately above the block (paragraph, list item, or table) that
states it; the prose stays the human-readable form and the annotation is the
machine-checkable form:

    <!-- figure: {"envelope":"envelopes/20261113T115930Z-0be5a53.json","kind":"extremum",
         "measurement":"psrr_db","extremum":"min","printed":{"value":"55.249","unit":"dB",
         "corner":"wcs/2.970V/125C"},"anchor":"psrr_db"} -->
    | `psrr_db` | **55.249 dB** | `wcs/2.970V/125C` | 68.330 dB (`bcs/3.630V/27C`) |

For each annotation the checker (a) re-derives the value from the cited
envelope's full-precision `corners[].measurements[].value`, (b) rounds ONCE to
the printed literal's own decimal places -- directionally for extents, because
a range endpoint or an extremum states a bound, not a rounded value: a minimum
is compared against the floored rounding and a maximum against the ceilinged
rounding at the printed precision, so a printed endpoint may widen the stated
range but never narrow it -- and (c) requires the printed literal to occur in
the covered block -- so editing the prose without the annotation fails, and
editing the annotation without the prose fails too. Values are
never taken from a figure already printed in a document or from the envelope's
rounded summaries: a second rounding of a rounded value is exactly the bug
this checker exists for.

Annotation schema (one JSON object; `envelope` resolves relative to the
document's own directory; `subset` is equality/membership over the four fields
an envelope corner carries -- `process`, `supply_v` (mapping: a bare value
matches any net's value, `supply_v.<net>` names one), `temperature_c`,
`corner_id` (glob) -- and `anchor`, when given, narrows the covered block to
the lines containing it):

  kind         re-derived as
  -----------  ----------------------------------------------------------------
  cell         the measurement for one corner (`corner`), rounded once to the
               printed decimal places
  count        corners in `subset` satisfying `predicate` (`{"op": ">|>=|<|<=|
               ==|!=", "value": n, "unit": opt}` on `measurement`), or carrying
               `status` ("pass"/"fail"), or, with neither, the subset size;
               printed as "N" or "N/total"
  range        min/max of `measurement` over `subset` (printed.min /
               printed.max, one shared printed.unit); endpoints are bounds,
               each rounded once directionally -- the minimum against the
               floor and the maximum against the ceiling at the printed
               precision, so a span of 0.37-0.64 printed as 0.4-0.6 at one
               decimal is rejected while 0.37-0.64 and a conservative
               0.3-0.7 both pass
  pct_change   percentage change of `measurement` from the `from` corner to
               every corner in `subset`; must hold for EVERY corner, or split
               with "per": "<field>" and printed.values keyed by group value;
               optional "direction": "rise"/"fall"
  extremum     the corner actually holding the min/max of `measurement` over
               `subset`; "keyed_to": "<other measurement>" declares that the
               named corner is really that quantity's extremum, in which case
               printed.value is `measurement` AT that corner; printed.corner
               is optional when the covered block states only the value;
               printed.value rounds toward the conservative side (floor for
               a minimum, ceiling for a maximum)

Units convert through a small explicit scale table (V/mV/uV/nV, A/mA/uA/nA,
dB, dimensionless); typographic minus, dashes, micro signs and ellipses are
normalized before matching, so a document may print what it prints.

The manifest (`sim/documented-figures.json`) enumerates the in-scope
documents: {"schema_version": 1, "documents": [{"path": "sim/x/README.md"}]}.
A document in the manifest that carries no annotations is not an error: the
coverage summary reports it, because a document nobody has annotated yet must
not turn the suite red.

Exit status: 0 every annotation re-derives and matches (coverage summary
printed, including the count of un-annotated decimal figures per document);
1 a mismatch, a malformed annotation, a printed literal absent from its
covered block, or a document / cited envelope missing; 2 could not run
(manifest unreadable or malformed, bad arguments).

Offline: reads only committed files under --root, no network, no simulation,
no absolute host paths.
"""
import argparse
import json
import math
import os
import re
import sys
from decimal import Decimal, ROUND_CEILING, ROUND_FLOOR, ROUND_HALF_UP
from fnmatch import fnmatch

SUBSET_FIELDS = ("process", "supply_v", "temperature_c", "corner_id")
OPS = {
    ">": lambda a, b: a > b,
    ">=": lambda a, b: a >= b,
    "<": lambda a, b: a < b,
    "<=": lambda a, b: a <= b,
    "==": lambda a, b: a == b,
    "!=": lambda a, b: a != b,
}
UNIT_SCALES = {
    "V": {"V": 1, "mV": 1e3, "uV": 1e6, "nV": 1e9},
    "A": {"A": 1, "mA": 1e3, "uA": 1e6, "nA": 1e9},
    "dB": {"dB": 1},
    "": {"": 1},
}
NORMALIZE = {
    "\u2212": "-",
    "\u2013": "-",
    "\u2014": "-",
    "\u00b5": "u",
    "\u03bc": "u",
    "\u2026": "...",
}
NUM_RE = re.compile(r"[+-]?\d+\.\d+")
ANN_RE = re.compile(r"^\s*<!--\s*figure:\s*(.*)$")


class CheckError(Exception):
    pass


def norm(s):
    for k, v in NORMALIZE.items():
        s = s.replace(k, v)
    return s


def parse_num(s):
    t = norm(str(s)).strip().replace(" ", "")
    if not re.fullmatch(r"[+-]?\d+(\.\d+)?", t):
        raise CheckError(f"printed value {s!r} is not a plain decimal number")
    return Decimal(t)


def decimals_in(s):
    t = norm(str(s)).strip().lstrip("+-")
    return len(t.split(".", 1)[1]) if "." in t else 0


def round_once(value, nd, rounding=ROUND_HALF_UP):
    d = value if isinstance(value, Decimal) else Decimal(repr(float(value)))
    return d.quantize(Decimal(1).scaleb(-nd), rounding=rounding)


def fmt_dec(d, nd):
    return f"{d:.{nd}f}"


def unit_factor(unit):
    u = norm("" if unit is None else str(unit))
    for fam, table in UNIT_SCALES.items():
        if u in table:
            return fam, table[u]
    raise CheckError(f"unit {unit!r} is not in the scale table (V/mV/uV/nV, A/mA/uA/nA, dB, dimensionless)")


def convert(value, unit_from, unit_to):
    f1, m1 = unit_factor(unit_from)
    f2, m2 = unit_factor(unit_to)
    if f1 != f2:
        raise CheckError(f"cannot convert {unit_from!r} to {unit_to!r}: different unit families")
    return value * (m2 / m1)


def corner_field(c, key):
    if key == "supply_v" or key.startswith("supply_v."):
        sv = c.get("supply_v") or {}
        return sv if key == "supply_v" else sv.get(key.split(".", 1)[1])
    if key in ("process", "temperature_c", "corner_id"):
        return c.get(key)
    raise CheckError(
        f"selector field {key!r} is not one of {', '.join(SUBSET_FIELDS)} (dotted supply_v.<net> allowed)")


def match_value(got, want):
    if isinstance(want, list):
        return any(match_value(got, w) for w in want)
    if isinstance(got, dict):
        return any(match_value(v, want) for v in got.values())
    if isinstance(want, str) and any(ch in want for ch in "*?"):
        return fnmatch(norm(str(got)), norm(want))
    if isinstance(got, bool) or isinstance(want, bool):
        return got == want
    if isinstance(got, (int, float)) and isinstance(want, (int, float)):
        return math.isclose(float(got), float(want), rel_tol=1e-12, abs_tol=1e-12)
    return str(got) == str(want)


def select_corners(env, subset):
    if not isinstance(subset, dict):
        raise CheckError("subset must be an object")
    out = []
    for c in env.get("corners", []):
        if all(match_value(corner_field(c, k), w) for k, w in subset.items()):
            out.append(c)
    return out


def get_meas(c, name):
    for m in c.get("measurements", []):
        if m.get("name") == name:
            return m
    return None


def req(j, key, typ):
    v = j.get(key)
    if not isinstance(v, typ):
        raise CheckError(f"annotation field {key!r} is missing or not a {typ.__name__}")
    return v


def claim_str(j):
    bits = [str(j.get("kind", "?"))]
    if j.get("measurement"):
        bits.append(str(j["measurement"]))
    if j.get("extremum"):
        bits.append(str(j["extremum"]))
    if j.get("predicate"):
        bits.append(json.dumps(j["predicate"], sort_keys=True))
    if j.get("status"):
        bits.append(f"status={j['status']}")
    if j.get("subset"):
        bits.append(f"subset={json.dumps(j['subset'], sort_keys=True)}")
    if j.get("per"):
        bits.append(f"per={j['per']}")
    return " ".join(bits)


def check_value(printed, expected, block, what, env_rel, bound=None):
    ps = str(printed)
    nd = decimals_in(ps)
    if bound == "min":
        rounding, bound_txt = ROUND_FLOOR, " (conservative bound: floor at printed precision)"
    elif bound == "max":
        rounding, bound_txt = ROUND_CEILING, " (conservative bound: ceiling at printed precision)"
    else:
        rounding, bound_txt = ROUND_HALF_UP, ""
    want = round_once(expected, nd, rounding)
    probs = []
    if parse_num(ps) != want:
        probs.append(f"printed {ps} does not match {what}; expected {fmt_dec(want, nd)}{bound_txt} (from {env_rel})")
    if norm(ps) not in block:
        probs.append(f"printed literal {ps} absent from covered block")
    return probs


def check_cell(j, env, block, env_rel):
    name = req(j, "measurement", str)
    corner = req(j, "corner", str)
    printed = req(j, "printed", dict)
    cs = select_corners(env, {"corner_id": corner})
    if len(cs) != 1:
        raise CheckError(f"corner {corner!r} matches {len(cs)} corners in {env_rel}; expected exactly 1")
    m = get_meas(cs[0], name)
    if m is None:
        raise CheckError(f"measurement {name!r} absent from {env_rel}")
    val = float(m["value"])
    punit = printed.get("unit")
    if punit is not None:
        if not isinstance(punit, str):
            raise CheckError("printed.unit must be a string")
        val = convert(val, m.get("unit"), punit)
    probs = check_value(printed.get("value"), val, block, f"{name} at {corner}", env_rel)
    if punit and norm(punit) not in block:
        probs.append(f"printed unit {punit} absent from covered block")
    return probs


def check_count(j, env, block, env_rel):
    printed = req(j, "printed", dict)
    if printed.get("value") is None:
        raise CheckError("printed.value is missing")
    subset = j.get("subset", {})
    pred = j.get("predicate")
    status = j.get("status")
    if pred is not None and status is not None:
        raise CheckError("predicate and status are mutually exclusive")
    cs = select_corners(env, subset)
    total = len(cs)
    if pred is not None:
        if not isinstance(pred, dict) or pred.get("op") not in OPS or "value" not in pred:
            raise CheckError('predicate must be {"op": ">|>=|<|<=|==|!=", "value": number, "unit": optional}')
        name = req(j, "measurement", str)
        count = 0
        for c in cs:
            m = get_meas(c, name)
            if m is None:
                raise CheckError(f"measurement {name!r} absent from {env_rel}")
            pv = pred["value"]
            if pred.get("unit"):
                if not isinstance(pred["unit"], str):
                    raise CheckError("predicate.unit must be a string")
                pv = convert(float(pv), pred["unit"], m.get("unit"))
            if OPS[pred["op"]](float(m["value"]), float(pv)):
                count += 1
        desc = (f"{count} of {total} corners satisfy {pred['op']} {pred['value']}"
                f"{pred.get('unit') or ''} on {name}")
    elif status is not None:
        count = sum(1 for c in cs if c.get("status") == status)
        desc = f"{count} of {total} corners have status {status}"
    else:
        count = total
        desc = f"{total} corners in subset"
    ps = str(printed["value"])
    probs = []
    if "/" in ps:
        a, b = ps.split("/", 1)
        if parse_num(a) != Decimal(count) or parse_num(b) != Decimal(total):
            probs.append(f"printed {ps} does not match; expected {count}/{total} ({desc}, from {env_rel})")
    else:
        if parse_num(ps) != Decimal(count):
            probs.append(f"printed {ps} does not match; expected {count} ({desc}, from {env_rel})")
    if norm(ps) not in block:
        probs.append(f"printed literal {ps} absent from covered block")
    return probs


def check_range(j, env, block, env_rel):
    name = req(j, "measurement", str)
    printed = req(j, "printed", dict)
    for k in ("min", "max"):
        if printed.get(k) is None:
            raise CheckError(f"printed.{k} is missing")
    punit = printed.get("unit")
    if punit is not None and not isinstance(punit, str):
        raise CheckError("printed.unit must be a string")
    cs = select_corners(env, j.get("subset", {}))
    if not cs:
        raise CheckError(f"subset selects no corners in {env_rel}")
    vals = []
    for c in cs:
        m = get_meas(c, name)
        if m is None:
            raise CheckError(f"measurement {name!r} absent from {env_rel}")
        v = float(m["value"])
        if punit:
            v = convert(v, m.get("unit"), punit)
        vals.append(v)
    probs = check_value(printed["min"], min(vals), block, f"min {name} over subset", env_rel, bound="min")
    probs += check_value(printed["max"], max(vals), block, f"max {name} over subset", env_rel, bound="max")
    if punit and norm(punit) not in block:
        probs.append(f"printed unit {punit} absent from covered block")
    return probs


def check_pct(j, env, block, env_rel):
    name = req(j, "measurement", str)
    printed = req(j, "printed", dict)
    frm = j.get("from")
    if not isinstance(frm, dict):
        raise CheckError('"from" is required: a selector matching exactly one baseline corner')
    base_cs = select_corners(env, frm)
    if len(base_cs) != 1:
        raise CheckError(f'"from" matches {len(base_cs)} corners in {env_rel}; expected exactly 1')
    m0 = get_meas(base_cs[0], name)
    if m0 is None:
        raise CheckError(f"measurement {name!r} absent from {env_rel}")
    base = float(m0["value"])
    if base == 0.0:
        raise CheckError("baseline value is zero; percentage change is undefined")
    per = j.get("per")
    single = printed.get("value")
    values = printed.get("values")
    if per is not None and not isinstance(values, dict):
        raise CheckError('"per" requires printed.values: one printed value per group')
    if isinstance(values, dict) and per is None:
        raise CheckError('printed.values requires "per"')
    if single is None and values is None:
        raise CheckError('printed needs "value", or "values" with "per"')
    direction = j.get("direction")
    if direction not in (None, "rise", "fall"):
        raise CheckError('direction must be "rise" or "fall"')
    cs = select_corners(env, j.get("subset", {}))
    if not cs:
        raise CheckError(f"subset selects no corners in {env_rel}")
    base_id = base_cs[0].get("corner_id")
    probs = []
    for c in cs:
        m = get_meas(c, name)
        if m is None:
            raise CheckError(f"measurement {name!r} absent from {env_rel}")
        pct = (float(m["value"]) - base) / abs(base) * 100.0
        cid = c.get("corner_id")
        if direction == "rise" and pct < 0:
            probs.append(f"claimed rise but {name} falls at {cid}: {fmt_dec(round_once(pct, 1), 1)} % (from {env_rel})")
        if direction == "fall" and pct > 0:
            probs.append(f"claimed fall but {name} rises at {cid}: {fmt_dec(round_once(pct, 1), 1)} % (from {env_rel})")
        if isinstance(values, dict):
            gkey = norm(str(corner_field(c, per)))
            if gkey not in values:
                raise CheckError(f"printed.values has no entry for {per}={gkey}")
            ps = str(values[gkey])
        else:
            ps = str(single)
        probs += check_value(ps, pct, block, f"{name} change at {cid} vs {base_id}", env_rel)
    return probs


def check_extremum(j, env, block, env_rel):
    name = req(j, "measurement", str)
    ext = j.get("extremum")
    if ext not in ("min", "max"):
        raise CheckError('extremum must be "min" or "max"')
    printed = req(j, "printed", dict)
    if printed.get("value") is None:
        raise CheckError("printed.value is missing")
    keyed = j.get("keyed_to")
    if keyed is not None and not isinstance(keyed, str):
        raise CheckError("keyed_to must be a measurement name")
    pc = printed.get("corner")
    if keyed is not None and pc is None:
        raise CheckError("printed.corner is required when keyed_to is given")
    if pc is not None and not isinstance(pc, str):
        raise CheckError("printed.corner must be a string")
    cs = select_corners(env, j.get("subset", {}))
    if not cs:
        raise CheckError(f"subset selects no corners in {env_rel}")
    kname = keyed or name
    pairs = []
    for c in cs:
        m = get_meas(c, kname)
        if m is None:
            raise CheckError(f"measurement {kname!r} absent from {env_rel}")
        pairs.append((float(m["value"]), c))
    best = min(p[0] for p in pairs) if ext == "min" else max(p[0] for p in pairs)
    holders = [c for v, c in pairs if v == best]
    holder_ids = sorted(str(c.get("corner_id")) for c in holders)
    probs = []
    holder = None
    if pc is not None:
        for c in holders:
            if norm(str(c.get("corner_id"))) == norm(pc):
                holder = c
        if holder is None:
            probs.append(f"printed corner {pc} does not hold the {ext}imum of {kname}; "
                         f"expected one of {holder_ids} (from {env_rel})")
    if keyed:
        if holder is None:
            return probs
        m = get_meas(holder, name)
        if m is None:
            raise CheckError(f"measurement {name!r} absent from {env_rel}")
        expected, src_unit = float(m["value"]), m.get("unit")
        what = f"{name} at {pc} (the {ext}imum of {kname})"
    else:
        expected = best
        src_unit = get_meas(holders[0], kname).get("unit")
        what = f"{ext}imum of {kname} over subset"
    punit = printed.get("unit")
    if punit is not None:
        if not isinstance(punit, str):
            raise CheckError("printed.unit must be a string")
        expected = convert(expected, src_unit, punit)
        if norm(punit) not in block:
            probs.append(f"printed unit {punit} absent from covered block")
    probs += check_value(printed["value"], expected, block, what, env_rel, bound=ext)
    if pc is not None and norm(pc) not in block:
        probs.append(f"printed corner {pc} absent from covered block")
    return probs


KIND_CHECKS = {
    "cell": check_cell,
    "count": check_count,
    "range": check_range,
    "pct_change": check_pct,
    "extremum": check_extremum,
}


def collect_block(lines, i):
    n = len(lines)
    while i < n and lines[i].strip() == "":
        i += 1
    out, idxs = [], set()
    while i < n:
        s = lines[i]
        st = s.strip()
        if st == "" or st.startswith("#") or ANN_RE.match(s):
            break
        out.append(s)
        idxs.add(i)
        i += 1
    return out, idxs


def parse_document(text):
    lines = text.splitlines()
    anns, covered, ann_lines = [], set(), set()
    pending = []
    i, n = 0, len(lines)
    while i < n:
        m = ANN_RE.match(lines[i])
        if not m:
            if pending:
                block_lines, block_idxs = collect_block(lines, i)
                covered.update(block_idxs)
                for k, p in enumerate(pending):
                    p["idx"] = len(anns) + k + 1
                    p["block_lines"] = block_lines
                    anns.append(p)
                pending = []
            i += 1
            continue
        start = i
        seg = m.group(1)
        while "-->" not in seg and i + 1 < n:
            i += 1
            seg += "\n" + lines[i]
        terminated = "-->" in seg
        raw = (seg.split("-->", 1)[0] if terminated else seg).strip()
        for li in range(start, i + 1):
            ann_lines.add(li)
        entry = {"idx": None, "json": None, "malformed": None, "block_lines": []}
        if not terminated:
            entry["malformed"] = "unterminated <!-- figure: comment (no --> before end of file)"
        else:
            try:
                entry["json"] = json.loads(raw)
            except ValueError as exc:
                entry["malformed"] = f"annotation JSON does not parse: {exc}"
        pending.append(entry)
        i += 1
    for k, p in enumerate(pending):
        p["idx"] = len(anns) + k + 1
        anns.append(p)
    return anns, covered, ann_lines


def load_envelope(root, rel, j, cache):
    env_rel = j.get("envelope")
    if not isinstance(env_rel, str) or not env_rel:
        raise CheckError("annotation has no envelope path")
    if os.path.isabs(env_rel):
        raise CheckError(f"envelope path is absolute: {env_rel}")
    full = os.path.normpath(os.path.join(root, os.path.dirname(rel), env_rel))
    if not full.startswith(root + os.sep):
        raise CheckError(f"envelope path escapes the repo root: {env_rel}")
    if full not in cache:
        try:
            with open(full, encoding="utf-8") as fh:
                env = json.load(fh)
        except (OSError, ValueError) as exc:
            raise CheckError(f"cited envelope missing or unreadable: {env_rel}: {exc}")
        if not isinstance(env, dict) or not isinstance(env.get("corners"), list):
            raise CheckError(f"cited envelope has no corners[]: {env_rel}")
        cache[full] = env
    return cache[full]


def check_annotation(root, rel, ann, cache):
    j = ann["json"]
    if not isinstance(j, dict):
        raise CheckError("annotation is not a JSON object")
    kind = j.get("kind")
    if kind not in KIND_CHECKS:
        raise CheckError(f"unknown kind {kind!r}; expected one of {', '.join(sorted(KIND_CHECKS))}")
    env = load_envelope(root, rel, j, cache)
    block_lines = ann["block_lines"]
    if isinstance(j.get("anchor"), str):
        a = norm(j["anchor"])
        narrowed = [bl for bl in block_lines if a in norm(bl)]
        if not narrowed:
            raise CheckError(f"anchor {j['anchor']!r} matches no line of the covered block")
        block_lines = narrowed
    block = norm("\n".join(block_lines))
    if not block.strip():
        raise CheckError("covered block is empty; nothing follows the annotation")
    return KIND_CHECKS[kind](j, env, block, j["envelope"])


def fail(rel, ann, msg):
    return f"{rel}: figure #{ann.get('idx', '?')} [{claim_str(ann['json']) if isinstance(ann.get('json'), dict) else '?'}]: {msg}"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--manifest", default="sim/documented-figures.json",
                    help="manifest path, relative to --root (default: sim/documented-figures.json)")
    ap.add_argument("--root", default=".", help="repository root the manifest paths resolve against")
    args = ap.parse_args()
    root = os.path.realpath(args.root)
    if not os.path.isdir(root):
        print(f"check-documented-figures: ERROR not a directory: {args.root}", file=sys.stderr)
        return 2
    try:
        with open(os.path.join(root, args.manifest), encoding="utf-8") as fh:
            manifest = json.load(fh)
    except (OSError, ValueError) as exc:
        print(f"check-documented-figures: ERROR cannot read manifest {args.manifest}: {exc}", file=sys.stderr)
        return 2
    docs = manifest.get("documents") if isinstance(manifest, dict) else None
    if not isinstance(docs, list) or not docs:
        print("check-documented-figures: ERROR manifest has no documents list", file=sys.stderr)
        return 2
    for entry in docs:
        if not isinstance(entry, dict) or not isinstance(entry.get("path"), str):
            print("check-documented-figures: ERROR manifest entry without a document path", file=sys.stderr)
            return 2

    failures, summaries, total_ok = [], [], 0
    for entry in docs:
        rel = entry["path"]
        try:
            with open(os.path.join(root, rel), encoding="utf-8") as fh:
                text = fh.read()
        except OSError as exc:
            failures.append(f"{rel}: document missing or unreadable: {exc}")
            summaries.append(f"{rel}: UNREADABLE")
            continue
        anns, covered, ann_lines = parse_document(text)
        cache = {}
        n_ok = 0
        for ann in anns:
            if ann["malformed"]:
                failures.append(fail(rel, ann, ann["malformed"]))
                continue
            try:
                probs = check_annotation(root, rel, ann, cache)
            except CheckError as exc:
                failures.append(fail(rel, ann, str(exc)))
                continue
            if probs:
                for p in probs:
                    failures.append(fail(rel, ann, p))
            else:
                n_ok += 1
        unann = sum(len(NUM_RE.findall(norm(line)))
                    for idx, line in enumerate(text.splitlines())
                    if idx not in covered and idx not in ann_lines)
        total_ok += n_ok
        summaries.append(f"{rel}: {n_ok}/{len(anns)} annotation(s) verified, "
                         f"{unann} un-annotated decimal figure(s)")

    print("Documented-figure coverage")
    for s in summaries:
        print(f"  {s}")
    for f in failures:
        print(f"ERROR: {f}", file=sys.stderr)
    print(f"{total_ok} annotation(s) verified across {len(docs)} document(s); {len(failures)} problem(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
