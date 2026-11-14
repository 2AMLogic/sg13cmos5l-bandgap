# design

Design sources for the SG13CMOS5L bandgap. `xschemrc` and `sg13cmos5l/`
(`*.sch`, `*.sym`, `netlist/*.spice`) are migrated unedited from
`2AMLogic/sg13g2-bandgap` at the commit named in
[`spec/decision-records/0006-migrate-sg13cmos5l-design-sources.md`](../spec/decision-records/0006-migrate-sg13cmos5l-design-sources.md);
`reuse.lock.json` lists them under `mode: "migrate"`. Everything else
(including `sg13cmos5l/README.md`) stays pinned there. Do not edit migrated
files without a decision record.

## Netlist freshness (T1 item 1)

`check-netlist-freshness.sh` is the gate T1 item 1 is attested on
([`0015`](../spec/decision-records/0015-item1-netlist-freshness-gate.md)). Run it
from anywhere in the repo, on a host carrying xschem 3.4.7 and the PDK revision
`sim/pdk.json` pins (`sim/env.sh` resolves it and refuses any other revision):

```bash
design/check-netlist-freshness.sh                 # all four cells
design/check-netlist-freshness.sh bandgap_core    # one cell
```

For each cell it re-exports the schematic with `klt netlist` — never a raw
`xschem`, which initialises its GUI, writes a plausible-looking netlist and then
hangs in the Tk event loop — and compares the result against the committed
netlist through `tools/netlist_pin_delta.py`. Exit 0 fresh, 1 drifted, 2 setup
error.

The comparison is **normalized, not a byte compare**, and tolerates exactly two
differences, neither of them a design change:

- xschem's `** sch_path:` / `** sym_path:` provenance comments (they carry the
  generating checkout's absolute path) and `klt netlist`'s own
  `** klt-netlist-inputs:` line;
- one ` mm_ok=1` token per `sg13_hv_pmos` / `sg13_hv_nmos` / `rppd` / `rhigh`
  instance card. The committed netlists were exported at the archived PDK pin
  `607e18d4`, which did not emit it; this repo pins `f7bca32694fe`, which does.
  `sg13g2-bandgap` owns these cells and ratified keeping the archived-pin bytes
  (its #405/#406), with regeneration deferred to its #322.

Everything else — device cards, sizes, nets, multipliers, `.subckt` port lists,
`*.iopin` lines, blank lines, any other comment — is compared verbatim.
`mm_ok` at any other value, or on any other device model, is drift.
`tests/test-netlist-pin-delta.sh` holds the negative controls (bash + python3
only, so CI runs it on every push).

A `DRIFT` result is a **design-source finding**, not a tolerance to widen: these
cells belong to `sg13g2-bandgap`, so file it there.

## Running xschem by hand

`xschemrc` puts the invoking directory first on the xschem library path, so
schematics must be opened from the directory that holds them — `cd
design/sg13cmos5l` for this PDK variant. Opening one from `design/` instead
resolves the identically-named SG13G2 symbols and silently produces a netlist
built from the wrong PDK's devices.
