# 0001: Ratify the target-spec table for SG13CMOS5L

- **Status**: ratified, effective when the PR for issue #2 merges. This repo
  has no two-key release gate yet; the sibling's `scripts/ratify-key.sh` flow
  is not assumed.
- **Date**: 2026-10-17
- **Decided by**: Loom Builder agent, issue #2

## Context

`README.md` carried a draft table. `sg13g2-bandgap` ratified an SG13G2 table
(its `0007`, `0011`, `0014`) whose **shapes** apply here and whose **values**
were derived on an `npn13G2` core. This block uses `pnpMPA` (gain near 1) and
has no MIM capacitor. At `52535387e6ccf0a89f6490901a9abb2b78144176` the source
has no TC, PSRR, Iq or mismatch bench for the SG13CMOS5L core
([`porting-plan.md`](../porting-plan.md)). Ratifying a result-shaped number
would therefore ratify a guess.

## Decision

1. The table in [`target-spec.md`](../target-spec.md) is the block's spec, and
   `README.md`'s table is the same table.
2. The **method and bench** of each row are ratified. Numbers marked
   "derived" (output nominal, untrimmed line, trimmed line, trim range and
   resolution) and "set after" (area) are recorded by a superseding record when
   their bench has produced committed evidence. They are not copied from SG13G2.
3. The TC, PSRR, Supply, Iq and Startup targets, fallbacks and stretches are
   the draft's numbers, kept. Nothing is relaxed. Each is a target, not a
   claim that it is met; the Status column in `target-spec.md` says which have
   any evidence.
4. Rows that depend on a MoM capacitor's value are `insufficient-evidence`,
   not a pass.
5. A fallback to an all-MOS reference is a **different block**, not a recorded
   fallback of this one. It is considered only if the TC fallback
   (< 100 ppm/°C) is itself missed on measured evidence, and then needs its own
   issue and record.
6. The 1.2 V LV supply row stays a stretch and needs its own LV-flavour
   derivation; it is not argued here.

## Alternatives considered

- **Copy the SG13G2 numbers (1.050 V, ±16%, ±0.5%).** Rejected: they came from
  an `npn13G2` Brokaw sum and its mismatch scatter.
- **Leave the table draft until benches exist.** Rejected: the issue gates #3
  to #5 on a ratified table, and the rows that can be fixed now (supply,
  TC/PSRR/Iq targets, bench names, corner box) are not blocked by missing
  benches.
- **Ratify a trimmed-line number now from an estimate.** Rejected: the SG13G2
  trimmed line (±0.5%) was later measured as not met (its `0014`).

## Consequences

- Follow-on issues create the benches listed in `target-spec.md`; each
  produces a record that a superseding decision record cites.
- TC and Output-reference rows stay `target-only` until then. The honest
  status of the README is "specification ratified, no row evidenced".
- Grids run through `klt sim` on the batch fleet; klayout-tools#2727 and #3134
  currently block that for CMOS5L.
