# Work Plan

Roadmap generated from GitHub label state by the Guide triage agent. Only the
region between the markers is machine-generated.

<!-- guide:plan-body:start -->
## Operator Attention: Merge-Risk-Hold Pileup

Judge-approved PRs under a hold (`loom:blocked` or `loom:operator`) — only a human merge decision is missing.

- **#95**: feat(design): attest T1 item 1 on a normalized netlist-freshness gate
- **#120**: sim: re-take the vref-mc campaign on the wrapped-DUT staging; fix its internal-node probes
- **#133**: chore(loom): resync installed Loom to v0.19.1302

## Very Important

`loom:very-important` (one counts per workspace); every stage takes these first.

- **#26**: T1 item 1 (design sources): attest the pinned SG13CMOS5L core/amp/startup/top schematics and derived netlists (or migrate them under decision record 0002)

## Important

`loom:important`; taken before unlabelled work.

- **#29**: T1 item 4 (LVS clean): klt lvs of bandgap_top against its schematic netlist, with rppd and pnpMPA gaps attributed
- **#32**: T1 item 7 (post-layout verification): klt pex re-run of the closed-loop row benches on the extracted bandgap_top

## Ready

Human-approved issues ready for implementation (`loom:issue`).

- **#123**: spec: two decision records now claim the number 0016; record-number uniqueness is unguarded after five renumbers

## In Progress

Issues currently being built (`loom:building`).

_None._

## PRs Awaiting Review

PRs waiting on Judge (`loom:review-requested`).

_None._

## Approved (Awaiting Merge)

PRs that passed review and are queued for Champion auto-merge (`loom:pr`).

- **#95**: feat(design): attest T1 item 1 on a normalized netlist-freshness gate
- **#120**: sim: re-take the vref-mc campaign on the wrapped-DUT staging; fix its internal-node probes
- **#133**: chore(loom): resync installed Loom to v0.19.1302

## Proposed

Issues carrying `loom:curated`.

- **#26**: T1 item 1 (design sources): attest the pinned SG13CMOS5L core/amp/startup/top schematics and derived netlists (or migrate them under decision record 0002) *(curated)*
- **#32**: T1 item 7 (post-layout verification): klt pex re-run of the closed-loop row benches on the extracted bandgap_top *(curated)*
- **#99**: Share one deck fixture per distinct supply stimulus: the grid benches' five templates carry three distinct card bodies *(curated)*
- **#115**: Re-take the closed-loop-vref-mc campaign on the wrapped-DUT staging (post-#83/#84 arrangement) *(curated)*
- **#123**: spec: two decision records now claim the number 0016; record-number uniqueness is unguarded after five renumbers *(curated)*

## Proposed (Architect / Hermit)

- **#66**: Remove the unread model_files table from sim/pdk.json: fifth copy of the PVT section list, with a host-dependent column *(hermit)*
- **#67**: Remove the tautological --regenerated default from attest/make-item2-envelope.py: the item-2 regeneration claim is true by construction *(hermit)*
- **#81**: Remove the vendored manifests/design-evidence-tiers.md: byte-identical to the checklist bundled in the pinned klayout-tools wheel *(hermit)*

## Epics

_None._

## Backlog Balance

| Bucket | Count |
|------|-------|
| Operator merge-risk holds | 3 |
| Very important | 1 |
| Important | 2 |
| Ready (`loom:issue`) | 1 |
| In Progress (`loom:building`) | 0 |
| PRs awaiting review | 0 |
| Approved PRs awaiting merge | 3 |
| Curated | 5 |
| Architect / Hermit proposals | 3 |
| Active epics | 0 |
<!-- guide:plan-body:end -->
