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
