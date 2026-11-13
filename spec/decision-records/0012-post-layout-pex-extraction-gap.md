# 0012: Post-layout verification — the extraction is committed, the delta is not producible

- **Status**: ratified, effective when the PR for issue #32 merges
- **Date**: 2026-11-13
- **Decided by**: Loom Builder agent, issue #32

## Context

T1 item 7 (*Post-layout verification*) asks, in the Analog column, for the spec suite re-run
against the layout-extracted netlist, and `klt signoff` accepts **only** a `klt pex` report for
it — the per-corner, per-spec-row schematic-vs-extracted delta. Before this change,
`manifests/sg13cmos5l-bandgap.signoff.json` graded item 7 `unmet` / `no_evidence`: there was no
layout on `main` when `spec/target-spec.md` was ratified, and §Signoff named
klayout-tools#3739 (`klt pex` needed a testbench or measure command to produce an
extraction-only report) as the gate.

Both of its declared dependencies have since landed. Issue #27 committed
`layout/sg13cmos5l-bandgap_top/sg13cmos5l-bandgap_top.gds`, DRC clean under the curated
`sg13cmos5l` deck. Issue #30 committed the five PVT-grid benches that carry item 5
([`0011`](0011-corner-verification-pvt-grids.md)), whose decks already follow the convention
`klt pex` needs — each `.include`s the schematic DUT, and each request carries
`netlist_source: schematic`, so the extracted leg would re-point that one line.
klayout-tools#3739 is closed, completed, and shipped in the `klt` 0.8.0 pin this repo already
grades against. So nothing procedural stood in the way of running the delta.

**What stands in the way is the extraction deck's device coverage, and it is measured rather
than assumed.** `klt deck devices --deck sg13cmos5l` declares `nfet`, `pfet`, `cap_cmomi`,
`cap_cmomf`, `rsil`, `rppd` and `rhigh` — and no bipolar class, both at the pinned deck
revision (`sha256:5a43b8eb0e1a…`, the revision `layout/README.md` records for DRC) and on
klayout-tools `main`. Extraction of the committed top stream therefore yields **17 devices**
where the design instantiates **20 cards / 27 units**; the difference is exactly the three
`pnpMPA` devices, 10 unit instances, and nothing else. Every MOS and both poly-resistor
flavours extract card-for-card and unit-for-unit. `sim/tools/pex_device_inventory.py` derives
that from the two committed netlists alone, and `sim/pex-bandgap-top/records/` carries its
report.

The core's reference *is* those bipolars: a ΔV_BE between branches of unequal emitter count.
An extracted netlist without them is not a degraded bandgap, it is a different circuit — and
per `docs/cli/pex.md` an extracted leg on it "converges and reports numbers". The in-tool
signal, `model_mismatch`, is "reported, not enforced" and is only computed when a measurement
leg runs, so a `delta[]` built on that netlist would look like a post-layout result and would
be a comparison of two circuits.

The upstream position on recognising the device is settled, not pending. klayout-tools#4927
(closed, completed) established that the curated deck extracts **zero** devices from the PDK's
own `pnpMPA` testcase, that the PDK's own runset *does* recognise it, and that
`klt lvs` with `"engine": "klayout-runset"` in its request is the supported path — while
porting the PDK's Ruby
`CustomBJTExtractor` into the curated deck is out of scope (as for the sibling family's HBTs,
#1232). **`klt extract` and `klt pex` have no engine selector at all** — no flag, and no
request field (`klt extract` takes none, and `klt pex` drives extraction through `--deck`):
they extract against a curated deck only. `--device-model` does not help either — it binds a *recognised* bipolar class to
a PDK subcircuit, and there is no recognised class here to bind.

## Decision

### 1. Item 7's committed evidence is the extraction, not a delta

`sim/pex-bandgap-top/` carries one `klt pex --extract-only` run of the committed top GDS at the
`klt` 0.8.0 pin: the envelope (cited by `manifests/sg13cmos5l-bandgap.json` for item 7), the
extracted netlist that envelope hashes, and this repo's record quoting `extraction.model` and
`body_bias` verbatim and embedding the device inventory. `sim/pex-run.sh` reproduces it;
`sim/pex-bandgap-top/pex.json` is the committed request.

### 2. No `delta[]` is manufactured, and no spec row is graded from this

All seven rows the item-5 benches grade — `vref_nominal`, `tc_endpoint`, `tc_box`, `psrr_dc`,
`iq`, `startup_self_starting`, `startup_time` — are **`insufficient-evidence` for item 7**.
`pex.json` declares that row set so the accountability is visible in the artifact, not only
here. Their item-5 (schematic) evidence and every ratified bound are untouched; nothing in
`spec/target-spec.md`'s Target, Fallback or Stretch columns is edited, and no row's status is
upgraded on the strength of this run.

### 3. The 45-point grids are not run against the extracted netlist

Not a capacity decision and not a narrowing for convenience: 450 fleet units would produce
seven rows of numbers from a circuit with no bipolars, each of which would then have to be
retracted. The run that *would* be evidence is the one blocked upstream.

### 4. `klt signoff` grading item 7 `unmet` / `check_failed` is the intended outcome

Item 7 is cited and graded, not left `no_evidence`; the grader reports that a `pex` artifact
exists and does not establish the item. This follows the same rule
[`0011`](0011-corner-verification-pvt-grids.md) §2 applied to `psrr_dc`: failing or incomplete
evidence is cited and reported, never withheld to keep a verdict clean.

### 5. The tool gaps are filed, and §Signoff's gap list is brought current

- [`klayout-tools#5477`](https://github.com/2AMLogic/klayout-tools/issues/5477): an extraction
  whose deck declares no class for a drawn device family omits it with no coverage disclosure
  (`klt drc` publishes `coverage.rules_skipped`; extraction publishes no counterpart), and
  `extract`/`pex` have no runset-engine alternative. This is the issue `spec/target-spec.md`
  §Signoff's standing note — "Bipolar (`pnpMPA`) recognition in the CMOS5L LVS deck is a gap
  the source documents but this plan did not find a matching open klayout-tools issue for; it
  is filed or confirmed when the first layout issue runs LVS" — is now discharged by, together
  with the already-closed #4927 that confirmed the LVS half.
- [`klayout-tools#5479`](https://github.com/2AMLogic/klayout-tools/issues/5479): an
  `--extract-only` citation renders item 7 `unmet` / `check_failed` with `citation: null`,
  indistinguishable from a delta run that ran and failed.
- §Signoff's list is updated for evidence references only: #3094 and #3739 are marked closed,
  #4927 and the two new issues are added. No row and no bound changes.

## Alternatives considered

**Run the five 45-point grids against the extracted netlist anyway and report the deltas.**
Rejected. It is the one outcome `CLAUDE.md` forbids by name: numbers from a circuit missing its
first-order device, presented as post-layout evidence. The `plausible_range` guards on `vref_v`
and `iq_a` would catch the degenerate solution at most points, so the artifact would be a grid
of failures attributed to the layout when the cause is the extractor.

**Hand-patch the extracted netlist to add the three `pnpMPA` cards.** Rejected. That is
"substitute a schematic device", and the result would not be a `klt pex` report at all —
`klt pex` extracts, picks both netlists and computes every delta row itself, with no hook
between extraction and simulation. A hybrid netlist would also be unreproducible by the tool
that is supposed to be the evidence.

**Grade item 7 against a cell that contains no bipolar** (e.g. `bandgap_amp` alone).
Rejected. Item 7 is about the block, and `spec/target-spec.md`'s rows are the assembled
`bandgap_top`'s. A delta on a sub-cell would be real evidence about that sub-cell and no
evidence for any ratified row; citing it under item 7 would be the narrowing
[`0011`](0011-corner-verification-pvt-grids.md) §5 already rejected for item 5's row set.

**Leave item 7 `no_evidence` and write the finding up in prose only.** Rejected. The extraction
*did* run and it does establish things worth citing — a clean `parasitic_integrity` result,
fully biased device bodies, and the lumped-RC model's own scope statement — and the device
inventory is a measurement, not an opinion. `no_evidence` would also lose the single most
useful fact for whoever revisits this: that the extraction is correct for everything the deck
declares, so only the bipolar class is missing.

**Wait for the tool and ship nothing.** Rejected. The gap is upstream and has been ruled out of
scope once already (#4927, #1232); an unbounded wait would leave `main` with no statement of
where item 7 stands, no reproducible runner, and no filed friction — which is the canary's
actual job.

## Consequences

- `manifests/sg13cmos5l-bandgap.json` gains an `evidence.7` citation; item 7 moves from
  `unmet` / `no_evidence` to `unmet` / `check_failed` in
  `manifests/sg13cmos5l-bandgap.signoff.json`. `t1_met_count` is unchanged at 4.
- `sim/pex-bandgap-top/` is append-only evidence on the same terms as the grid benches:
  `cm5_record_path` refuses an existing record and `write_record` opens with `"x"`, and
  `sim/pex-run.sh` refuses an existing envelope or extracted netlist.
- `sim/tests/test-pex-device-inventory.sh` is inventoried under T1 item 10, so CI re-derives
  the committed record's device inventory from the netlists it names on every run. A design
  change that adds or removes a device, or a swapped extracted netlist, fails there.
- Item 7 becomes producible, without any change to this decision, the moment an extracted
  netlist can contain the bipolars (klayout-tools#5477, or any successor that gives
  `extract`/`pex` the runset path #4927 gave `klt lvs`). The two repo-side gaps that a delta
  run would then hit — the flat schematic DUT, and the benches' internal-node probes — are
  stated in `sim/pex-bandgap-top/README.md` and are this repo's work, not the tool's.
- #33 (the characterization report) aggregates item 7 as `insufficient-evidence` for all seven
  rows, with this record and the committed envelope as the reference.
- Nothing here bears on #29 (LVS, item 4). Item 7 is graded on the `klt pex` report, not on an
  LVS match, and the runset engine #4927 documents is an LVS-side answer that does not reach
  extraction.
