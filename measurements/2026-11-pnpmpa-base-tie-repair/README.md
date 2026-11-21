# 2026-11 pnpMPA base-tie repair (#170): contacted base rings, markers removed

**Evidence of record for the repaired stream** (decision record
[`0021`](../../spec/decision-records/0021-pnpmpa-base-tie-contacts.md), which
supersedes [`0018`](../../spec/decision-records/0018-pdk-runset-pnpmpa-nsd-ring.md)
§4's keep). The repair changes `draw_pnpmpa`
(`layout/common_sg13cmos5l.py`) two ways: the base-ring wall widens from
`min(dw2act, dh2act) = 0.29` to `max(min(dw2act, dh2act), Cnt_a + 2*Cnt_c) = 0.30 µm`
(widening inward from the unchanged PCell outer extents, so every outer-edge
clearance and routing coordinate is unchanged), which lifts the `cont_array`
underflow that drew **zero** contacts on every base ring; and the ten PNP
base-ring `nSD` (7/0) markers are removed, restoring the PCell's own
complement idiom so the PDK runset's `pnp` derivation recognises the devices
(it excludes `nsd_drw` regions). The two MOS well-tap `nSD` islands and the
`rhigh` body marker are untouched.

Run 2026-11-21 on the `#170` repair branch by the Loom Builder.

## Provenance

| Item | Value |
|---|---|
| Superseded top stream | `4e4e4f85fa0875651c294c95a1f65792fa1913dd20d027fbe6905f2d001cb330` (main `5968a91`, 0018's stream; extracted with `git show` for the control runs) |
| Repaired top stream | `layout/sg13cmos5l-bandgap_top/sg13cmos5l-bandgap_top.gds`, `sha256:10c43369670ffbfcf7a553830f2edcea1ed44f30bdb4d2088f35f37ebd131e5c` |
| Superseded / repaired core leaf | `832b570e7d10…` → `fb6af4dc470f…` |
| Retained leaves | amp `f277d9855772…`, startup `a18f8c052af3…` — byte-identical, untouched |
| Regeneration | `uv run --with klayout python3 layout/sg13cmos5l-bandgap_{core,top}/generate.py` (amp/startup committed); a second full regeneration is byte-identical (`cmp`, both streams) |
| PDK | `~/share/pdk/ihp-sg13cmos5l`, revision `f7bca32694fe3d58be0cc7d9df4b9f5db7161a14` (store marker `.pdk-store.json`) |
| PDK LVS runset | `libs.tech/klayout/tech/lvs/sg13cmos5l.lvs`, `sha256:0d91cb6e4c4aba974ffb07175614c183faab1cb8c6b7fab483e38d3cfcb5df5c` (0018's hash, unchanged) |
| klt, ERC/census-adjacent rows | `0.8.0` (CI pin, `uvx --from "klayout-tools==0.8.0"`), klayout module `0.30.13` |
| klt, runset rows | host `0.9.3.dev2575+g6bd18bbc8637`, standalone klayout `0.30.12` (`--engine klayout-runset` does not exist at the 0.8.0 pin — same split as the #166 probe) |
| klt, DRC / signoff | `0.8.0` with `klayout==0.30.12` (the pin's tested engine) |

## Measurement A — geometry census (`census.py`, klayout 0.30.13)

`census.py` (beside this README) walks the stream hierarchy: per gate-free
NWell island (the ten PNP base wells), the merged Cont polygons on base Activ
(Activ inside the well, outside pSD) that also sit under Metal1 — the contacts
that physically bridge the n+ ring to its Metal1 ring — plus the
emitter-window contacts.

| Stream | raw Cont boxes | Cont∩nSD | gate-free wells | base contacts/well (bridged) | emitter contacts/well |
|---|---|---|---|---|---|
| superseded | 1643 | 2 | 10 | **0** (0) | 18 |
| repaired | 1903 | 2 | 10 | **24** (24) | 18 |

The superseded row reproduces #166's census exactly (1643 / 2 / 0 / 18). The
repaired stream draws 26 Cont boxes per ring (9 left + 9 right + 8 bottom,
`cont_array` on the 0.30 µm wall) that merge into 24 polygons at the two
bottom corners where the side and bottom rows meet — the corner-merge the
issue's implementation guidance names; the collector ring has always merged
the same way (its `d3act = 0.35` wall yields one contact per position). DRC
(measurement D) checks the spacing. No contact touches both base Activ and
in-well pSD on either stream: the emitter stays isolated from the ring. The
2 Cont∩nSD are the two MOS well-tap islands — the only nSD left in the
stream besides startup's `rhigh` body marker.

## Measurement B — `klt erc` 0.8.0, population spec (marker-free, contact-qualified)

Spec: [`../2026-11-pnpmpa-base-tie-probe/erc-spec-population-markerfree.json`](../2026-11-pnpmpa-base-tie-probe/erc-spec-population-markerfree.json)
(#171's, byte-identical for both runs): wells `31/0` minus poly
(`well_excludes ["5/0"]`), tap `1/0 ∩ 6/0`, `connect_to` Metal1, `net vss`;
the MOS tie (`well_requires ["5/0"]`, tap `1/0 ∩ 7/0`) grades `vdd`.

| Stream | erc_status | PNP findings | MOS wells | islands |
|---|---|---|---|---|
| superseded | `violations` (exit 3) | **10 × `erc.missing_tie`** ("tap is not connected to declared net 'vss'", layer `pnp_base_tap_vss`, one bbox per well) | tied (0 findings) | vdd 1/1, vss 1/1 |
| repaired | **`clean`** (exit 4 = antenna `not_checked`, no `--pdk` table) | **0** | tied | vdd 1/1, vss 1/1 |

`erc_coverage.checked` carries both tie classes, `skipped` empty, on both
streams — the negative control ran the same check the repair is accepted on.
The exit-4 top-level `status: not_checked` is the `--pdk`-less antenna
contract (no sg13cmos5l antenna table exists); the verdict field is
`erc_status`. This run, on the repaired committed hash, is also what names
the runset's shared base net: it is `vss`.

## Measurement C — `klt extract --engine klayout-runset` (klt 0.9.3.dev2575)

| Run | status | device counts | PNP base nets |
|---|---|---|---|
| `--deck-var no_simplify=true` | extracted | **`pnpMPA` 10**, `sg13_hv_nmos` 6, `sg13_hv_pmos` 8, `rppd` 2, `rhigh` 1 | **one shared net** (`$1`), collectors on it too, emitters `$2`/`$5`/`$6` |
| defaults (runset `SIMPLIFY` on) | extracted | `pnpMPA` 3 (= the schematic's 3 cards: the eight Q2 units are parallel and fold), rest identical | one shared net |

0018's reopen condition is met for the repaired hash: the runset derives the
full `pnpMPA` inventory, and — unlike the #166 scratch stream, whose ten
floating bases sat on ten distinct anonymous nets — every base terminal is on
**one** net, shared with the collectors, disjoint from the three emitter
groups. `no_simplify=true` is passed to show all ten units (the runset's
default `Netlist.simplify` folds the eight parallel Q2 units into one card;
neither form has a floating base). Net names: the runset reads none from
`8/2`; measurement B establishes the shared base/collector net is `vss`.

## Measurement D — `klt drc --deck sg13cmos5l` (0.8.0 / klayout 0.30.12)

| Stream | core | top |
|---|---|---|
| repaired | clean, 0 violations | clean, 0 violations |

Reports committed as `layout/sg13cmos5l-bandgap_{core,top}/drc.json`
(input-hash refresh only; coverage identical to the superseded baseline:
same 24 `rules_skipped`, all `no_applicable_geometry`, same rule-free layer
list). The 0.17 µm pSD-to-base-Activ gap the inward widening leaves (0.18 →
0.17 in the thin wall's inner edge) is clean on this deck.

## Files

- `census.py` — the hierarchy walk behind measurement A.
- `reports/census-{superseded,repaired}.txt` — its raw output per stream.
- `reports/erc-population-markerfree-{superseded,repaired}.json` — measurement B.
- `reports/runset-extract-repaired-{nosimplify,defaultsimplify}.json` + `…-nosimplify.cir` — measurement C (each carries its own provenance).
