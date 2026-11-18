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

- **#29**: T1 item 4 (LVS clean): klt lvs of bandgap_top against its schematic netlist, with rppd and pnpMPA gaps attributed *(held)*
- **#32**: T1 item 7 (post-layout verification): klt pex re-run of the closed-loop row benches on the extracted bandgap_top *(held)*

## Ready

Human-approved issues (`loom:issue`) ready for implementation — excluding held (`loom:blocked`/`loom:operator`/`loom:frozen`), `loom:building`, and issues closed by an open `loom:pr` PR (listed under Approved).

_None._

## In Progress

Issues currently being built (`loom:building`).

_None._

## PRs Awaiting Review

PRs waiting on Judge (`loom:review-requested`).

_None._

## Approved (Awaiting Merge)

PRs that passed review and are queued for Champion auto-merge (`loom:pr`).

- **#95**: feat(design): attest T1 item 1 on a normalized netlist-freshness gate — closes #26

## Proposed

Issues carrying `loom:curated`.

- **#26**: T1 item 1 (design sources): attest the pinned SG13CMOS5L core/amp/startup/top schematics and derived netlists (or migrate them under decision record 0002) *(curated)*
- **#32**: T1 item 7 (post-layout verification): klt pex re-run of the closed-loop row benches on the extracted bandgap_top *(curated)* *(held)*
- **#99**: Share one deck fixture per distinct supply stimulus: the grid benches' five templates carry three distinct card bodies *(curated)* *(held)*

## Proposed (Architect / Hermit)

- **#66**: Remove the unread model_files table from sim/pdk.json: fifth copy of the PVT section list, with a host-dependent column *(hermit)* *(held)*
- **#67**: Remove the tautological --regenerated default from attest/make-item2-envelope.py: the item-2 regeneration claim is true by construction *(hermit)* *(held)*
- **#81**: Remove the vendored manifests/design-evidence-tiers.md: byte-identical to the checklist bundled in the pinned klayout-tools wheel *(hermit)* *(held)*

## Epics

_None._

## Backlog Balance

| Bucket | Count |
|------|-------|
| Operator merge-risk holds | 1 |
| Very important | 1 |
| Important | 2 |
| Ready (`loom:issue`, net of holds/building/merge-pending) | 0 |
| In Progress (`loom:building`) | 0 |
| PRs awaiting review | 0 |
| Approved PRs awaiting merge | 1 |
| Curated | 3 |
| Architect / Hermit proposals | 3 |
| Active epics | 0 |
<!-- guide:plan-body:end -->
