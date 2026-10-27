# 0006: Migrate the SG13CMOS5L design sources so T1 item 1 can be attested

- **Status**: ratified, effective when the PR for issue #26 merges
- **Date**: 2026-10-27
- **Decided by**: Loom Builder agent, issue #26 (amends 0002 for these files only)

## Context

Decision record 0002 pins `design/sg13cmos5l/` in `2AMLogic/sg13g2-bandgap`
and copies nothing. `klt signoff --attest 1` (first released in
klayout-tools 0.8.0) binds only repo-relative, existing, non-symlink files
inside the git repository that holds the inventory; it has no form for a
source held at a pinned external commit. T1 item 1 (design sources) therefore
cannot be graded while the cells stay external. 0002 anticipated this: a cell
that must move migrates under a new record naming the commit.

## Decision

Migrate the files below from `2AMLogic/sg13g2-bandgap` at
`52535387e6ccf0a89f6490901a9abb2b78144176`, byte for byte, unedited.
`design/xschemrc` is included because `klt netlist` cannot resolve the PDK
and sibling symbols without it (`klt netlist --rcfile ../xschemrc`); the
source reads `design/xschemrc` for that.

| Path | blob SHA-1 (= source tree entry) | SHA-256 (first 12) |
|---|---|---|
| `design/xschemrc` | `732e6cb39ad4` | `2db904d04cc8` |
| `design/sg13cmos5l/bandgap_amp.sch` | `963031c39593` | `db2a7050ebe3` |
| `design/sg13cmos5l/bandgap_amp.sym` | `1ba34bf5b920` | `b5af19a92554` |
| `design/sg13cmos5l/bandgap_core.sch` | `6d99e78a1d39` | `66a996151b8f` |
| `design/sg13cmos5l/bandgap_core.sym` | `f019ad18c770` | `c7916c2f07bd` |
| `design/sg13cmos5l/bandgap_startup.sch` | `e807585b3f31` | `8c3d6a723dc6` |
| `design/sg13cmos5l/bandgap_startup.sym` | `d6597dbec58d` | `b028d72edc62` |
| `design/sg13cmos5l/bandgap_top.sch` | `d4ea6ed19709` | `423b9d5c4451` |
| `design/sg13cmos5l/netlist/bandgap_amp.spice` | `a4242151900f` | `5b5013faa035` |
| `design/sg13cmos5l/netlist/bandgap_core.spice` | `224ef6da1345` | `548b7683c744` |
| `design/sg13cmos5l/netlist/bandgap_startup.spice` | `3226292a604b` | `69ad3209df7f` |
| `design/sg13cmos5l/netlist/bandgap_top.spice` | `792c17d2a003` | `a29624d3bbcc` |

Each blob SHA-1 was checked with `git hash-object` against the source tree
listing at that commit. The source has no `bandgap_top.sym`.

**Stays pinned** (read at the commit above, per 0002): everything else in
`reuse.lock.json`, including `design/sg13cmos5l/README.md`, the `sim/` and
`layout/` paths, and the porting plan and records. The commit pin is
unchanged; no bump.

`reuse.lock.json` gains a `mode: "migrate"` entry listing the moved paths,
and `design/sg13cmos5l/` is replaced in the pinned list by its remaining
file, `README.md`. `sim/closed-loop-vref-pvt/run.sh` reads the in-repo
`bandgap_top.spice` (identical bytes) instead of fetching it.

## Alternatives considered

- **Attest a vendored copy or submodule.** Rejected: no benefit over a plain
  copy and a second pin mechanism.
- **Regenerate the netlists here.** Rejected: would diverge from the bytes
  the source's sim evidence used (designed once).

## Consequences

- **The netlists are stale under this repo's PDK pin.** `klt netlist
  --check` (klt 0.8.1.dev, xschem 3.4.7, PDK `ihp-sg13cmos5l`
  `f7bca32694fe`) reports `drifted` on all four cells. Two causes, neither
  an edit made here: (1) the committed netlists carry the generating
  machine's absolute `sch_path`/`sym_path` header lines, which differ on any
  other checkout; (2) the regenerated netlist adds `mm_ok=1` to every `M*`
  and resistor instance, because the symbols at the `dev` PDK pin emit it and
  the committed netlists were generated on the archived `607e18d4` PDK
  (see 0002). So the item-1 freshness check fails and item 1 stays `unmet`
  until the source regenerates (or this repo does, under a new record). The
  finding is filed as `sg13g2-bandgap` #405, and the path-header gap as
  `klayout-tools` #4208.
- `attest/item1.json` is committed, so the check can be re-run locally; its
  envelope is not cited in the manifest while the check fails.
- The signoff workflow pin moves from klayout-tools 0.7.0 to 0.8.0 (see
  `manifests/README.md`).
