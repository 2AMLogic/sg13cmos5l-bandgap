# T1 item 9 attestation (testbenches shipped)

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

When the item-5/6 benches land, add their bench files to `testbenches` (repo-relative, unique, no
symlinks), re-run the regeneration above on a provisioned host, and commit the inventory, envelope,
manifest hash, signoff record and any new smoke record together.
