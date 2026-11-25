# Work Plan

Roadmap generated from GitHub label state by the Guide triage agent. Only the
region between the markers is machine-generated.

<!-- guide:plan-body:start -->
_Generated: 2026-11-25T21:13:10Z (snapshot; compare against live labels)_
## Operator Attention: Merge-Risk-Hold Pileup

Judge-approved PRs under a hold (`loom:blocked` or `loom:operator`) that require operator attention.

- **#95**: feat(design): attest T1 item 1 on a normalized netlist-freshness gate
- **#161**: docs: add decision record 0019 — the declared spec_rows.5 set is eleven, not nine

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
- **#161**: docs: add decision record 0019 — the declared spec_rows.5 set is eleven, not nine — closes #108

## Proposed

Issues carrying `loom:curated`.

- **#26**: T1 item 1 (design sources): attest the pinned SG13CMOS5L core/amp/startup/top schematics and derived netlists (or migrate them under decision record 0002) *(curated)*
- **#32**: T1 item 7 (post-layout verification): klt pex re-run of the closed-loop row benches on the extracted bandgap_top *(curated)* *(held)*
- **#99**: Share one deck fixture per distinct supply stimulus: the grid benches' five templates carry three distinct card bodies *(curated)* *(held)*
- **#108**: spec: decision record 0011 §5 reports the declared row set as nine; the manifest declares eleven, and the same paragraph implies seven *(curated)*
- **#114**: docs: the closed-loop PSRR worst case is now printed two ways — 55.248 dB in the bench README, 55.249 dB in seven other documents *(curated)* *(held)*
- **#168**: psrr_dc design iteration: bench a candidate amplifier change against the measured mechanism (record 0015) on the 45-point grid, without touching the committed design *(curated)* *(held)*

## Proposed (Architect / Hermit)

_None._

## Epics

_None._

## Backlog Balance

| Bucket | Count |
|------|-------|
| Operator merge-risk holds | 2 |
| Very important | 1 |
| Important | 2 |
| Ready (`loom:issue`, net of holds/building/merge-pending) | 0 |
| In Progress (`loom:building`) | 0 |
| PRs awaiting review | 0 |
| Approved PRs awaiting merge | 2 |
| Curated | 6 |
| Architect / Hermit proposals | 0 |
| Active epics | 0 |
<!-- guide:plan-body:end -->
