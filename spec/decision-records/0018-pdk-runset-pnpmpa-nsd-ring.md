# 0018: The #240 `nSD` rings stay — every runset-engine result on this stream discloses that the PDK runset derives no `pnpMPA`

- **Status**: ratified, effective when the PR for issue #145 merges
- **Date**: 2026-11-18
- **Decided by**: Loom Curator proposal, Champion-approved (issue #145);
  implemented by the Loom Builder agent

## Context

The committed `bandgap_top` stream deviates from the PDK `pnpMPA` PCell idiom
on purpose: issue #240 draws an explicit `nSD` marker ring (`L_NSD = (7, 0)`,
`layout/common_sg13cmos5l.py:68`) over each base contact ring — same
coordinates, same wall width as the n+ `Activ` ring — because the PDK PCell
draws n+ as `pSD`'s complement and places no marker, so every marker-keyed
derivation (`klt erc`'s `ties[]` boolean, the curated deck's `tap_nplus`) was
structurally blind to the physically-real base/substrate tie. The draw and its
documented trade are `layout/common_sg13cmos5l.py:580` and the comment block
above it.

The PDK's own KLayout LVS runset does implement `pnpMPA` — but its derivation
excludes that marker. On the pinned install this repo's probes run against
(`~/share/pdk/ihp-sg13cmos5l`, whose fleet-store marker `.pdk-store.json`
records `"version": "f7bca32694fe3d58be0cc7d9df4b9f5db7161a14"` — the
`IHP-GmbH/IHP-Open-PDK` `dev` pin `spec/porting-plan.md` records, proved by the
same revision-proof chain `sim/env.sh` uses), as read 2026-11-18:

- `rule_decks/layers_definitions.lvs:140`: `nsd_drw  = get_polygons(7, 0)`;
  `:145`: `nsd_block = get_polygons(7, 21)`
- `rule_decks/bjt_derivations.lvs:32`:
  `bjt_exclude = gatpoly.join(pwell_block).join(nsd_drw)`
- `:110-113`: `pnp_exclude = trans_drw.join(emwind_drw)
  .join(emwihv_drw).join(nsd_block).join(bjt_exclude)`; then
  `pnp_mk = ptap_holes.not(pnp_exclude)`
- `:118`: `pnp_b = nactiv.and(pnp_mk).and(nwell_drw)` — the drawn n+ ring is
  covered entirely by the drawn `nSD` ring, so it falls out of `pnp_mk` and
  `pnp_b` derives empty
- `:122`: `pnp_mpa_e = pnp_e.and(pnp_b.extents).and(pnp_c.extents)` — empty
  with it; no `pnpMPA` device is derived

Measured, re-run first-hand for this record on 2026-11-18 (host `klt
0.9.3.dev1136+g81926eccba7b`, klayout 0.30.12; the finding was first posted in
issue #145 and reproduced there as a probe; layout
`layout/sg13cmos5l-bandgap_top/sg13cmos5l-bandgap_top.gds`,
`sha256:4e4e4f85fa0875651c294c95a1f65792fa1913dd20d027fbe6905f2d001cb330` —
the stream items 2/3 cite, re-hashed unchanged on this tree; runset
`libs.tech/klayout/tech/lvs/sg13cmos5l.lvs`,
`sha256:0d91cb6e4c4aba974ffb07175614c183faab1cb8c6b7fab483e38d3cfcb5df5c`;
scratch dir `/tmp`, nothing written to the checkout):

| Run | Devices derived |
|---|---|
| `klt extract --engine klayout-runset --deck-file <runset>` on the committed stream | **17**: `sg13_hv_nmos` 6, `sg13_hv_pmos` 8, `rppd` 2, `rhigh` 1 — **no `pnpMPA`** |
| Same, on a scratch copy with every `(7, 0)` shape cleared (105 shapes) | **27**: **`pnpMPA` 10**, `sg13_hv_nmos` 6, `sg13_hv_pmos` 8, `rppd` 3, `rhigh` 0 |

The stripped run's 10 `pnpMPA` units match the schematic's inventory (3 cards /
10 units) exactly, which is the falsification: the `(7, 0)` layer is precisely
what blocks recognition. The stripped run is otherwise *not* clean — `rppd`
gains a device and `rhigh` loses its one once the marker is gone (the collector
rings / substrate tie re-classify; untraced here) — so it is evidence about the
mechanism, not a candidate mask set.

This is a different mechanism from
[`0012`](0012-post-layout-pex-extraction-gap.md)'s gap and leaves that record's
story untouched: 0012 records that the *curated* deck declares no bipolar class
at all (17 extracted vs 20 cards / 27 units); here the runset *does* implement
the device, and the layout's own marker ring — the thing that makes the tie
gradeable — is what its derivation excludes. Consequences stack: a
runset-engine route fails on this record's mechanism, a curated-deck route on
0012's.

## Decision

1. **The #240 `nSD` rings stay.** The mask set of the committed, attested
   stream is not changed: no GDS regeneration, no re-run of items 2/3, no
   change to `design/`, `layout/`, or any ratified spec row. The accepted cost
   is explicit: for as long as the rings are drawn, every runset-engine route —
   [`klt lvs`](https://github.com/2AMLogic/klayout-tools/issues/4927) with
   `"engine": "klayout-runset"` in its request (the path #4927 documents as the
   supported LVS route), `klt extract --engine klayout-runset`, and any future
   `klt pex` runset mode — sees a different circuit than the schematic for this
   stream, because it derives no `pnpMPA`.

2. **The disclosure rule**: any cited runset-engine result on this stream must
   state that the PDK runset derives no `pnpMPA` for it — because of the #240
   `nSD` rings, per the derivation in §Context — and point at this record. A
   runset-engine row that depends on `pnpMPA` recognition is
   `insufficient-evidence`, not a pass (the same house rule
   [`0012`](0012-post-layout-pex-extraction-gap.md) §2 applies to rows graded
   from a bipolar-free extracted netlist).

3. **Where the rule binds** — the minimum surface; anything citing a
   runset-engine result for this stream is covered by §2 regardless:
   - `spec/target-spec.md` §Signoff's #4927 entry states the runset engine is
     the supported path for an LVS *match*; every citation of that path for
     this stream carries the disclosure.
   - [`0012`](0012-post-layout-pex-extraction-gap.md)'s runset note (its
     closing consequence: the runset engine #4927 documents is an LVS-side
     answer that does not reach extraction) — the rule binds its runset half.
     The record itself is left untouched: it is ratified, and ratified records
     are superseded, never rewritten.
   - #29 (T1 item 4, LVS) and #32 (T1 item 7, post-layout verification)
     evidence wording: any report, envelope or record those issues cite that
     was produced by a runset engine carries the disclosure. Both issues
     receive a cross-reference comment pointing here in the PR that lands this
     record; neither issue's scope changes.

4. **Reopen condition.** A redraw of the base tie (or any other mask-set
   change) is not decided here. If it is later wanted, it takes its own record
   naming which commit of items 2/3 it supersedes and listing the re-runs it
   forces (GDS regeneration, DRC, the item-2 attestation envelope at minimum).
   The disclosure rule lapses for a given stream only when a record shows a
   runset-engine extraction of that stream's committed hash deriving the full
   `pnpMPA` inventory (3 cards / 10 units).

## Alternatives considered

**Remove or redraw the `nSD` ring so the runset derivation sees the base
tie.** Rejected. It is a mask-set change to a committed, attested stream: items
2/3 would need re-running and re-attestation. It is also not known to *work*:
the stripped probe's own inventory is unclean (`rppd` 3 vs 2, `rhigh` 0 vs 1,
untraced), so removing the marker demonstrably re-classifies other devices; and
#240's motivation — a gradeable substrate tie — would regress, sending the tie
back behind marker-blind derivations or forcing a different marker mechanism
nobody has designed.

**Gate the ring to a layer the runset's derivation ignores.** Rejected on both
halves of §1's cost: it is still a mask-set change (items 2/3 reopen), and the
layer choice is untraced — whether any drawable layer keeps the marker-keyed
checks (`klt erc`'s `ties[]`, the curated deck's `tap_nplus`) working while
dropping out of `nsd_drw`/`nsd_block` is unverified. Speculative layout surgery
on an attested stream for an unmeasured payoff.

**Treat it as a runset bug and wait, or patch a local fork of the runset.**
Rejected. The runset is PDK-owned and shared; its exclusion of `nSD` shapes
from the `pnp` derivation is defensible for PDK-idiom layouts, where n+ over a
PNP base is `pSD`'s complement and no `nSD` marker exists — the deviation is
ours, documented at #240. A local fork of `sg13cmos5l.lvs` would break the
provenance every runset citation relies on. The tool-side half that *is* a gap
— `klt pex` has no runset engine at all — is filed separately as
[`klayout-tools#6559`](https://github.com/2AMLogic/klayout-tools/issues/6559);
this record does not depend on it.

## Consequences

- This record is additive: no change to `design/`, `layout/`, the committed
  GDS, or any ratified spec row or ratified record. Items 2/3 remain attested
  as committed; DR-0012's curated-deck story (17 extracted vs 20 cards / 27
  units) is unchanged.
- The rule binds future citations, not committed evidence: everything committed
  to date came from the curated deck (`klt extract`/`klt pex`), and 0012
  already records what that is worth. No committed artifact is relabelled.
- #29 and #32 receive cross-reference comments pointing here; their evidence
  wording is constrained by §3 from the moment this record is effective. #32
  remains blocked on the PEX route; #29 remains open on LVS.
- Untraced, named: whether the stripped probe's `rppd`/`rhigh` shifts are a
  separate defect. Out of scope per #145; tracing it later does not supersede
  this record unless it changes the decision.
- §Context's probe is reproducible from the two hashes and the store marker
  quoted there: the committed-stream run against the pinned GDS, the stripped
  run against a scratch copy with `(7, 0)` cleared. Neither wrote to the
  checkout.
