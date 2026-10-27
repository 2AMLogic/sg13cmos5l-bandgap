# Block manifests

`sg13cmos5l-bandgap.json` is the block manifest graded by `klt signoff`
against the T1 checklist. Its `evidence` map gains one
citation per checklist item as artifacts land (item 9: `evidence/item9.json`, see
`attest/README.md`; item 10: `evidence/item10.json`, produced from
`attest/item10.json`).

- `design-evidence-tiers.md` is the checklist, vendored byte-identical from
  `2AMLogic/klayout-tools` `docs/design-evidence-tiers.md` at commit
  `44cc42323184` (git blob `2f7f69825f8c`).
- `sg13cmos5l-bandgap.signoff.json` is the verdict of record: the committed
  output of `klt signoff`, pinned to `klayout-tools==0.8.0` (the first release with `--attest`).

## Regenerating the record

Run from the repo root (the record embeds the `--tiers-doc` path). Exit 3
means "grader ran, items unmet" and is expected until T1 is reached.

```
uvx --from "klayout-tools==0.8.0" klt signoff \
    --manifest manifests/sg13cmos5l-bandgap.json \
    --tiers-doc manifests/design-evidence-tiers.md \
    --format json > manifests/sg13cmos5l-bandgap.signoff.json
```

Any change to the manifest, the checklist or cited evidence must regenerate
the record in the same PR. `.github/workflows/signoff.yml` re-runs the
command with the same pin (0.8.0), accepts exit 0 and 3 only, and byte-compares.

## Item 10 attestation

```
uvx --from "klayout-tools==0.8.0" klt signoff --attest 10 \
    --inventory attest/item10.json -o evidence/item10.json
```

Update the `content_hash` cited in the manifest if the envelope changes, then
regenerate the record. CI runs the same command with `--check`.
