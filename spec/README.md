# spec

Ratified specification, decision records and the porting plan for this block.

| File | What it is |
|---|---|
| [`porting-plan.md`](porting-plan.md) | Sibling commits read (full SHAs), what is inherited, what is re-derived, open questions |
| [`target-spec.md`](target-spec.md) | The target table: every row with target, fallback, stretch, binding conditions, planned testbench and evidence status |
| [`decision-records/`](decision-records/) | One record per spec change, numbered `NNNN-<slug>.md` |

Decision records:

- [`0001-target-spec-ratification.md`](decision-records/0001-target-spec-ratification.md): ratifies the table in `target-spec.md`
- [`0002-sg13g2-bandgap-branch-reuse.md`](decision-records/0002-sg13g2-bandgap-branch-reuse.md): the SG13CMOS5L branch is pinned in `/reuse.lock.json`, not migrated
- [`0006-migrate-sg13cmos5l-design-sources.md`](decision-records/0006-migrate-sg13cmos5l-design-sources.md): migrates the SG13CMOS5L design sources byte-for-byte from the pinned `sg13g2-bandgap` commit so T1 item 1 can be attested (amends 0002 for these files only)
- [`0007-migrate-sg13cmos5l-layout.md`](decision-records/0007-migrate-sg13cmos5l-layout.md): migrates the SG13CMOS5L layout generators and GDS the same way so T1 item 2 can be graded (sibling of 0006)
- [`0008-shared-sim-runner-helpers.md`](decision-records/0008-shared-sim-runner-helpers.md): the sim bench runners share one runner skeleton (`sim/runner-lib.sh`, `sim/tools/cm5_record.py`); the record shapes are left alone
- [`0009-output-reference-nominal-first-measured.md`](decision-records/0009-output-reference-nominal-first-measured.md): records the first measured closed-loop `vref` and moves the "Output reference, nominal" row off `target-only`
- [`0010-retire-pvt-section-name-caveat.md`](decision-records/0010-retire-pvt-section-name-caveat.md): §PVT's section names are verified at the `dev` pin; records the git-checkout vs PDK-store install difference and its v0.3.0 sibling-tree hazard
- [`0011-corner-verification-pvt-grids.md`](decision-records/0011-corner-verification-pvt-grids.md): the five closed-loop PVT-grid benches that carry T1 item 5, what each measured, and the ratified **Target** column as the bound every grid is graded at — on which the PSRR @ DC row fails 24 of its 45 points
- [`0012-post-layout-pex-extraction-gap.md`](decision-records/0012-post-layout-pex-extraction-gap.md): post-layout verification — the extraction is committed as item-7 evidence, but the schematic-vs-extracted delta is not producible (the curated deck declares no bipolar class, so the `pnpMPA` devices do not extract)
- [`0013-subckt-wrapped-staged-dut.md`](decision-records/0013-subckt-wrapped-staged-dut.md): a `.SUBCKT`-wrapped DUT is derived at staging time; startup is graded on the same nodes
- [`0014-substrate-net-global.md`](decision-records/0014-substrate-net-global.md): declares `sub!` global in the item-5 deck fixtures so the `Vsub` tie reaches the DUT (supersedes item 5 of 0013)
- [`0015-psrr-dc-attribution.md`](decision-records/0015-psrr-dc-attribution.md): what limits PSRR @ DC — the mirror's output conductance against the amplifier's rail tracking, with a bench that measures it
- [`0016-statistical-mc-sections-and-window.md`](decision-records/0016-statistical-mc-sections-and-window.md): the statistical Monte Carlo bench — which model sections, which window, and what the untrimmed-line row may be read as
- [`0017-shared-deck-fixtures.md`](decision-records/0017-shared-deck-fixtures.md): grid benches on an identical supply stimulus share one deck fixture (amends 0011 §6 and 0014's Decision §1)
- [`0018-pdk-runset-pnpmpa-nsd-ring.md`](decision-records/0018-pdk-runset-pnpmpa-nsd-ring.md): the `nSD` rings stay — every runset-engine result on this stream discloses that the PDK runset derives no `pnpMPA`
- [`0020-migrate-erc-supply-spec.md`](decision-records/0020-migrate-erc-supply-spec.md): migrates the ERC supply spec from the pinned source and splits its `ties[]` per well population — the ten baseline `erc.missing_tie` findings were a spec declaration gap, and the klt 0.8.0 rerun is `erc_status: "clean"` (amends 0002 for this file only)

Rules: spec changes go through a decision record; a ratified record is
superseded, never rewritten; no row is relaxed to make a result pass.
