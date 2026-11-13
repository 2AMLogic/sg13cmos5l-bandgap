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
- **#30**: T1 item 5 (corner verification): 45-point closed-loop benches for the nominal, TC (box and endpoint), PSRR, Iq and startup rows as klt sim envelopes

## Ready

Human-approved issues ready for implementation (`loom:issue`).

_None._

## In Progress

Issues currently being built (`loom:building`).

- **#30**: T1 item 5 (corner verification): 45-point closed-loop benches for the nominal, TC (box and endpoint), PSRR, Iq and startup rows as klt sim envelopes

## PRs Awaiting Review

PRs waiting on Judge (`loom:review-requested`).

_None._

## Approved (Awaiting Merge)

PRs that passed review and are queued for Champion auto-merge (`loom:pr`).

_None._

## Proposed

Issues carrying `loom:curated`.

- **#26**: T1 item 1 (design sources): attest the pinned SG13CMOS5L core/amp/startup/top schematics and derived netlists (or migrate them under decision record 0002) *(curated)*
- **#30**: T1 item 5 (corner verification): 45-point closed-loop benches for the nominal, TC (box and endpoint), PSRR, Iq and startup rows as klt sim envelopes *(curated)*
- **#47**: Run sim/smoke/run_smoke.sh once on a toolchain host and diff record keys after runner-lib refactor *(curated)*

## Proposed (Architect / Hermit)

- **#61**: Single source for the §PVT corner table: run.sh and check-model-sections.py each hand-copy it *(hermit)*
- **#64**: Remove fetch-era leftovers from the closed-loop vref runner: dead gh gate, scratch copy, stale DUT wording *(hermit)*
- **#66**: Remove the unread model_files table from sim/pdk.json: fifth copy of the PVT section list, with a host-dependent column *(hermit)*
- **#67**: Remove the tautological --regenerated default from attest/make-item2-envelope.py: the item-2 regeneration claim is true by construction *(hermit)*
- **#70**: Remove template-era .gitignore rules for flow/, cocotb, a sim harness and per-corner logs that this repo does not have *(hermit)*
- **#71**: Wire package.json test/check:ci to the four sim/tests suites: the Loom-template stubs report 'No tests configured' and exit 0 *(hermit)*

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
| Curated | 3 |
| Architect / Hermit proposals | 6 |
| Active epics | 0 |
<!-- guide:plan-body:end -->
