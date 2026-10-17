# spec

Ratified specification, decision records and the porting plan for this block.

| File | What it is |
|---|---|
| [`porting-plan.md`](porting-plan.md) | Sibling commits read (full SHAs), what is inherited, what is re-derived, open questions |
| [`target-spec.md`](target-spec.md) | The target table: every row with target, fallback, stretch, binding conditions, planned testbench and evidence status |
| [`decision-records/`](decision-records/) | One record per spec change, numbered `NNNN-<slug>.md` |

Decision records:

- [`0001-target-spec-ratification.md`](decision-records/0001-target-spec-ratification.md): ratifies the table in `target-spec.md`
- [`0002-sg13g2-bandgap-branch-reuse.md`](decision-records/0002-sg13g2-bandgap-branch-reuse.md): the SG13CMOS5L branch is pinned in `/reuse.lock.json`, not migrated

Rules: spec changes go through a decision record; a ratified record is
superseded, never rewritten; no row is relaxed to make a result pass.
