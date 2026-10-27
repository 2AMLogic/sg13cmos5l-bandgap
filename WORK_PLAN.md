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

- **#15**: Verify the spec's corner and mismatch model sections resolve at the pinned IHP dev revision

## Ready

Human-approved issues ready for implementation (`loom:issue`).

_None._

## In Progress

Issues currently being built (`loom:building`).

- **#28**: T1 item 3 (DRC clean): klt drc on every bandgap cell and the top with the SG13CMOS5L deck coverage disclosed

## PRs Awaiting Review

PRs waiting on Judge (`loom:review-requested`).

_None._

## Approved (Awaiting Merge)

PRs that passed review and are queued for Champion auto-merge (`loom:pr`).

- **#44**: feat(layout): commit klt drc reports and meet T1 item 3

## Proposed

Issues carrying `loom:curated`.

- **#15**: Verify the spec's corner and mismatch model sections resolve at the pinned IHP dev revision *(curated)*
- **#19**: Record the first closed-loop vref run (sim/closed-loop-vref-pvt/run.sh) on a host with the pinned PDK *(curated)*
- **#26**: T1 item 1 (design sources): attest the pinned SG13CMOS5L core/amp/startup/top schematics and derived netlists (or migrate them under decision record 0002) *(curated)*
- **#28**: T1 item 3 (DRC clean): klt drc on every bandgap cell and the top with the SG13CMOS5L deck coverage disclosed *(curated)*

## Proposed (Architect / Hermit)

- **#37**: Deduplicate sim bench runners: share envelope parsing, tool gates and record writing *(hermit)*

## Epics

_None._

## Backlog Balance

| Bucket | Count |
|------|-------|
| Operator merge-risk holds | 0 |
| Very important | 0 |
| Important | 1 |
| Ready (`loom:issue`) | 0 |
| In Progress (`loom:building`) | 1 |
| PRs awaiting review | 0 |
| Approved PRs awaiting merge | 1 |
| Curated | 4 |
| Architect / Hermit proposals | 1 |
| Active epics | 0 |
<!-- guide:plan-body:end -->
