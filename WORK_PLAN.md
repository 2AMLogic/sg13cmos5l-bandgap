# Work Plan

Roadmap generated from GitHub label state by the Guide triage agent. Only the
region between the markers is machine-generated.

<!-- guide:plan-body:start -->
_Generated: 2026-11-21T00:11:50Z (snapshot; compare against live labels)_
## Operator Attention: Merge-Risk-Hold Pileup

Judge-approved PRs under a hold (`loom:blocked` or `loom:operator`) — only a human merge decision is missing.

- **#95**: feat(design): attest T1 item 1 on a normalized netlist-freshness gate
- **#161**: docs: add decision record 0019 — the declared spec_rows.5 set is eleven, not nine

## Very Important

`loom:very-important` (one counts per workspace); every stage takes these first.

- **#26**: T1 item 1 (design sources): attest the pinned SG13CMOS5L core/amp/startup/top schematics and derived netlists (or migrate them under decision record 0002)

## Important

`loom:important`; taken before unlabelled work.

- **#29**: T1 item 4 (LVS clean): klt lvs of bandgap_top against its schematic netlist, with rppd and pnpMPA gaps attributed *(held)*
- **#32**: T1 item 7 (post-layout verification): klt pex re-run of the closed-loop row benches on the extracted bandgap_top

## Ready

Human-approved issues (`loom:issue`) ready for implementation — excluding held (`loom:blocked`/`loom:operator`/`loom:frozen`), `loom:building`, and issues closed by an open `loom:pr` PR (listed under Approved).

- **#172**: Dangling cross-reference: layout/README.md has no "SG13CMOS5L layer numbers" section

## In Progress

Issues currently being built (`loom:building`).

- **#108**: spec: decision record 0011 §5 reports the declared row set as nine; the manifest declares eleven, and the same paragraph implies seven
- **#166**: Scratch probe: does bandgap_top without the ten pnpMPA base-ring nSD shapes derive pnpMPA on the PDK runset and still grade its base tie? (decision record 0018 reopen condition)
- **#168**: psrr_dc design iteration: bench a candidate amplifier change against the measured mechanism (record 0015) on the 45-point grid, without touching the committed design
- **#170**: pnpMPA base rings carry zero contacts: the base tie does not exist as drawn (draw_pnpmpa cont_array underflow at w=1u l=2u)

## PRs Awaiting Review

PRs waiting on Judge (`loom:review-requested`).

- **#171**: measure: pnpMPA base-tie probe — ring-free runset recognition succeeds; base rings carry zero contacts (#166)

## Approved (Awaiting Merge)

PRs that passed review and are queued for Champion auto-merge (`loom:pr`).

- **#95**: feat(design): attest T1 item 1 on a normalized netlist-freshness gate — closes #26
- **#161**: docs: add decision record 0019 — the declared spec_rows.5 set is eleven, not nine — closes #108

## Proposed

Issues carrying `loom:curated`.

- **#26**: T1 item 1 (design sources): attest the pinned SG13CMOS5L core/amp/startup/top schematics and derived netlists (or migrate them under decision record 0002) *(curated)*
- **#32**: T1 item 7 (post-layout verification): klt pex re-run of the closed-loop row benches on the extracted bandgap_top *(curated)*
- **#99**: Share one deck fixture per distinct supply stimulus: the grid benches' five templates carry three distinct card bodies *(curated)* *(held)*
- **#108**: spec: decision record 0011 §5 reports the declared row set as nine; the manifest declares eleven, and the same paragraph implies seven *(curated)*
- **#114**: docs: the closed-loop PSRR worst case is now printed two ways — 55.248 dB in the bench README, 55.249 dB in seven other documents *(curated)* *(held)*
- **#166**: Scratch probe: does bandgap_top without the ten pnpMPA base-ring nSD shapes derive pnpMPA on the PDK runset and still grade its base tie? (decision record 0018 reopen condition) *(curated)*
- **#168**: psrr_dc design iteration: bench a candidate amplifier change against the measured mechanism (record 0015) on the 45-point grid, without touching the committed design *(curated)*
- **#170**: pnpMPA base rings carry zero contacts: the base tie does not exist as drawn (draw_pnpmpa cont_array underflow at w=1u l=2u) *(curated)*
- **#172**: Dangling cross-reference: layout/README.md has no "SG13CMOS5L layer numbers" section *(curated)*

## Proposed (Architect / Hermit)

- **#66**: Remove the unread model_files table from sim/pdk.json: fifth copy of the PVT section list, with a host-dependent column *(hermit)* *(held)*
- **#67**: Remove the tautological --regenerated default from attest/make-item2-envelope.py: the item-2 regeneration claim is true by construction *(hermit)* *(held)*
- **#81**: Remove the vendored manifests/design-evidence-tiers.md: byte-identical to the checklist bundled in the pinned klayout-tools wheel *(hermit)* *(held)*

## Epics

_None._

## Backlog Balance

| Bucket | Count |
|------|-------|
| Operator merge-risk holds | 2 |
| Very important | 1 |
| Important | 2 |
| Ready (`loom:issue`, net of holds/building/merge-pending) | 1 |
| In Progress (`loom:building`) | 4 |
| PRs awaiting review | 1 |
| Approved PRs awaiting merge | 2 |
| Curated | 9 |
| Architect / Hermit proposals | 3 |
| Active epics | 0 |
<!-- guide:plan-body:end -->
