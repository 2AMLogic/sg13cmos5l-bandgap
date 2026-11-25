# Work Log

Chronological record of merged PRs and closed issues, maintained by the Guide
triage agent. Newest first.

### 2026-11-24

- **PR #185**: ci: pin klayout alongside klt in the signoff job
- **PR #182**: attest: measure item 2 regenerated hash by rerunning the generators
- **Issue #184** (closed): Pin klayout for the item-2 fresh-rerun check in signoff.yml
- **Issue #67** (closed): Remove the tautological --regenerated default from attest/make-item2-envelope.py: the item-2 regeneration claim is true by construction

### 2026-11-23

- **PR #183**: layout: keep pnpMPA collector bottom contacts clear of side columns
- **PR #181**: spec: index decision record 0021 and require every record in the README index
- **PR #179**: sim: drop the unread model_files inventory from pdk.json
- **PR #178**: chore: stop vendoring the T1 checklist — the pinned klayout-tools release selects it
- **PR #175**: fix(layout): draw the pnpMPA base tie as real geometry and drop its nSD markers (DR-0022)
- **Issue #180** (closed): spec/README.md's decision-record list omits 0021-remove-vendored-tiers-checklist.md (landed unindexed in #178)
- **Issue #177** (closed): layout(pnpMPA): collector-ring bottom contact row overlaps side columns at corners (20 non-square Cont polygons)
- **Issue #170** (closed): pnpMPA base rings carry zero contacts: the base tie does not exist as drawn (draw_pnpmpa cont_array underflow at w=1u l=2u)
- **Issue #81** (closed): Remove the vendored manifests/design-evidence-tiers.md: byte-identical to the checklist bundled in the pinned klayout-tools wheel
- **Issue #66** (closed): Remove the unread model_files table from sim/pdk.json: fifth copy of the PVT section list, with a host-dependent column

### 2026-11-21

- **PR #174**: docs(layout): add SG13CMOS5L layer numbers section to layout README
- **Issue #172** (closed): Dangling cross-reference: layout/README.md has no "SG13CMOS5L layer numbers" section
- **PR #171**: measure: pnpMPA base-tie probe — ring-free runset recognition succeeds; base rings carry zero contacts (#166)
- **Issue #166** (closed): Scratch probe: does bandgap_top without the ten pnpMPA base-ring nSD shapes derive pnpMPA on the PDK runset and still grade its base tie? (decision record 0018 reopen condition)

### 2026-11-20

- **PR #169**: feat(layout): migrate the ERC supply spec, split ties per well population, commit the clean klt 0.8.0 report
- **Issue #167** (closed): T1 item 11, ERC half: migrate the klt erc supply spec for bandgap_top, declare ties per well population, and commit the report (does not wait on the item-4 LVS report)

### 2026-11-19

- **PR #163**: docs(spec): complete the decision-record index in spec/README.md
- **Issue #162** (closed): spec: spec/README.md's decision-record list names 5 of 16 records — complete it or say it is a highlights list
- **PR #157**: docs: name each closed-loop PSRR bench's raw values in sim/README
- **PR #155**: docs: classify worst-case row in per-corner table as extremum
- **Issue #156** (closed): sim/README.md:423 quotes one bench's raw value for a two-bench comparison
- **Issue #153** (closed): sim/README.md: say whether an extremum row inside a per-corner table is a cell or an extremum before #107 annotates closed-loop-psrr-op

### 2026-11-18

- **PR #152**: docs: restate closed-loop PSRR worst case to conservative rounding at unratified sites
- **PR #149**: ci: add the merge_group trigger to the required-check workflow(s)
- **Issue #148** (closed): Merge queue: add the merge_group trigger to the required-check workflow(s)
- **Issue #135** (closed): post-verdict.sh: the final head.sha read has no timeout, so one hung connection stalls a verdict indefinitely
- **PR #146**: docs: ratify DR-0018 — keep the #240 nSD rings, disclose runset-engine pnpMPA blindness
- **Issue #145** (closed): PDK runset cannot recognise the committed layout's pnpMPA devices: the #240 nSD rings sit in bjt_derivations.lvs's pnp_exclude, so pnp_b derives empty

### 2026-11-17

- **PR #141**: chore(loom): resync installed Loom to v0.19.1306
- **PR #140**: sim: check decision-record numbering for prefix collisions and H1 mismatches
- **Issue #123** (closed): spec: two decision records now claim the number 0016; record-number uniqueness is unguarded after five renumbers
- **PR #138**: spec: scope the vref-mc re-take "only ... differ" claim (issue #124)
- **Issue #124** (closed): spec/target-spec.md: scope the vref-mc re-take "only ... differ" claim (8 ungraded one-LSB values fall outside it)

### 2026-11-16

- **PR #120**: sim: re-take the vref-mc campaign on the wrapped-DUT staging; fix its internal-node probes
- **PR #133**: chore(loom): resync installed Loom to v0.19.1302
- **Issue #115** (closed): Re-take the closed-loop-vref-mc campaign on the wrapped-DUT staging (post-#83/#84 arrangement)

### 2026-11-15

- **PR #131**: test: assert bench.json deck_template and testbench resolve to the same file
- **Issue #119** (closed): sim: no check asserts bench.json's `deck_template` and `testbench` resolve to the same file (both bench suites)
- **PR #128**: fix: sign-aware left boundary in documented-figure literal presence
- **Issue #127** (closed): sim: literal_present accepts a sign-flipped figure (a positive printed literal is satisfied by its negative in prose)
- **PR #125**: fix: admit a sentence-ending period in documented-figure literal presence
- **Issue #121** (closed): sim: boundary-aware literal presence rejects a figure that ends a sentence
- **PR #111**: sim: share one deck fixture across grid benches on an identical supply stimulus
- **PR #118**: fix: checker accounts every decimal, rounds keyed cells to nearest, matches literals boundary-aware
- **PR #117**: test: require the ratified PVT axes on check 8's reference bench
- **PR #102**: chore: drop the ten expired .gitkeep placeholders under the grid benches
- **PR #82**: sim: measure the untrimmed line (3σ) with a controlled Monte Carlo and cite it for T1 item 6
- **Issue #113** (closed): sim: documented-figure coverage summary understates the unverified set, and bound rounding is applied to non-extent keyed_to values
- **Issue #109** (closed): Check 8's reference bench has no presence guard on supply_v / temperature_c
- **Issue #97** (closed): Remove the ten expired .gitkeep placeholders under the five grid benches' evidence directories
- **Issue #31** (closed): T1 item 6 (Monte Carlo): closed-loop vref mismatch MC (N >= 300 per point) as klt yield evidence for the untrimmed-line row
- **PR #112**: docs: state the declared spec-row denominator as eleven, not nine
- **PR #110**: sim: commit the documented-figure checker with claim annotations (cell, count, range, pct_change, extremum)
- **Issue #105** (closed): README.md and manifests/README.md say "four of the nine declared rows" are gaps; the manifest declares eleven
- **Issue #103** (closed): sim: commit the documented-figure checker and extend it to prose counts, percentage summaries and rounding

### 2026-11-14

- **PR #106**: test: guard the whole corners mapping across grid benches (check 8)
- **PR #104**: docs: state committed layout, extraction and silicon status in README
- **PR #98**: sim: attribute the psrr_dc Target miss to the mirror's output conductance against the amplifier's rail tracking
- **Issue #101** (closed): Compare the whole corners mapping in test-grid-benches.sh check 8: supply_v and temperature_c are copied five ways with no guard
- **Issue #94** (closed): README status paragraph says nothing is laid out or extracted, but the layout, DRC and a post-layout extraction are on main
- **Issue #93** (closed): Attribute the PSRR @ DC Target miss: operating-point evidence at the failing 2.97 V and 3.30 V points
- **Issue #90** (closed): Reconcile the two lists of the offline test suite: attest/item10.json misses test-smoke-request.sh, so CI never runs it
- **PR #96**: test: attest test-smoke-request.sh and assert every offline suite is inventoried
- **PR #92**: docs: roadmap as of 2026-11-13
- **Issue #47** (closed): Run sim/smoke/run_smoke.sh once on a toolchain host and diff record keys after runner-lib refactor

### 2026-11-13

- **Issue #87** (closed): Remove the `netlist_source: "extracted"` label from sim/smoke/run_smoke.sh: a hand-written deck declared post-layout
- **PR #89**: sim: drop the false `extracted` provenance label from the smoke request
- **Issue #83** (closed): The decks' `Vsub sub! vss` tie does not reach the DUT: rppd/rhigh bulk nodes are instance-local and held only by rshunt
- **PR #85**: sim: declare `sub!` global so the item-5 decks' Vsub tie reaches the DUT's resistor bulks
- **Issue #80** (closed): Make the item-5 benches runnable on an extracted bandgap_top: .SUBCKT-wrapped DUT and measurements addressable on both legs
- **PR #84**: sim: wrap the staged DUT in .SUBCKT sg13cmos5l_bandgap_top and address bench nodes on both legs
- **Issue #71** (closed): Wire package.json test/check:ci to the four sim/tests suites: the Loom-template stubs report 'No tests configured' and exit 0
- **PR #76**: build: run the sim/tests suites from pnpm test and check:ci
- **PR #79**: sim: commit the item-7 pex extraction and the device inventory that blocks its delta
- **Issue #64** (closed): Remove fetch-era leftovers from the closed-loop vref runner: dead gh gate, scratch copy, stale DUT wording
- **PR #78**: sim: drop the dead gh gate and call the shared pin/stage helpers from the vref probe
- **Issue #61** (closed): Test that the five grid requests' §PVT corner sections agree with each other and with check-model-sections.py REQUIRED
- **PR #77**: test: tie the grid requests' corner sections to the checker's REQUIRED
- **Issue #70** (closed): Remove template-era .gitignore rules for flow/, cocotb, a sim harness and per-corner logs that this repo does not have
- **PR #75**: chore: drop .gitignore rules for a flow, cocotb and sim harness this repo lacks
- **Issue #30** (closed): T1 item 5 (corner verification): 45-point closed-loop benches for the nominal, TC (box and endpoint), PSRR, Iq and startup rows as klt sim envelopes
- **PR #72**: sim: run the five closed-loop PVT grids and cite them for T1 item 5
- **PR #68**: docs(spec): state §PVT section names as verified at the dev pin; record the install-shape hazard
- **PR #65**: sim: drop the vref deck's SPICE title line and record the first closed-loop vref
- **PR #63**: docs(sim): record the PVT corner and mismatch sections as resolved at the pinned PDK revision
- **Issue #62** (closed): Retire the spec PVT caveat: section names are now verified at the dev pin
- **Issue #19** (closed): Record the first closed-loop vref run (sim/closed-loop-vref-pvt/run.sh) on a host with the pinned PDK
- **Issue #15** (closed): Verify the spec's corner and mismatch model sections resolve at the pinned IHP dev revision

### 2026-11-12

- **PR #58**: Bump Repo Skills 0.25.10 -> 0.26.1

### 2026-11-07

- **PR #56**: Bump Repo Skills 0.25.1 -> 0.25.10

### 2026-11-06

- **PR #54**: test: offline exit-code test for check-model-sections.py, attested in item 10
- **Issue #53** (closed): Add an offline test for check-model-sections.py and run it and test-runner-lib.sh in CI

### 2026-11-01

- **PR #51**: Bump Repo Skills 0.24.7 -> 0.25.1

### 2026-10-27

- **PR #46**: refactor(sim): share bench runner gates, envelope parsing and record write
- **PR #44**: feat(layout): commit klt drc reports and meet T1 item 3
- **Issue #37** (closed): Deduplicate sim bench runners: share envelope parsing, tool gates and record writing
- **Issue #28** (closed): T1 item 3 (DRC clean): klt drc on every bandgap cell and the top with the SG13CMOS5L deck coverage disclosed
- **PR #41**: feat(layout): migrate SG13CMOS5L layout generators and GDS for T1 item 2
- **PR #40**: feat(design): migrate SG13CMOS5L cells for T1 item 1 attestation
- **PR #39**: feat: attest T1 item 9 with a bench inventory and committed envelope
- **PR #38**: docs: add README reproduce section and attested T1 item 10 envelope
- **Issue #35** (closed): T1 item 10 (repo hygiene): hygiene inventory and klt signoff --attest 10 envelope
- **Issue #34** (closed): T1 item 9 (testbenches shipped): testbench inventory and klt signoff --attest 9 envelope
- **Issue #27** (closed): T1 item 2 (layout): committed bandgap_top GDS assembled from the amp, core and startup cells

### 2026-10-24

- **PR #22**: feat(sim): accept fleet PDK store marker as revision proof in env.sh
- **Issue #21** (closed): sim/env.sh: accept a PDK-store tree (.pdk-store.json) at the pin

### 2026-10-23

- **PR #18**: feat(sim): closed-loop vref bench against the pinned source netlist
- **Issue #14** (closed): Closed-loop vref bench at the nominal point on the dev PDK pin (sim/closed-loop-vref-pvt)
- **PR #17**: feat(sim): add static checker for PVT model-library sections

### 2026-10-21

- **PR #11**: Bump Repo Skills 0.24.3 -> 0.24.7

### 2026-10-20

- **PR #8**: ci: add klt signoff manifest, T1 checklist, verdict record and workflow
- **Issue #3** (closed): Add the T1 signoff scaffolding: block manifest, vendored checklist and CI (item 10)

### 2026-10-17

- **PR #7**: feat: pin SG13CMOS5L PDK, add refusing env.sh and typ-corner smoke bench
- **Issue #4** (closed): Pin the PDK and commit a smoke simulation (T1 item 9 bring-up)
- **PR #6**: docs(spec): ratify SG13CMOS5L target spec and pin sg13g2-bandgap branch
- **Issue #2** (closed): Draft and ratify the target spec
- **PR #1**: chore(loom): Install Loom 0.19.1181
