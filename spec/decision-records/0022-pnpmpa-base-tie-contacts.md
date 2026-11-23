# 0022: The pnpMPA base tie is repaired as drawn geometry — base-ring contacts added, the ten `nSD` rings removed, items 2/3 re-attested

- **Status**: ratified, effective when the PR for issue #170 merges
- **Date**: 2026-11-21
- **Decided by**: Loom Builder agent, issue #170 (supersedes
  [`0018`](0018-pdk-runset-pnpmpa-nsd-ring.md) §1/§2 for the repaired
  stream, per its own §4 reopen condition)

## Context

#166's probe (its
[measurement note](../../measurements/2026-11-pnpmpa-base-tie-probe/README.md);
scratch-stream evidence only) found that the ten `pnpMPA` base rings in the
committed `bandgap_top` stream carry **zero contacts**. Root cause is
arithmetic in `draw_pnpmpa` (`layout/common_sg13cmos5l.py`): the base-ring
`cont_array` calls span `wall − 2·Cnt_c` in each wall's thin dimension, and
the wall was `min(dw2act, dh2act) = dh2act = 0.29 µm` — so the span is
`0.29 − 0.14 = 0.15 µm`, below the `Cnt_a = 0.16 µm` single-contact minimum,
and `cont_array`'s "draws nothing if the box cannot hold a single contact"
guard silently dropped every base-ring contact at this device size
(`w=1u l=2u`). The n+ `Activ` ring, the `NWell` base region and the `vss`
Metal1 ring were three electrically unconnected conductors: the base tie the
schematic draws does not exist as layout. The collector ring does not share
the defect (`d3act = 0.35` → 0.21 µm usable → one contact per position),
which is why the substrate tie was real while the base tie was not.

0018's premise — that the #240 `nSD` marker ring "makes the physically-real
tie gradeable" — measured tap *region* derivation, not tap *connection*. The
marker-keyed ERC form reported "no tap contact drawn" on the very stream
that drew the marker: there was no contact under it. And the runset's `pnp`
derivation excludes `nsd_drw` regions (`bjt_derivations.lvs`), so the same
marker was also what blocked `pnpMPA` recognition. A marker could not fix a
missing contact; a contact fix makes the marker counterproductive.

The PDK PCell's own answer to the same arithmetic: its base contacts sit only
on the left and right walls, whose width formula `dw2act = max(wact, 0.3)`
guarantees a landing `≥ 0.30 = Cnt_a + 2·M1_c1` at every size — the PCell
never contacts its `dh2act = 0.29` thin walls.

## Decision

1. **Widen the base-ring wall to hold contacts.** The wall becomes
   `max(min(dw2act, dh2act), Cnt_a + 2·Cnt_c) = 0.30 µm` (0.29 at every
   instantiated size), widening **inward** from the PCell's own unchanged
   outer extents (`br_*` from `pnpmpa_extent`'s formulae), so the 0.31 µm
   NWell margin, the collector-ring spacing, the cell bbox and every
   routing coordinate against `*_ring_m1` are exactly what they were; only
   the ring's inner edge moves, by the 0.01 µm `dh2act` was short (the
   pSD-to-base-Activ gap in the thin wall goes 0.18 → 0.17 µm; the PDK's
   `pSD.d1` floor for that gap is 0.03 µm, a rule the curated `sg13cmos5l`
   deck does not implement — see Evidence).
   Each ring now draws 24 `Cont` boxes (9 left + 9 right + 6 bottom,
   `Cnt_a` on a `Cnt_a + Cnt_b` pitch with exact `Cnt_c` enclosures). The
   bottom row's span is trimmed by `Cnt_b` at each end so it clears the two
   side columns' bottom contacts: spanning the full width (the first
   revision of this repair) overlapped them at both corners and merged
   into 20 L-shaped, non-square `Cont` polygons chip-wide, which the PDK
   deck classes as `ContBar` and fails against `CntB.a`/`CntB.a1`/`CntB.b2`.
   Every merged base-ring `Cont` polygon is now an exact 0.16 × 0.16 µm
   box, checked directly by the census. The Metal1 ring keeps its 0.02 µm insets (`width = wall − 0.04`),
   which at the new wall gives exactly `M1_c1` coverage on both sides of
   the contact row. The `cont_array` guard itself is unchanged and correct.

2. **Remove the ten PNP base-ring `nSD` markers** (the `b.ring(L_NSD, …)`
   call #240 added to `draw_pnpmpa`), restoring the PCell's own complement
   idiom for the n+ base. The two MOS well-tap `nSD` islands
   (`draw_well_tap`) and the `rhigh` body marker (`_draw_poly_res`) are
   untouched — #171's negative control already proved selective removal
   preserves both (2 `Cont`∩`nSD` and the `rppd` 2 / `rhigh` 1 inventory,
   re-verified on the repaired stream). The tie is graded on drawn contacts,
   not implant markers.

3. **The re-runs this forces** (0018 §4's list, "at minimum", all executed
   in the same PR): GDS regeneration (core, then top; amp/startup
   byte-identical and untouched), DRC on both regenerated streams (clean,
   reports refreshed), the item-2 attestation envelope regenerated
   (`attest/make-item2-envelope.py --regenerated`, byte-identical rerun
   verified with `cmp`), the manifest's item-2 and item-3 `content_hash`
   updated, and the signoff record regenerated — plus one re-run the
   committed evidence itself forced: `sim/pex-bandgap-top`'s record pins
   the layout hash it measured, so `sim/pex-run.sh` was re-run on the
   repaired stream (`20261123T113843Z-2e66606`: same 17 devices / 13 nets /
   66 R / 13 C cards, `parasitic_integrity` clean, `body_bias` biased, the
   same `not_checked` extract-only status and the same pnpMPA inventory
   mismatch 0012 records) and the manifest's item-7 citation now names the
   new envelope. The superseded run's record stays committed and auditable:
   the pre-repair stream bytes it measured are preserved unchanged at
   `sim/pex-bandgap-top/superseded/4e4e4f85fa08-bandgap_top.gds` and the
   old record's `layout.path` points there (its `layout.relocated_by`
   field says so) — every hash every record names still resolves, which
   `sim/tests/test-pex-device-inventory.sh` checks offline. Items 2 and 3
   both remain `met` against the new top hash; item 7 remains
   `unmet / check_failed`, unchanged. **Superseded commits of record**:
   item 2 at `33249ff` (PR #41), item 3 at `fce5dca` (PR #44). **Streams
   of record**: superseded top `sha256:4e4e4f85fa08…`, repaired top
   `sha256:7f6e35d5fa145…` (core `832b570e7d10…` → `7fc6bb248e7b…`).

4. **0018's disclosure rule lapses for the repaired stream** — its own §4
   condition is met: a runset-engine extraction of the repaired committed
   hash derives the full `pnpMPA` inventory (10 units at
   `--deck-var no_simplify=true`; 3 cards under the runset's default
   `simplify`, the eight Q2 units folding as true parallels) with every
   base terminal on **one shared net** — shared with the collectors,
   disjoint from the three emitter groups, and named `vss` by the ERC run
   on the same hash. The rule still binds every result cited against the
   superseded `4e4e4f85` stream. 0012's curated-deck story is unchanged:
   the curated deck still declares no bipolar class (17 devices, no
   `pnpMPA`), so item 7's `check_failed` verdict and #29's/#32's scopes do
   not move.

## Evidence

[`measurements/2026-11-pnpmpa-base-tie-repair/`](../../measurements/2026-11-pnpmpa-base-tie-repair/README.md)
is the evidence of record: the geometry census (superseded stream reproduces
#166's 0-contacts-per-ring exactly; repaired stream 24 bridged base contacts
per ring, 18 emitter contacts, emitter isolated, `Cont`∩`nSD` = 2), the ERC
pair on #171's population spec `erc-spec-population-markerfree.json` (10 ×
`erc.missing_tie` on `pnp_base_tap_vss` at the superseded hash as the
negative control; `erc_status: "clean"` at the repaired hash, both supplies
1/1 islands, both tie classes checked), the runset extractions, and the DRC
runs. Every row carries its tool versions and input hashes in its report
file.

**What the curated DRC deck does not cover.** `klt drc --deck sg13cmos5l`
checks only `5.1 NWell`, `5.5 Activ`, `5.8 GatPoly`, `5.16 Metal1`, `5.17
Metaln` and `5.19–5.22 Via/TopMetal` (`layout/sg13cmos5l-bandgap_top/drc.json`
→ `coverage.deck_scope`); it has no `5.14 Cont` / `5.15 ContBar` rule and no
`5.10 pSD` rule. The base-ring contact shape and spacing are therefore graded
by `census.py` (every merged base-ring `Cont` polygon an exact 0.16 × 0.16 µm
box, minimum contact space ≥ `Cnt.b` = 0.18 µm), and the 0.17 µm pSD-to-base-
Activ gap is held against the PDK's own `pSD.d1` (min pSD space to N+ Activ
in NWell, 0.03 µm, `sg13cmos5l_maximal.drc`), not against the curated deck.
The emitter-to-base `Activ` gap (0.35 µm vs `activ.space.1` 0.21 µm) is the
one the curated deck does check.
The production ERC spec (`erc-supply-spec.json`, DR-0020) keeps its
marker-keyed `pnp_base_well_tap_vss` tie and its committed report stays
bound to the superseded `4e4e4f85` stream: #167 owns that file, the
marker-only check is the known weak form (it passes the bad stream), and
migrating it to the contact-qualified form is that domain's follow-up, not
this record's change.

## Alternatives considered

**Keep the `nSD` markers and fix only the contacts.** Rejected: the runset's
`pnp` derivation excludes `nsd_drw`, so recognition — 0018 §4's own reopen
condition — stays blocked, and the marker then guards nothing the contacts
do not grade better.

**Widen the wall outward (or move the contacts to a single-centre-row
placement).** Outward widening moves every outer edge the assembly routes
against for no clearance it needs; the inward form is a strictly smaller
diff with identical contact content. A centre-row placement that "fits" the
0.29 wall does not exist: 0.29 − 0.14 = 0.15 < `Cnt_a` is the defect.

**Contact only the side walls, as the PCell does.** Rejected for this
layout, not for the PDK: the simplified footprint's uniform-wall idiom and
its three-wall (open-top) contact scheme are what the callers' straps and
escape routes were built and DRC-proven against; the guidance for this
repair keeps them and requires the corner check instead (the bottom row is
trimmed to clear the side columns by `Cnt_b`).

## Consequences

- `layout/README.md`'s reproduction, evidence and extraction sections are
  updated to the repaired stream; the ERC section states the production
  report's binding explicitly.
- No spec row is relaxed; the Area row's numbers are refreshed from the
  regenerated stream (`klt stats`, bbox unchanged).
- The sibling `2AMLogic/sg13g2-bandgap` stream `1b07a94d…` carries the same
  defect (filed there as sg13g2-bandgap#633); its repair is that repo's to
  make against its own records.
- #29 and #32 consume the repaired geometry from here; their LVS-match and
  PEX scopes are unchanged by this record.
