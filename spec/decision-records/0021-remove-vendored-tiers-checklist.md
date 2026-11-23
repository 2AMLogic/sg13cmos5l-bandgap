# 0021: Stop vendoring the T1 checklist — the pinned klayout-tools release alone selects it

- **Status**: ratified, effective when the PR for issue #81 merges
- **Date**: 2026-11-23
- **Decided by**: operator ruling of 2026-11-23 (attended `/fleet:decide` session, round 20261121-r19, q103), recorded by Loom Builder agent, issue #81 (reverses the #3 deliverable that vendored it)

## Context

Issue #3 delivered `manifests/design-evidence-tiers.md` as a vendored copy
of the T1 checklist, and every `klt signoff` caller
(`.github/workflows/signoff.yml`, `manifests/README.md`) passed
`--tiers-doc manifests/design-evidence-tiers.md`. The copy is byte-identical
to the `klayout_tools/data/design-evidence-tiers.md` bundled in the pinned
`klayout-tools==0.8.0` wheel — both sha256
`a26b90262320d0fbd32b3f549a02b6300832706041797a559d8bf6bdb62efdc7` — so the
vendor is a second copy of a document the pin already fixes, and a pin bump
that changed the checklist would land as a silent divergence between the
two copies instead of a visible record change.

## Decision

Per the operator ruling of 2026-11-23 (round 20261121-r19, q103, made once
for the twelve repos that asked the same question): **remove the vendored
checklist and the `--tiers-doc` override; the pinned klayout-tools release
alone selects the checklist.** This reverses issue #3's "vendored checklist"
deliverable as filed.

- `manifests/design-evidence-tiers.md` is deleted (no `.UPSTREAM` marker
  existed beside it).
- No caller passes `--tiers-doc` any more; the prose that described the
  vendoring (`.github/workflows/signoff.yml` header, `manifests/README.md`,
  `README.md`'s repo-layout tree) now says the checklist is the
  `docs/design-evidence-tiers.md` bundled in the pinned wheel, linking
  2AMLogic/klayout-tools at the v0.8.0 tag.
- `manifests/sg13cmos5l-bandgap.signoff.json` is regenerated once under the
  0.8.0 pin without the override. The only line that moves is `source_doc`:
  the canonical label `docs/design-evidence-tiers.md` (a path inside the
  klayout-tools distribution) replaces the repo-relative vendor path.
  `source_doc_content_hash` is unchanged — the graded checklist is the same
  document — and no item verdict, count or tier result moved.
- The CI comparison of a fresh `klt signoff` run against the committed
  record stays: with no vendored copy left to edit, it is what catches a
  checklist change at a pin bump.

## Alternatives considered

- **Keep the copy plus a drift check against the wheel's bytes.** Rejected
  by the ruling: it reverses vendoring outright rather than policing a
  second copy.
- **Bump the pin and re-vendor the new release's doc.** Out of scope — the
  pin stays 0.8.0, and after this record a bump needs no vendor step at all.

## Consequences

- The repo holds one copy of the checklist, inside the pinned tool. A
  checklist change can only arrive as a pin bump, surfaced by the signoff CI
  comparison instead of a repo-local edit that no release governs.
- The record's `source_doc` now names a path outside this repo; the sha256
  in `source_doc_content_hash` remains the byte-identity check of what was
  graded.
- The `measurements/` evidence that recorded the old `--tiers-doc` command
  line is append-only history and is left as written.
- Nothing else in `manifests/` changes: the block manifest, its evidence
  citations and the item-10 inventory pin (a hash of `attest/item10.json`,
  which did not change) are untouched; only the hygiene hashes the item-10
  envelope re-records for the edited files move, as they must.
