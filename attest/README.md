# T1 attestation inventories

This directory holds one `klt signoff --attest` inventory per attested T1 item:
`item1.json` (design sources), `item9.json` (testbenches shipped) and
`item10.json` (repo hygiene), plus `make-item2-envelope.py` for item 2. Every
envelope they produce lands in `../evidence/` and is cited by
`../manifests/sg13cmos5l-bandgap.json`.

**Everything below is about item 9 unless a heading says otherwise**; item 1 has
its own section at the end, item 10's regeneration command is in
`../manifests/README.md`, and item 2's is in `../layout/README.md`.

## Item 9 (testbenches shipped)

- `item9.json`: the inventory. Lists every committed bench, the cold-start command and the pins
  (PDK name and revision, klt, ngspice, OSDI build commit).
- `../evidence/item9.json`: the envelope `klt signoff --attest 9` produced from it, cited by
  `manifests/sg13cmos5l-bandgap.json`.

## Cold-start invocation

From the repo root, on a host with the pinned PDK, ngspice >= 43 and `psp103.osdi` (`sim/README.md`):

```
source sim/env.sh && sim/smoke/run_smoke.sh
```

This is one single-corner local `ngspice` run (typ / 27 C / 3.3 V). The 45-point closed-loop grid
(`sim/closed-loop-vref-pvt/`) is inventoried as a bench but is not the cold start: it goes to the
batch fleet through `klt sim`.

## Append-only records

Each attestation run executes `run_smoke.sh`, which writes one new `sim/smoke/records/*.json`.
Those records are append-only evidence: commit the new one with the regenerated envelope, never
edit or delete an existing one. The envelope does not hash the records, so they do not cause drift.

## Regenerating

```
uvx --from "klayout-tools==0.8.0" klt signoff --attest 9 --inventory attest/item9.json -o evidence/item9.json
```

Then update the `content_hash` for item 9 in the manifest to the inventory's sha256 (printed as
`inventory:`), and regenerate the signoff record as in `manifests/README.md`.
Any change to the inventory or to an inventoried bench byte changes the hashes.

## What CI skips

`cold_start` is `local_only`: GitHub's runner has no PDK, ngspice 43+ or OSDI objects. CI runs
`klt signoff --attest 9 ... --check`, which lists the cold start under `skipped_checks` (`[SKIP]`,
its committed outcome carried through) and still re-hashes every inventoried file. A passing CI
`--check` therefore does not re-prove the cold start; only a provisioned host's `--attest` does.
`bash sim/tests/test-attest-pins.sh` keeps the inventory's PDK and OSDI pins equal to
`sim/pdk.json` and `reuse.lock.json`.

## Extending

When a bench lands, add its bench files to `testbenches` (repo-relative, unique, no symlinks),
re-run the regeneration above on a provisioned host, and commit the inventory, envelope,
manifest hash, signoff record and any new smoke record together.

Done once already, for the five item-5 PVT-grid benches (issue #30, decision record 0011): the
inventory now carries 11 entries, each bench contributing its **deck template** and its
committed **`klt sim` request** — what the bench is. `bench.json` and `sim/grid-run.sh` are
runner plumbing and are deliberately not inventoried, the same convention that already left each
bench's `run.sh` out. The grids themselves are not cold-started here either: they go to the
Spot batch fleet, which a GitHub runner cannot reach any more than it can reach the PDK.

## Item 1 (design sources)

- `item1.json`: the inventory. Lists the four schematics, their three symbols,
  `design/xschemrc`, and — deliberately — the two files that implement the
  freshness gate itself (`design/check-netlist-freshness.sh`,
  `design/tools/netlist_pin_delta.py`). Item 1 binds every `sources` entry by
  hash, so listing the gate there means its tolerance cannot be widened without
  re-attesting and re-pinning the manifest.
- `../evidence/item1.json`: the envelope, 18 checks (10 `present` sources, 4
  `present` derived netlists, 4 `freshness` commands).

The freshness check is **not** a raw `klt netlist --check`. It is
`design/check-netlist-freshness.sh`, one invocation per cell, which re-exports
the schematic with `klt netlist` and compares the result under a normalization
that tolerates exactly two classified differences — xschem's absolute-path
provenance comments and the `mm_ok=1` PDK-pin delta — and nothing else. Why, and
why the netlists are not simply regenerated, is
[`0015`](../spec/decision-records/0015-item1-netlist-freshness-gate.md); how to
run it is `../design/README.md`.

### Regenerating

Needs xschem 3.4.7 and the PDK revision `sim/pdk.json` pins (`sim/env.sh`
refuses any other revision):

```
source sim/env.sh
uvx --from "klayout-tools==0.8.0" klt signoff --attest 1 \
    --inventory attest/item1.json -o evidence/item1.json
```

Then re-pin the item-1 `content_hash` in the manifest to the inventory sha256 it
prints as `inventory:`, and regenerate the signoff record
(`../manifests/README.md`).

### What CI skips

All four `freshness` commands are `local_only`: a GitHub runner has no xschem and
no PDK. CI runs `klt signoff --attest 1 ... --check`, which lists them `[SKIP]`
with their committed outcome carried and still re-hashes every inventoried file.
A green CI run therefore does **not** re-prove the re-export; only a provisioned
host's `--attest` does. What CI *does* re-prove on every push is that the
normalization stayed narrow, via `design/tests/test-netlist-pin-delta.sh`, which
needs only bash and python3.
