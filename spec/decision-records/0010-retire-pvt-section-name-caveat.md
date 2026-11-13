# 0010: Retire §PVT's "not verified at the `dev` pin" caveat; record the checkout-vs-store install difference

- **Status**: ratified, effective when the PR for issue #62 merges
- **Date**: 2026-11-13
- **Decided by**: Loom Builder agent, issue #62

## Context

`spec/target-spec.md` §PVT named the corner and mismatch sections of
`cornerPNP.lib`, `cornerMOShv.lib` and `cornerRES.lib`, then qualified them:
the names were "those the source used on its historical pin", they were
"**not verified at the `dev` pin**" with issue #4 owning the confirmation, and
the `stat` and mismatch names were "the part most likely to change".

Issue #15 (merged as PR #63) closed that question. At the `dev` pin
`f7bca32694fe3d58be0cc7d9df4b9f5db7161a14`,
`source sim/env.sh && python3 -I sim/tools/check-model-sections.py` exits 0
with **12/12 required sections found, 0 problems**; every name §PVT writes
resolves verbatim, so there is no rename. The run, its negative control (the
same `cornerPNP.lib` with its `.LIB stat` block deleted exits 1 with 11/12)
and the pin are recorded in `sim/README.md` § "Model section check" and in
`sim/pdk.json` `model_files_verification`. The paragraph therefore contradicted
this repo's own evidence, and made the PVT and Monte Carlo rows downstream
(#30, #31) read as less grounded than they are.

The same paragraph's symlink sentence was true of only one of the two ways the
PDK is installed, and the distinction turned out to be load-bearing. A raw
combined IHP-Open-PDK git checkout carries the shared `sg13g2_*` MOS and
resistor files as relative symlinks into `../ihp-sg13g2` (`sim/pdk.json`
`variant_of_checkout`), which is why an `ihp-sg13cmos5l`-only install cannot
resolve them. The fleet PDK store bundle instead materializes them as real
files inside `ihp-sg13cmos5l/`, and it must: the store's sibling `ihp-sg13g2`
tree is pinned at **v0.3.0, not at this `dev` commit**, and `cornerRES.lib`,
`sg13g2_moshv_mod.lib` and `resistors_mod.lib` differ in content between the
two trees. Live symlinks on a store-provisioned host would silently resolve
the SG13CMOS5L models to v0.3.0 content — a wrong-model hazard the spec did
not warn about.

Record [`0009`](0009-output-reference-nominal-first-measured.md) explicitly
left this edit alone ("Also update §PVT's 'not verified at the `dev` pin'
note… Rejected as out of scope: issue #15 owns that question"), and #15's
curated scope in turn put `spec/target-spec.md` out of bounds. This record
closes that loop.

## Decision

Rewrite the one §PVT prose paragraph that followed the model-file mapping
table, in three parts:

1. **Verified, with its evidence named.** The section names in the table are
   verified at the pin, citing the pin, the tool
   (`sim/tools/check-model-sections.py`), the date of the run (2026-11-13,
   issue #15) and where the record lives (`sim/README.md` § "Model section
   check", `sim/pdk.json` `model_files_verification`). The spec cites the
   evidence by path and does not copy the checker's output.
2. **Install-shape caveat.** The symlink statement is qualified as describing a
   raw combined git checkout; a fleet PDK store bundle materializes the shared
   files as real files, with the v0.3.0 sibling-tree hazard stated. The
   "an `ihp-sg13cmos5l`-only install cannot resolve them" consequence is kept
   for the git-checkout case.
3. **The mismatch choice stays open.** The mismatch candidates all exist at the
   pin and are listed; which of them the Monte Carlo benches use is a bench
   decision belonging to #31, not settled here. The OSDI list is kept, with the
   two objects the one bench that has run at the pin actually preloads
   (`psp103.osdi`, `r3_cmc.osdi`, record `0009`) distinguished from the two
   that are built but unexercised.

**No ratified row changes.** No parameter, target, fallback, stretch or binding
condition is touched, and the §PVT axis and model-file mapping tables are
byte-identical before and after. This record does **not** supersede
[`0001`](0001-target-spec-ratification.md); it records a change to the spec's
prose about evidence status, which is exactly what `0001`'s "a measured figure
recorded against a row is evidence, never a newly ratified target number"
rule contemplates.

## Alternatives considered

- **Fold the spec edit into PR #63 (issue #15).** Rejected: that PR's curated
  scope excluded `spec/target-spec.md` on purpose, and it was already in
  review. Deferring the edit to this record keeps the evidence commit and the
  spec commit separately reviewable.
- **Delete the caveat without a decision record.** Rejected: CLAUDE.md
  requires a decision record for every spec change, and `sim/README.md`'s
  finding ("no rename, and the spec text needs no decision record") was a
  statement about the *section names* not needing a record, not a licence to
  edit the ratified spec unrecorded.
- **Also decide the Monte Carlo mismatch sections here.** Rejected: choosing
  between `mos_tt_stat` / `mos_*_mismatch` and `res_stat` / `res_*_mismatch`
  is a bench-design decision that belongs to #31, and the checker reports them
  as informational for that reason.
- **Drop the symlink sentence entirely now that the store ships real files.**
  Rejected: a raw combined git checkout is still a supported install (CLAUDE.md
  tells readers to install inside one), and dropping the sentence would also
  drop the v0.3.0 hazard that makes the store's materialization necessary.
- **State the OSDI names as verified too.** Rejected: the checker covers
  `.lib` sections only. The record names the two objects a passing bench
  actually preloaded and leaves the other two described as built but
  unexercised.

## Consequences

- §PVT no longer defers its section names to #4, and a reader of the PVT or
  Monte Carlo rows now sees the v0.3.0 sibling-tree hazard where it bites.
- The claim is re-establishable, not copied: `source sim/env.sh && python3 -I
  sim/tools/check-model-sections.py` was re-run at this PR's head on
  2026-11-13 on the fleet PDK store (`PDK_ROOT=~/share/pdk`) and again printed
  `12/12 required sections found; 0 problem(s)`, exit 0.
- `bash sim/tests/test-model-sections.sh` (offline, fake models tree) still
  passes; the checker's own required-section list is untouched by this change.
- The mismatch-section decision stays owned by #31, and a future record that
  makes it supersedes this one's third part only.
- Nothing in `sim/` changes: `sim/pdk.json`, `sim/README.md`, `sim/env.sh` and
  `sim/tools/check-model-sections.py` are untouched append-only evidence here.
- `spec/target-spec.md` is an inventoried hygiene file of T1 item 10, so
  `evidence/item10.json` is regenerated in the same PR (one `content_hash`
  field), exactly as record `0009`'s PR had to. `attest/item10.json` is
  unchanged, and the manifest cites the inventory hash, so
  `manifests/sg13cmos5l-bandgap.signoff.json` stays byte-identical —
  re-checked with the pinned `klayout-tools==0.8.0` before this PR was opened.
