# pex-bandgap-top — T1 item 7 (post-layout verification)

What T1 item 7 asks for, in the Analog column, is the spec suite **re-run against the
layout-extracted netlist**, and a `klt pex` JSON report — the per-corner, per-spec-row
schematic-vs-extracted delta — is the only evidence `klt signoff` accepts for it.

**That delta is not produced here, and this directory says why with measurements instead of
prose.** The curated `sg13cmos5l` extraction deck declares **no bipolar device class**, so the
three `pnpMPA` devices the bandgap core is built on are not recognised: they are not flagged,
not emitted as placeholders, they are simply **absent** from every netlist `klt extract`
produces for this layout. An extracted leg simulated on that netlist would converge and report
numbers, and every `delta[]` row would be a difference between two different circuits rather
than a parasitic effect. So what is committed is the extraction half plus the device inventory
that establishes the omission.

Nothing in this directory is simulated. Every figure is **layout-derived** — geometry out of
the committed GDS, R/C out of the deck's own coefficients.

| File | Role |
|---|---|
| `pex.json` | The committed request: layout, top cell, deck, declared pin set, the klt pin, and the row set item 7 is accountable for |
| `pex-run.sh` (in `sim/`) | The runner: resolves the pins, runs `klt pex --extract-only` at `pex.json`'s klt version, takes the device inventory, writes all three artifacts append-only |
| `envelopes/<UTC>-<short sha>.json` | The raw `klt pex --format json` envelope. **This is the artifact `manifests/sg13cmos5l-bandgap.json` cites for item 7**; `klt signoff` reads it |
| `extracted/<UTC>-<short sha>.spice` | The extracted netlist that envelope's `extraction.netlist_sha256` names, committed so the inventory below is auditable offline |
| `records/<UTC>-<short sha>.json` | This repo's own record: the pins, the layout and DUT hashes, `extraction.model` and `body_bias` quoted from the envelope, and the device inventory |

Run it:

```bash
source sim/env.sh && sim/pex-run.sh
```

Exit 0 means the extraction ran **and** the device inventory matches. It exits **5** today, on
the inventory, which is the state this directory records.

## The run of record

`20261113T123950Z-8422e4d` — `klt pex --extract-only --deck sg13cmos5l` on
`layout/sg13cmos5l-bandgap_top/sg13cmos5l-bandgap_top.gds`
(`sha256:4e4e4f85fa08…`, the same stream items 2 and 3 cite), top cell
`sg13cmos5l_bandgap_top`, `--pins vdd,vss,vref --rename-declared-pins`, `--pdk
ihp-sg13cmos5l` at the pinned PDK revision `f7bca326…`.

- `klt` **0.8.0** (`uvx --from "klayout-tools==0.8.0"`, the same pin
  `manifests/README.md` grades `klt signoff` at), `klayout` 0.30.13, deck content hash
  `sha256:5a43b8eb0e1a…` — the same deck revision `layout/README.md` records for DRC.
- `status: not_checked`, `measurement.mode: "extract-only"`, `delta: []`, exit 4 — by design
  for this mode (klayout-tools#3739): there is no measurement leg to pass or fail.
- `extraction`: **17 devices, 13 nets**, 66 parasitic resistor cards and 13 capacitor cards.
  `parasitic_integrity`: 13 nets checked, **0** with findings — no open net, island, orphan
  node, suspicious resistor, short candidate or capacitance mismatch.
- `body_bias`: **`"biased"`**, `unbiased_device_count: 0`, no unbiased PMOS body net. Item 7's
  own note requires a claim citing it to read this field and say whether the numbers were taken
  on a properly-biased netlist: on this netlist every device body has a DC path, so the
  body-bias condition that would make a resimulation *physically wrong* is **not** present
  here. The gap below is a different one.
- `extraction.model`, quoted into the record verbatim because item 7 names it as the
  machine-checkable statement of what the lumped-RC model accounts for: capacitance is
  net-to-ground area/perimeter plus net-to-net **vertical-overlap** coupling; lateral
  (same-layer) coupling only for a net pair naming a declared `--critical-net` (none declared
  here); resistance is a **single lumped series R per net, star-distributed** across that net's
  device terminals, not a distributed RC ladder; **quasi-static** — one frequency-independent R
  and C per net, no skin effect, no transmission-line behaviour.

## The device inventory: the extraction is complete except for the bipolars

`sim/tools/pex_device_inventory.py` tallies the leaf devices each side instantiates, per
model, expanding the schematic export's hierarchy **per physical instance** (so `m=8` counts
8 units) the way a flat extraction already counts them. It needs only the two committed
netlists: no PDK, no simulator, no klt, no network.

```bash
python3 -I sim/tools/pex_device_inventory.py \
    --schematic design/sg13cmos5l/netlist/bandgap_top.spice \
    --extracted sim/pex-bandgap-top/extracted/20261113T123950Z-8422e4d.spice \
    --extracted-top sg13cmos5l_bandgap_top
```

| Model | Schematic DUT (cards / units) | Extracted (cards / units) |
|---|---|---|
| `sg13_hv_pmos` | 8 / 8 | 8 / 8 |
| `sg13_hv_nmos` | 6 / 6 | 6 / 6 |
| `rppd` | 2 / 2 | 2 / 2 |
| `rhigh` | 1 / 1 | 1 / 1 |
| **`pnpMPA`** | **3 / 10** | **0 / 0** |
| **total** | **20 / 27** | **17 / 17** |

`difference.status: "mismatch"`, `kind: "model_set"`, `schematic_only: {pnpMPA: 3 cards,
10 units}`, `extracted_only: {}`. Every device the deck declares a class for extracts
**card-for-card and unit-for-unit**, including both poly resistor flavours — so the extraction
is not broken and the pin resolution is not the problem. The entire divergence is the bipolar,
which is what the core's ΔV_BE reference *is*.

The exit code carries the verdict: **0** = the multisets agree, **1** = they differ, **2** =
usage. `sim/tests/test-pex-device-inventory.sh` covers the contract on fixtures **and
re-derives this record's own inventory** from the two netlists it names, so a hand-edited
record, a swapped netlist, or a design change that adds or drops a device without a fresh run
fails offline rather than being believed.

## Why the deck cannot see the bipolar, and what would be needed

`klt deck devices --deck sg13cmos5l` declares `nfet`, `pfet`, `cap_cmomi`, `cap_cmomf`,
`rsil`, `rppd`, `rhigh` — and no bipolar class, at the pinned deck revision and on
klayout-tools `main`. The upstream position is settled and documented, not an oversight:

- klayout-tools#4927 (**closed, completed**) established that the curated `sg13cmos5l` deck
  extracts **zero** devices from the PDK's own `pnpMPA` testcase, and that the supported path
  for recognising it is `klt lvs` with `"engine": "klayout-runset"` in its request, against
  the install's `libs.tech/klayout/tech/lvs/sg13cmos5l.lvs` (measured there: `status: match`, 2 of 2
  devices). Porting the PDK's Ruby `CustomBJTExtractor` into the curated deck was ruled out of
  scope, as it was for the sibling family's HBTs (#1232).
- **`klt extract` and `klt pex` have no engine selector at all** — no flag, and no request
  field (`klt extract` takes none; `klt pex` drives extraction through `--deck`). They extract
  against a curated deck only, so the runset route that gets LVS to `match` cannot produce an extracted *netlist* at
  all. There is no flag, deck option or `--device-model` mapping that closes this:
  `--device-model` binds a **recognised** bipolar class to a PDK subcircuit, and there is no
  recognised class here to bind.

Filed as generic tool friction under this repo's friction protocol:

- [`2AMLogic/klayout-tools#5477`](https://github.com/2AMLogic/klayout-tools/issues/5477) — an
  extraction whose deck has no class for a drawn device family omits it with **no coverage
  disclosure** (`klt drc` publishes `coverage.rules_skipped`; extraction publishes no
  counterpart), and there is **no runset-engine alternative** for `extract`/`pex`.
- [`2AMLogic/klayout-tools#5479`](https://github.com/2AMLogic/klayout-tools/issues/5479) — an
  `--extract-only` citation renders item 7 `unmet` / `check_failed` with `citation: null`,
  indistinguishable from a delta run that ran and failed.

## What this does and does not establish

**Does**: that the committed stream extracts, under the pinned deck, into a parasitic-annotated
netlist with a clean `parasitic_integrity` result and fully biased device bodies; what that
netlist's lumped-RC model accounts for; and that it is missing exactly the three `pnpMPA`
devices and nothing else.

**Does not**: any post-layout figure for any spec row. All seven rows the five item-5 benches
grade — `vref_nominal`, `tc_endpoint`, `tc_box`, `psrr_dc`, `iq`, `startup_self_starting`,
`startup_time` — are `insufficient-evidence` for item 7. Their item-5 (schematic) evidence is
untouched, and no ratified bound is relaxed:
[`spec/decision-records/0012`](../../spec/decision-records/0012-post-layout-pex-extraction-gap.md)
records the decision.

`klt signoff` grades item 7 **`unmet` / `check_failed`** on this citation — which is the honest
verdict, and the one the committed record of
`manifests/sg13cmos5l-bandgap.signoff.json` carries.

## Two further repo-side gaps a delta run would hit even with the bipolars

Worth stating, because they are *this repo's* work rather than the tool's, and they are not
blockers today only because the bipolar gap is upstream of them:

1. **The migrated DUT is flat.** `design/sg13cmos5l/netlist/bandgap_top.spice` is an xschem
   export whose top `.subckt` line is commented out, and `klt extract` output is always
   `.SUBCKT`-wrapped — `klt pex` would fire `flat_dut_mismatch` and skip the extracted leg.
   Fixable here by wrapping the DUT in a `.SUBCKT sg13cmos5l_bandgap_top vdd vss vref` and
   instantiating it from the bench deck, which the `--pins`/`--rename-declared-pins` settings
   in `pex.json` already make interface-compatible.
2. **The benches probe internal nodes by name.** The item-5 decks measure `v(fb)`, `v(sns1)`,
   `v(sns2)` and `v(xx3.det)`; extraction joins those nets into `fb|out`, `in_n|sns1`,
   `in_p|sns2` and flattens the hierarchy away, so one `.meas` card cannot address both legs.
   A delta run needs benches whose graded measurements are taken at the three declared pins
   only, or a net-name mapping (`klt pex --tie-net`, which the 0.8.0 pin does not carry).
