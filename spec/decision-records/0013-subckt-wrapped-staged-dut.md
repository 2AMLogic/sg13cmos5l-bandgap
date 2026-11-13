# 0013: Derive a `.SUBCKT`-wrapped DUT at staging time; grade startup on the same nodes

- **Status**: ratified, effective when the PR for issue #80 merges
- **Date**: 2026-11-13
- **Decided by**: Loom Builder agent, issue #80 (Part of #32)

## Context

T1 item 7 needs a `klt pex` schematic-vs-extracted delta per graded row. The
delta is blocked upstream on the curated `sg13cmos5l` deck declaring no bipolar
class, so the three `pnpMPA` devices never extract
([`2AMLogic/klayout-tools#5477`](https://github.com/2AMLogic/klayout-tools/issues/5477),
decision record 0012). `sim/pex-bandgap-top/README.md` named two further gaps
that are **this repo's** work and would stop a delta run even once the bipolars
extract:

1. **The staged DUT was flat.** `design/sg13cmos5l/netlist/bandgap_top.spice`
   is an xschem export whose top block is commented out
   (`**.subckt bandgap_top vdd vss vref` … `**.ends`), and `cm5_stage_dut`
   staged it as-is minus the final `.end` card. `klt extract` output is always
   `.SUBCKT`-wrapped, so `klt pex` fires `flat_dut_mismatch` and skips the
   extracted leg.
2. **The benches addressed internal nodes by name.** The item-5 decks measured
   `v(fb)`, `v(sns1)`, `v(sns2)` and `v(xx3.det)`. Extraction joins those nets
   into `fb|out`, `in_n|sns1`, `in_p|sns2` and `det` and flattens the
   hierarchy, so one `.meas` card cannot address both legs.

Two constraints bound the fix. `attest/item1.json` checks
`design/sg13cmos5l/netlist/bandgap_top.spice` with `klt netlist … --check` and
decision record 0006 holds it byte-for-byte to the pinned source, so the
attested file cannot be hand-edited. And the startup row's three
"self-starting" criteria are ratified on internal nodes
(`sim/closed-loop-startup/bench.json`, decision record 0011), so what they
grade cannot be relaxed for a tooling convenience.

## Decision

**1. The wrapper is derived at staging time, never committed and never edited
into `design/`.** `cm5_stage_dut` (`sim/runner-lib.sh`) makes exactly three
derived changes to the copy it stages under `sim/build/<bench>/`:

- the commented-out top header becomes a live
  `.subckt sg13cmos5l_bandgap_top vdd vref vss`,
- its matching `**.ends` becomes `.ends sg13cmos5l_bandgap_top`,
- the final `.end` card is dropped, so the including deck's is the only one.

The three leaf `.subckt` definitions, every instance line and every parameter
are untouched. `git diff` on `design/sg13cmos5l/netlist/` is empty and
`attest/item1.json` is unchanged, so 0006's byte-for-byte rule and item 1's
`--check` both still hold. The staging step **refuses** (exit 6,
`TOP_BLOCK_UNEXPECTED`) unless it finds exactly one expected header followed by
exactly one `**.ends`: a renamed, reordered, duplicated or missing top block is
a named refusal rather than a silent flat stage.

**2. The cell name and pin order are the EXTRACTED netlist's, not the
schematic export's.** `.subckt sg13cmos5l_bandgap_top vdd vref vss` — note
`vdd vref vss`, which is *not* the export's own `vdd vss vref`. `klt pex`
reuses the bench's positional `X…` line on both legs and fires
`pin_order_mismatch` when the two headers hold the same pins in a different
order; the committed extracted netlist's header is
`.SUBCKT sg13cmos5l_bandgap_top vdd vref vss`
(`sim/pex-bandgap-top/extracted/20261113T123950Z-8422e4d.spice:14`). Both
values live once, in `sim/runner-lib.sh` (`CM5_DUT_SUBCKT`, `CM5_DUT_PINS`);
`sim/tests/test-grid-benches.sh` reads them from there and checks them against
every deck's `Xdut` card **and** against the committed extracted header, so a
drift fails offline instead of at a submitted grid.

**3. All five item-5 decks instantiate it** as
`Xdut vdd vref vss sg13cmos5l_bandgap_top`, immediately after the `.include`.

**4. The startup row's graded criteria do not move.** `det_release_ratio`,
`dvsns_v` and `fb_headroom_v` keep their names, their `limits` and their
`spec_row: startup_self_starting`, and stay graded on the same physical nodes.
Only the node *paths* lengthen by the wrapper's instance prefix:
`v(fb)` → `v(xdut.fb)`, `v(sns1)` → `v(xdut.sns1)`,
`v(sns2)` → `v(xdut.sns2)`, `v(xx3.det)` → `v(xdut.xx3.det)`. The
`vref-pvt` bench's `fb_v`/`sns1_v`/`sns2_v` move the same way; they carry no
`limits` and no `spec_row` and are diagnostic, not graded. **No ratified bound,
row or criterion changes in this record.**

**5. No `.global sub!` card is added.** See "What was measured" below: the
source's `sub!` resistor-bulk nodes were *already* local to each leaf instance
under ngspice, so the wrapper only lengthens them; adding a `.global` card
would newly tie those bulks to `vss` and change the recorded item-5 results.

**6. Records pin what ran as well as what was read.** `source_file_sha256`
still hashes the file **as read** (equal to the pinned source blob);
`staged_dut_sha256` and `staged_dut_subckt` are new fields holding the derived
copy's hash and wrapper cell name.

## What was measured

All local, single-corner `klt sim --backend local` runs at typ / 27 °C /
3.30 V on `ngspice-47` at PDK revision `f7bca326`. **SIMULATED** figures.

**The wrapper is electrically a no-op.** `sim/closed-loop-vref-pvt`'s
measurement set, flat deck vs wrapped deck, identical in every digit reported:

| Measurement | Flat DUT (main) | Wrapped DUT (`Xdut`) |
|---|---|---|
| `vref_v` | 1.19696 V | 1.19696 V |
| `vref_prev_v` | 1.19696 V | 1.19696 V |
| `fb_v` | 2.49741 V | 2.49741 V |
| `sns1_v` | 0.780446 V | 0.780446 V |
| `sns2_v` | 0.780213 V | 0.780213 V |
| `vref_settle_v` | 5.70942e-09 V | 5.70942e-09 V |

`vref_v` also equals the value decision record 0009 records for this corner.

**`sub!` is not an ngspice global, and was already instance-local before the
wrapper.** `!` is an xschem global-net marker; ngspice has no such convention,
and the netlist carries no `.global` card. An `op` + `display` probe lists:

| Deck | Nodes matching `sub` |
|---|---|
| flat (main) | `sub!`, `xx1.sub!`, `xx3.sub!`, `vsub#branch` |
| wrapped | `sub!`, `xdut.xx1.sub!`, `xdut.xx3.sub!`, `vsub#branch` |

So the `rppd`/`rhigh` bulk nodes inside `bandgap_core` and `bandgap_startup`
have **never** been the node `Vsub sub! vss dc 0` drives, on either deck — they
are held only by `.options rshunt=1e9`. The wrapper changes the prefix and
nothing else, which is why the table above is identical. That the bulks are not
actually tied to `vss` is a pre-existing property of the migrated deck, not of
this change, and is **out of scope here**: tying them would alter every
recorded item-5 figure. It is filed separately rather than fixed in passing.

**Both legs load and their pins connect.** The `sim/closed-loop-startup` deck,
unmodified, one corner, with the `.include` pointed at (a) the staged schematic
DUT and (b) `sim/pex-bandgap-top/extracted/20261113T123950Z-8422e4d.spice`:

| | Leg (a) staged schematic | Leg (b) extracted |
|---|---|---|
| unknown-subckt / pin-count / unconnected errors | 0 | **0** |
| transient ran | 1001 points | 1001 points |
| pin-level measurements resolved | `vref_start_v`, `vref_final_v`, `vdd_final_v`, `t_settle_s` | same four |
| internal-node measurements resolved | all four | **none** |
| envelope status | `pass` | `error` |

Leg (b) **is not evidence** and no figure from it is claimed: the netlist is
missing all three `pnpMPA` devices, and it shows — `vref_final_v` comes out at
3.2999 V, i.e. `vref` pinned to the rail with the ΔV_BE core absent. What leg
(b) does establish is exactly the interface claim this record makes: the
wrapper's cell name and pin order bind to the extracted `.SUBCKT` with no
unconnected pin and no unknown subcircuit, and the devices appear under the
instance (`xdut.x$1…`). Its only errors are the four internal-node
measurements (`Error: RHS "v(xdut.sns1)[length(time)-1]" invalid`, and three
like it) — which is gap 2 above, measured rather than asserted, and which is
what makes `klt pex --measure-command` the route for #32 rather than a guess.

The `Unknown model type pspnqs103va` warnings (28 of them) appear identically
on both legs and on main; they are the PDK's NQS variant, which the benches do
not preload, and are unrelated to this change.

## Alternatives considered

- **Re-netlist the top as a `.subckt` from xschem.** Rejected: it changes an
  attested, lineage-pinned file (`attest/item1.json`, decision record 0006) and
  the design is designed once (CLAUDE.md "Scope discipline").
- **Commit a second, wrapped copy of the netlist.** Rejected: two sources of
  truth for the same circuit, and the second would drift silently.
- **Wrap with the schematic export's own `vdd vss vref` order.** Rejected: the
  pins match but the order does not, so `klt pex` fires `pin_order_mismatch`
  and skips the extracted leg — the same outcome as not wrapping at all.
- **Regrade "self-starting" at the three declared pins**, so no measurement
  needs an internal node. Rejected: it changes what a ratified row grades in
  order to suit a tool, which CLAUDE.md forbids; the release of the startup
  cell is not observable at `vref`, `vdd` and `vss`.
- **Alias the extracted net names with `klt pex --tie-net`**, as
  `sim/pex-bandgap-top/README.md` previously suggested. Rejected because it
  does not exist: `--tie-net EXTRACTED_NET=SCHEMATIC_NET` only accepts a net
  listed in the report's `body_bias.unbiased_nets` ("any other name is an
  error") — it is a body-bias tie, not a net-name mapping — and it is absent
  from the 0.8.0 pin's `klt pex --help` altogether. The README's claim is
  struck in this change.
- **Wait for a klt net-alias feature.** Rejected: `--measure-command` is
  present at the 0.8.0 pin and already covers a row whose one `.meas` card
  cannot address both legs.
- **Add `.global sub!`** (the suspected fix when this issue was curated).
  Rejected on measurement: it is not needed, and it would not be neutral —
  it would newly connect the resistor bulks to `vss` and change every recorded
  item-5 figure.

## Consequences

- One deck serves both legs. The repo-side half of the item-7 delta is closed;
  what remains is the upstream bipolar gap (`klayout-tools#5477`) and #32's
  `--measure-command` script, for which `sim/pex-bandgap-top/README.md` now
  carries the per-leg node map.
- `design/` is untouched and `attest/item1.json` is unchanged. The five deck
  templates and two requests are item-9 inventoried, so `attest/item9.json`'s
  envelope, the manifest's item-9 `content_hash` and the signoff record are
  regenerated in the same PR.
- Item-5 evidence is re-taken rather than reasoned about: fresh append-only
  45-point envelopes for all five benches on the batch fleet, each compared
  value-for-value against the envelope it supersedes. The grading each bench
  declares is unchanged, `psrr_dc` included — it still fails its ratified
  Target at the declared 24 of 45 points (`expected_failure` in its
  `bench.json`), which this change neither fixes nor worsens.
- A future re-extraction that renames the top cell or reorders its pins now
  fails `sim/tests/test-grid-benches.sh` offline, instead of surfacing as a
  `pin_order_mismatch` one submitted grid later.
