# Work Plan

Roadmap generated from GitHub label state by the Guide triage agent. Only the
region between the markers is machine-generated.

<!-- guide:plan-body:start -->
## Operator Attention: Merge-Risk-Hold Pileup

Judge-approved PRs under a hold (`loom:blocked` or `loom:operator`) — only a human merge decision is missing.

_None._

## Very Important

`loom:very-important` (one counts per workspace); every stage takes these first.

_None._

## Important

`loom:important`; taken before unlabelled work.

- **#26**: T1 item 1 (design sources): attest the pinned SG13CMOS5L core/amp/startup/top schematics and derived netlists (or migrate them under decision record 0002)
- **#32**: T1 item 7 (post-layout verification): klt pex re-run of the closed-loop row benches on the extracted bandgap_top

## Ready

Human-approved issues ready for implementation (`loom:issue`).

_None._

## In Progress

Issues currently being built (`loom:building`).

- **#31**: T1 item 6 (Monte Carlo): closed-loop vref mismatch MC (N >= 300 per point) as klt yield evidence for the untrimmed-line row

## PRs Awaiting Review

PRs waiting on Judge (`loom:review-requested`).

_None._

## Approved (Awaiting Merge)

PRs that passed review and are queued for Champion auto-merge (`loom:pr`).

_None._

## Proposed

Issues carrying `loom:curated`.

- **#26**: T1 item 1 (design sources): attest the pinned SG13CMOS5L core/amp/startup/top schematics and derived netlists (or migrate them under decision record 0002) *(curated)*
- **#31**: T1 item 6 (Monte Carlo): closed-loop vref mismatch MC (N >= 300 per point) as klt yield evidence for the untrimmed-line row *(curated)*
- **#32**: T1 item 7 (post-layout verification): klt pex re-run of the closed-loop row benches on the extracted bandgap_top *(curated)*
- **#47**: Run sim/smoke/run_smoke.sh once on a toolchain host and diff record keys after runner-lib refactor *(curated)*

## Proposed (Architect / Hermit)

- **#66**: Remove the unread model_files table from sim/pdk.json: fifth copy of the PVT section list, with a host-dependent column *(hermit)*
- **#67**: Remove the tautological --regenerated default from attest/make-item2-envelope.py: the item-2 regeneration claim is true by construction *(hermit)*
- **#81**: Remove the vendored manifests/design-evidence-tiers.md: byte-identical to the checklist bundled in the pinned klayout-tools wheel *(hermit)*

## Epics

_None._

## Backlog Balance

| Bucket | Count |
|------|-------|
| Operator merge-risk holds | 0 |
| Very important | 0 |
| Important | 2 |
| Ready (`loom:issue`) | 0 |
| In Progress (`loom:building`) | 1 |
| PRs awaiting review | 0 |
| Approved PRs awaiting merge | 0 |
| Curated | 4 |
| Architect / Hermit proposals | 3 |
| Active epics | 0 |
<!-- guide:plan-body:end -->
