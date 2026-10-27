# 0007: Migrate the SG13CMOS5L layout generators and GDS so T1 item 2 can be graded

- **Status**: ratified, effective when the PR for issue #27 merges
- **Date**: 2026-10-27
- **Decided by**: Loom Builder agent, issue #27 (amends 0002 for these files only; sibling of 0006)

## Context

Decision record 0002 pins `layout/sg13cmos5l-*` in `2AMLogic/sg13g2-bandgap`
and copies nothing. T1 item 2 (Layout) is graded on a committed stream hashed
in an envelope; a stream that exists only at an external pin cannot be bound.
0002 anticipated this: a cell that must move migrates under a new record naming
the commit. Record 0006 did the same for the design sources.

## Decision

Migrate the files below from `2AMLogic/sg13g2-bandgap` at
`52535387e6ccf0a89f6490901a9abb2b78144176`, byte for byte, unedited. Each blob
SHA-1 was checked with `git hash-object` against the source tree at that
commit.

| Path | blob SHA-1 (first 12) | SHA-256 (first 12) |
|---|---|---|
| `layout/_klayout_builder_base.py` | `5d498d219f74` | `211d250b4ef9` |
| `layout/common_sg13cmos5l.py` | `407035a7ab76` | `e61a28a0d0b5` |
| `layout/sg13cmos5l-bandgap_amp/generate.py` | `48d1c172d358` | `80e9cf04e84c` |
| `layout/sg13cmos5l-bandgap_amp/sg13cmos5l-bandgap_amp.gds` | `d8fc871fdc48` | `f277d9855772` |
| `layout/sg13cmos5l-bandgap_core/generate.py` | `7be71845e0fd` | `b77fe248a90a` |
| `layout/sg13cmos5l-bandgap_core/sg13cmos5l-bandgap_core.gds` | `c7c9471cde01` | `832b570e7d10` |
| `layout/sg13cmos5l-bandgap_startup/generate.py` | `5056bd19125c` | `c52859df84df` |
| `layout/sg13cmos5l-bandgap_startup/sg13cmos5l-bandgap_startup.gds` | `0b91085e34e5` | `a18f8c052af3` |
| `layout/sg13cmos5l-bandgap_top/generate.py` | `4584cce223ad` | `53ca227441bd` |
| `layout/sg13cmos5l-bandgap_top/sg13cmos5l-bandgap_top.gds` | `5de09c753f1d` | `4e4e4f85fa08` |

`_klayout_builder_base.py` is added to the list in `reuse.lock.json` because
every generator imports it through `common_sg13cmos5l.py`; the source's
`layout/common.py` is not imported by these cells and is not migrated.

**Stays pinned** (per 0002): the source's per-cell DRC, LVS, extraction and ERC
reports and reference/extracted netlists under `layout/sg13cmos5l-*`. They were
produced on the archived standalone PDK pin, not this repo's, so they are not
evidence here; DRC, LVS and PEX are issues #28, #29 and #32. The commit pin is
unchanged; no bump.

New in this repo, derived from the migrated stream: `layout/area.json` (`klt
stats` of the top GDS; bounding box 248.0 × 135.514 µm = 33 607.5 µm²,
layout-derived), `evidence/item2.json` and `attest/make-item2-envelope.py`
(klayout-tools 0.8.0 has no item-2 envelope verb). The Area row of
`spec/target-spec.md` points at `layout/README.md` for the number; it sets no
budget and stays `target-only`.

## Alternatives considered

- **Cite a GDS fetched at run time from the pin.** Rejected: the grader needs
  an in-repo stream.
- **Redraw the cells.** Rejected: violates "designed once".
- **Migrate the source's reports too.** Rejected: stale-PDK evidence with no
  claim here, and out of scope for item 2.

## Consequences

- Regeneration needs only `klayout` (python); the four streams reproduced
  byte-identically on a fresh run, so the envelope's regeneration claim holds.
- The source's cells predate this repo's spec; nothing about them is claimed to
  meet a row beyond "a committed, reproducible stream exists".
- Findings on the generators are filed on `sg13g2-bandgap`. Bumping or
  re-migrating needs a record naming old and new commit.
