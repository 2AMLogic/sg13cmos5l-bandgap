# Work Plan

Roadmap generated from GitHub label state by the Guide triage agent. Only the
region between the markers is machine-generated.

<!-- guide:plan-body:start -->
## Operator Attention: Merge-Risk-Hold Pileup

Judge-approved PRs under a hold (`loom:blocked` or `loom:operator`) — only a human merge decision is missing.

- **#95**: feat(design): attest T1 item 1 on a normalized netlist-freshness gate

## Very Important

`loom:very-important` (one counts per workspace); every stage takes these first.

- **#26**: T1 item 1 (design sources): attest the pinned SG13CMOS5L core/amp/startup/top schematics and derived netlists (or migrate them under decision record 0002)

## Important

`loom:important`; taken before unlabelled work.

- **#29**: T1 item 4 (LVS clean): klt lvs of bandgap_top against its schematic netlist, with rppd and pnpMPA gaps attributed
- **#32**: T1 item 7 (post-layout verification): klt pex re-run of the closed-loop row benches on the extracted bandgap_top
- **#94**: README status paragraph says nothing is laid out or extracted, but the layout, DRC and a post-layout extraction are on main

## Ready

Human-approved issues ready for implementation (`loom:issue`).

- **#97**: Remove the ten expired .gitkeep placeholders under the five grid benches' evidence directories

## In Progress

Issues currently being built (`loom:building`).

- **#26**: T1 item 1 (design sources): attest the pinned SG13CMOS5L core/amp/startup/top schematics and derived netlists (or migrate them under decision record 0002)
- **#31**: T1 item 6 (Monte Carlo): closed-loop vref mismatch MC (N >= 300 per point) as klt yield evidence for the untrimmed-line row
- **#93**: Attribute the PSRR @ DC Target miss: operating-point evidence at the failing 2.97 V and 3.30 V points

## PRs Awaiting Review

PRs waiting on Judge (`loom:review-requested`).

_None._

## Approved (Awaiting Merge)

PRs that passed review and are queued for Champion auto-merge (`loom:pr`).

- **#95**: feat(design): attest T1 item 1 on a normalized netlist-freshness gate

## Proposed

Issues carrying `loom:curated`.

- **#26**: T1 item 1 (design sources): attest the pinned SG13CMOS5L core/amp/startup/top schematics and derived netlists (or migrate them under decision record 0002) *(curated)*
- **#31**: T1 item 6 (Monte Carlo): closed-loop vref mismatch MC (N >= 300 per point) as klt yield evidence for the untrimmed-line row *(curated)*
- **#32**: T1 item 7 (post-layout verification): klt pex re-run of the closed-loop row benches on the extracted bandgap_top *(curated)*
- **#93**: Attribute the PSRR @ DC Target miss: operating-point evidence at the failing 2.97 V and 3.30 V points *(curated)*
- **#94**: README status paragraph says nothing is laid out or extracted, but the layout, DRC and a post-layout extraction are on main *(curated)*
- **#99**: Share one deck fixture per distinct supply stimulus: the grid benches' five templates carry three distinct card bodies *(curated)*

## Proposed (Architect / Hermit)

- **#66**: Remove the unread model_files table from sim/pdk.json: fifth copy of the PVT section list, with a host-dependent column *(hermit)*
- **#67**: Remove the tautological --regenerated default from attest/make-item2-envelope.py: the item-2 regeneration claim is true by construction *(hermit)*
- **#81**: Remove the vendored manifests/design-evidence-tiers.md: byte-identical to the checklist bundled in the pinned klayout-tools wheel *(hermit)*
- **#99**: Share one deck fixture per distinct supply stimulus: the grid benches' five templates carry three distinct card bodies *(hermit)*

## Epics

_None._

## Backlog Balance

| Bucket | Count |
|------|-------|
| Operator merge-risk holds | 1 |
| Very important | 1 |
| Important | 3 |
| Ready (`loom:issue`) | 1 |
| In Progress (`loom:building`) | 3 |
| PRs awaiting review | 0 |
| Approved PRs awaiting merge | 1 |
| Curated | 6 |
| Architect / Hermit proposals | 4 |
| Active epics | 0 |
<!-- guide:plan-body:end -->
