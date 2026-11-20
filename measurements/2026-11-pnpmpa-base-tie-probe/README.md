# 2026-11 pnpMPA base-tie probe (#166): ring-free runset recognition vs a gradeable base tie

**Scratch-stream evidence. No T1 item may cite this note.** Nothing under
`design/`, `layout/`, `manifests/`, `evidence/`, `attest/` or any ratified
record changed for it, and no generated stream is committed; the scratch GDS
is quoted by hash and reproduced by the recipe below. Decision record
[0018](../../../spec/decision-records/0018-pdk-runset-pnpmpa-nsd-ring.md) §4
(reopen condition) is the governing question: *does a `bandgap_top` without
the ten `pnpMPA` base-ring `nSD` shapes derive `pnpMPA` on the PDK runset and
still grade its base tie?*

**Answer in one line: recognition yes — the full 10-unit inventory with the
`rppd`/`rhigh` counts unchanged — but no tie is gradeable on either stream,
and the probe found why: the base rings carry zero contacts, so the base tie
does not exist as drawn geometry at all** (#170). The blocker is a layout
defect, not tool behaviour.

Run 2026-11-20 on `2b0a1ae` by the Loom Builder; the geometry control
reproduces this issue's own verified correction exactly.

## Provenance

| Item | Value |
|---|---|
| Committed top stream | `layout/sg13cmos5l-bandgap_top/sg13cmos5l-bandgap_top.gds`, `sha256:4e4e4f85fa0875651c294c95a1f65792fa1913dd20d027fbe6905f2d001cb330` (0018's stream, unchanged) |
| Scratch top stream | `sha256:64cb6e055500f5a9732c675c4e7f065581bee8e2777f42baa1f54f8bdd3976a9` (matches the issue's verified correction) |
| Scratch core leaf | `sha256:a6f252239357fb3d85212a8c972d312a464bbc1a7e709a01bf72ced3d40622de` (committed core: `832b570e7d109e0f1449271ee1aca27e1599a856fd15ffe4d999c4db8f1fc5d3`) |
| Retained leaves | amp `f277d98557728bb77e2a7332fa5052488a383fb90d233ef1cffd38071c22863a`, startup `a18f8c052af3d66f9e988cd874d92e0379d034f25cf9ce187dc351ad19c368fa` — byte-identical to committed |
| PDK | `~/share/pdk/ihp-sg13cmos5l`, revision `f7bca32694fe3d58be0cc7d9df4b9f5db7161a14` (store marker `.pdk-store.json`) |
| PDK LVS runset | `libs.tech/klayout/tech/lvs/sg13cmos5l.lvs`, `sha256:0d91cb6e4c4aba974ffb07175614c183faab1cb8c6b7fab483e38d3cfcb5df5c` (0018's hash, unchanged) |
| klt, curated/ERC/DRC/PEX rows | `0.8.0` (CI pin, `uvx --from "klayout-tools==0.8.0"`), klayout module `0.30.13` |
| klt, runset rows | host `0.9.3.dev2572+g75c6350d487d`, standalone klayout `0.30.12` — `--engine klayout-runset` does not exist at the 0.8.0 pin (clean error), so those rows run on the named newer build per the issue's instruction |
| Geometry regeneration | `uv run --with klayout` → klayout Python `0.30.13` |

## The recipe (geometry control)

1. `cp -r layout/ /tmp/probe166/layout` — nothing written to the checkout.
2. Delete the single `b.ring(L_NSD, br_x0, br_y0, br_x1, br_y1, min(d["dw2act"], d["dh2act"]))` call in `draw_pnpmpa` (`layout/common_sg13cmos5l.py:580`, the #240 ring; the file's other `L_NSD` uses — `draw_well_tap`'s tap island and `_draw_poly_res`'s `rhigh` body marker — stay).
3. `uv run --with klayout python3 layout/sg13cmos5l-bandgap_core/generate.py`, then `.../sg13cmos5l-bandgap_top/generate.py` (reads the leaf GDS; amp/startup stay committed).

Raw `(7, 0)` shape census, per cell (raw boxes as stored, hierarchy walked):

| Stream | core | startup | amp | top | total |
|---|---|---|---|---|---|
| committed | 41 | 63 | 1 | 0 | **105** |
| scratch | 1 | 63 | 1 | 0 | **65** |

The core's one retained shape is the mirror-well `nSD` tap island; the
`rhigh` body marker is among startup's retained 63. Hierarchical
merged-polygon XOR on `(7, 0)`: **exactly 10 removals, 0 additions**, each
removal one closed frame (wall 0.29 µm, 2.78 × 3.3 µm outer; Q1 at
`(-1.39, 28.35)–(1.39, 31.65)`, Q2×8 on the y=30 row, Q3 at
`(215.42, -1.96)–(218.82, 1.96)`). Expected 105 → 65 confirmed.

## Measurement A — `klt extract --engine klayout-runset` (runset engine, klt 0.9.3.dev2572)

| Stream | status | device counts |
|---|---|---|
| committed | extracted | `sg13_hv_nmos` 6, `sg13_hv_pmos` 8, `rppd` 2, `rhigh` 1 — **17 devices, no `pnpMPA`** (0018 reproduced) |
| scratch | extracted | **`pnpMPA` 10**, `sg13_hv_nmos` 6, `sg13_hv_pmos` 8, `rppd` 2, `rhigh` 1 — 27 devices |

Target counts met exactly (`pnpMPA` 10 / `rppd` 2 / `rhigh` 1 / nmos 6 / pmos 8).
**But**: in the scratch netlist every `pnpMPA` base terminal sits on its own
anonymous net (`$4`, `$18`, …`$26` — ten distinct nets), and the runset netlist
carries **no net names at all** (this stream labels on `8/2`; the runset reads
no names from it), so the derived circuit is ten floating-base devices, not a
match candidate. Device recognition is purely geometric in the runset's
`bjt_derivations.lvs`; connection still needs contacts (see the finding below).

## Measurement B — curated deck, `klt extract` and `klt pex --extract-only` (klt 0.8.0)

| Stream | extract devices/nets | pex devices/nets, `body_bias` | normalized netlist sha |
|---|---|---|---|
| committed | 17 (`nfet` 6, `pfet` 8, `rppd` 2, `rhigh` 1) / 13 | 17 / 13, `biased`, 0 unbiased | `103d0f15f8cb…` |
| scratch | identical | identical (extracted netlists byte-equal, sha `1d359847555d…`) | `103d0f15f8cb…` |

**Is each base well tied to its base net through `tap_nplus_complement`? No —
and it never was.** The curated deck declares no bipolar class, so a PNP well
or derived tap leaves no netlist trace; the byte-identical outputs prove *no
regression*, not a working tie. The tie question is settled by the geometry
and by ERC (C): in both streams the derived tap region — `tap_nplus`
(`Activ ∩ nSD`, committed) or `tap_nplus_complement` (`Activ ∩ NWell − pSD`,
either stream) — is an isolated conductor, because **no `Cont` exists on the
base ring to bridge it to the Metal1 ring**.

## Measurement C — `klt erc` (klt 0.8.0), three spec variants × two streams

All specs share the sibling-migrated stackup (`GatPoly 5/0` gate with
`active_layer 1/0`, `Metal1 8/0` label `8/2`, `Cont 6/0` between) and
`vdd`/`vss` supplies; both nets matched 1 island of 1 expected in every run.
Coverage: every tie class `checked`, `skipped` empty, no assertion-based
coverage (no `tap_boxes`/`well_boxes` used).

| Spec | PNP tie form (`net vss`) | committed | scratch |
|---|---|---|---|
| `erc-spec-baseline` (sibling's, one `vdd` tie over all wells) | — (all wells graded against `vdd`) | 10 × `erc.missing_tie` "not connected to 'vdd'" | 10 × same |
| `erc-spec-population-markerfree` | wells: `31/0` minus poly (`well_excludes ["5/0"]`); tap: `1/0 ∩ 6/0` | 10 × "tap not connected to 'vss'" | 10 × same |
| `erc-spec-population-markerkeyed` | same wells; tap: `1/0 ∩ 6/0 ∩ 7/0` | 10 × "**no tap contact drawn**" | 10 × same |

The MOS tie (`well_requires ["5/0"]`, tap `1/0 ∩ 7/0`, `net vdd`) passes on
both streams: 2 wells, both tapped by the retained `draw_well_tap` islands
(2 of the stream's 1643 `Cont` boxes overlap `nSD` — exactly these two).

Read the marker-keyed row against 0018's premise: on the **committed** stream,
with the #240 marker present, the PNP wells still report *no tap contact
drawn* — there is no contact under the marker. The tie verdict is decided by
the declaration *and* by the drawn contacts; the marker alone never made this
tie gradeable. The marker-free (contacted-diffusion) row shows what the
engine can see instead: the only contacted diffusion inside each PNP well is
the emitter (nets `sns1`/`e2`/`e3`), which correctly does not reach `vss`.

## Measurement D — `klt drc --deck sg13cmos5l` (klt 0.8.0)

| Stream | status | violations |
|---|---|---|
| committed | clean | 0 (matches the committed `layout/sg13cmos5l-bandgap_top/drc.json`) |
| scratch | clean | 0 |

No new finding relative to the committed baseline; removing the ten rings is
DRC-inert on this deck.

## The finding: the base tie does not exist as drawn (#170)

`draw_pnpmpa`'s three base-ring `cont_array` calls span
`wall − 2·Cnt_c = 0.29 − 0.14 = 0.15 µm` in each wall's thin dimension —
below the `Cnt_a = 0.16 µm` single-contact minimum — so `cont_array`'s
minimum-size guard silently places **zero** contacts on every base ring at
`w=1u l=2u`. Measured: Q1's well area holds 18 `Cont` boxes, all over the
emitter window; the base-ring walls hold none; stream-wide 2 of 1643 `Cont`
overlap `nSD`, both MOS tap islands. The collector ring does not share the
defect (`d3act = 0.35` → 0.21 µm usable → one contact per position), which is
why the substrate/collector tie is real while the base tie is not. The
`2AMLogic/sg13g2-bandgap` stream `1b07a94d…` has the same census (filed as
sg13g2-bandgap#633). The n+ `Activ` ring, the `NWell` base region and the
`vss` Metal1 ring are three unconnected conductors in both streams of this
probe.

## The `rppd`/`rhigh` shift 0018 left untraced: explained

0018's stripped probe cleared **all 105** `(7, 0)` shapes, including the
`rhigh` body marker `_draw_poly_res` draws for the `rhigh` flavour only (the
curated deck's `rhigh.requires` includes `(7, 0)`; `rppd`'s does not) — which
reclassifies the one `rhigh` as a third `rppd`, exactly the 3/0 the probe
saw. Removing only the ten base rings leaves that marker in place:
`rppd` 2, `rhigh` 1 on the scratch stream, identical to committed
(measurement A). Confirmed: the shift was the `rhigh` body `nSD`, not the
base rings.

## Conclusion

- **Full `pnpMPA` inventory on the runset without the rings: YES** — 10 units,
  all other class counts unchanged, DRC clean. 0018's reopen condition's
  recognition half is met by the geometry alone.
- **Gradeable base tie on the curated deck and in `klt erc`: NO — on either
  stream.** Not because the marker is missing but because the contact is: the
  base rings were never contacted, so no marker choice or tie declaration can
  grade a tie that is not drawn. The blocking behaviour is **not a klt gap**;
  it is layout defect #170 (follow-up with its own decision record per 0018
  §4, naming the items 2/3 re-runs a contact fix forces).
- Tool gap found and filed separately (generic form):
  klayout-tools#6954 — `klt erc`'s `ties[]` cannot express a complement-form
  tap boolean (`tap = layer − implant`), so a PDK-idiom marker-free tap stays
  undeclarable without literal `tap_boxes` assertions even once #170 is fixed
  marker-free. Cross-linked from #29 and #32.

## Signoff comparison (acceptance criterion)

`klt signoff --manifest manifests/sg13cmos5l-bandgap.json --tiers-doc
manifests/design-evidence-tiers.md --format json` at the 0.8.0 pin: exit 3
(grader clean, items unmet as committed), output **byte-identical** to
`manifests/sg13cmos5l-bandgap.signoff.json`. No committed stream, envelope,
manifest or ratified record was modified; `git diff` on this branch touches
only `measurements/`.

## Files

- `erc-spec-baseline.json`, `erc-spec-population-markerfree.json`,
  `erc-spec-population-markerkeyed.json` — the exact scratch ERC declarations
  (C's three variants; the population pair is identical bytes for both
  streams).
- `reports/` — the raw JSON for every table row above
  (`runset-*`, `curated-*`, `pex-*`, `drc-*`, `erc-*`; `-committed` /
  `-scratch` suffix). Each carries its own `provenance` (klt/klayout/input
  hash). The pex envelopes' extracted netlists are byte-equal; their sha is
  in the envelopes.
