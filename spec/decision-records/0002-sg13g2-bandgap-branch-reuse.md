# 0002: Pin the SG13CMOS5L branch of sg13g2-bandgap; do not migrate it

- **Status**: ratified, effective when the PR for issue #2 merges
- **Date**: 2026-10-17
- **Decided by**: Loom Builder agent, issue #2

## Context

`sg13g2-bandgap` carries the SG13CMOS5L core, amplifier, startup, top, four
benches and four layout cells (paths in [`porting-plan.md`](../porting-plan.md)).
The block is to be designed once. Either the branch moves here (with a record
naming the commit) or it stays there and is pinned here. Moving or freezing the
source is coordinated on `sg13g2-bandgap`, not assumed.

## Decision

**Pin.** [`/reuse.lock.json`](../../reuse.lock.json) names
`2AMLogic/sg13g2-bandgap` at `52535387e6ccf0a89f6490901a9abb2b78144176`
(first read at `e936e1653655197319e5765f6f59aa0da970bb5d`, which differs only
in Loom resync and work-log files) and the paths this repo takes from it.
Nothing is copied into this repo yet.

A design issue that must change a cell migrates **that cell** with a new record
that names the source commit, what moved, and what stays pinned. Bumping the
pin needs a record naming old and new commit.

The source is not frozen by this record. The note to `sg13g2-bandgap` is a
pointer: this repo reads that branch at the commit above, so edits to
`design/sg13cmos5l/` there change what a bump would bring in. Findings that
bear on the source are filed there.

## Alternatives considered

- **Migrate now.** Rejected: it forks the master before any SG13CMOS5L-specific
  change exists and creates a second copy to keep in sync.
- **Freeze the source branch.** Rejected: needs agreement on `sg13g2-bandgap`
  and gains nothing while pinned by commit.

## Consequences

- No design files appear in this repo until a design issue needs to change one.
- Evidence under the source's `sim/sg13cmos5l-*` was generated on the archived
  standalone PDK pin `607e18d4…`, not the `dev` pin (source
  `sim/pdk-sg13cmos5l.json`). It is cited with that pin, and is not evidence
  for this repo's PDK pin until #4 and a re-run say so.
- The source's SG13CMOS5L cells predate the spec here; nothing about them is
  claimed to meet a row.
