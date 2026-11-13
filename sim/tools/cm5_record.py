"""Shared bench-record helpers (issue #37). Stdlib only; import with
sys.path.insert(0, <this dir>) because runners call python3 -I."""
import hashlib
import json
import subprocess


def sha256(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def klt_version():
    return subprocess.run(["klt", "--version"], capture_output=True, text=True).stdout.strip()


def walk(o):
    """Yield every dict anywhere inside a klt envelope."""
    if isinstance(o, dict):
        yield o
        for v in o.values():
            yield from walk(v)
    elif isinstance(o, list):
        for v in o:
            yield from walk(v)


def collect(envelope, names):
    """Find {name, value} or {<name>: number} dicts anywhere in the envelope."""
    values = {}
    for d in walk(envelope):
        for k in names:
            if isinstance(d.get(k), (int, float)):
                values[k] = d[k]
            elif d.get("name") == k and isinstance(d.get("value"), (int, float)):
                values[k] = d["value"]
    return values


def write_record(path, record):
    """Create path exclusively (append-only evidence): raises if it exists."""
    with open(path, "x") as f:
        f.write(json.dumps(record, indent=2, sort_keys=True) + "\n")


def grid_summary(envelope, max_failing=60):
    """Per-row pass/fail and binding corner for a multi-corner `klt sim` envelope.

    T1 item 5 wants "per-row pass/fail and the binding corner recorded" (issue #30).
    `klt sim` already rolls that up in `measurements[]` (worst_case / min / max per
    measurement name) and in `corners[]` (per-point status), so this reduces rather
    than recomputes: nothing here re-derives a verdict the envelope did not state.
    `spec_row` is echoed from the per-corner measurement entries, which is where
    `klt sim` carries the tag `klt signoff` derives item 5's row coverage from.
    Returns None when the envelope is unreadable.
    """
    if not isinstance(envelope, dict):
        return None
    spec_rows = {}
    for corner in envelope.get("corners") or []:
        for m in corner.get("measurements") or []:
            if m.get("spec_row"):
                spec_rows[m.get("name")] = m["spec_row"]
    rows = []
    for m in envelope.get("measurements") or []:
        row = {
            "name": m.get("name"),
            "status": m.get("status"),
            "unit": m.get("unit"),
            "limits": m.get("limits"),
            "worst_case": m.get("worst_case"),
            "min": m.get("min"),
            "max": m.get("max"),
        }
        if m.get("name") in spec_rows:
            row["spec_row"] = spec_rows[m["name"]]
        rows.append(row)
    failing = []
    for corner in envelope.get("corners") or []:
        if corner.get("status") == "pass":
            continue
        failing.append({
            "corner_id": corner.get("corner_id"),
            "status": corner.get("status"),
            "diagnostics": [d.get("code") for d in (corner.get("diagnostics") or [])],
            "measurements": [
                {"name": m.get("name"), "status": m.get("status"), "value": m.get("value")}
                for m in (corner.get("measurements") or [])
                if m.get("status") != "pass"
            ],
        })
    coverage = envelope.get("coverage") or {}
    return {
        "envelope_status": envelope.get("status"),
        "points_total": envelope.get("corner_count"),
        "points_passed": envelope.get("passed"),
        "points_failed": envelope.get("failed"),
        "points_errored": envelope.get("errored"),
        "points_inconclusive": envelope.get("inconclusive"),
        "measurements_declared": coverage.get("measurements_declared"),
        "measurements_with_limits": coverage.get("measurements_with_limits"),
        "rows": rows,
        "failing_points": failing[:max_failing],
        "failing_points_truncated": len(failing) > max_failing,
    }
