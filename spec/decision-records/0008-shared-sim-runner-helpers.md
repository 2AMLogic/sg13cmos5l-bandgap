# 0008: Share the sim bench runner skeleton; leave record shapes alone

- **Status**: ratified, effective when the PR for issue #37 merges
- **Date**: 2026-10-27
- **Decided by**: Loom Builder agent, issue #37

## Context

`sim/smoke/run_smoke.sh` and `sim/closed-loop-vref-pvt/run.sh` carried two
copies of the tool gate, the ngspice >= 43 gate, the klt-envelope value walk
and the append-only record write. Issue #30 plans five more benches. The two
records also differ in shape (`pdk.revision` vs top-level `pdk_revision` plus
`pdk.pin_file`), and the smoke runner aborts on a `klt` failure without a
record while the closed-loop runner writes a failed one.

## Decision

- Move the shared mechanics into `sim/runner-lib.sh` (sourced: `cm5_gate`,
  `cm5_osdi_gate`, `cm5_record_path`) and `sim/tools/cm5_record.py`
  (`collect`, `sha256`, `klt_version`, `write_record`). Both runners use them.
- **Record shapes are unchanged.** Existing `sim/*/records/` are append-only
  evidence and are not edited; both runners still build their own record dict,
  with the same keys and values as before. The refactor changes no gate, exit
  code (3/4/5/6) or message text other than the runner tag already in use.
- **No unified schema yet.** A silent unification would make new records
  differ from committed ones. New benches under #30 use the helpers and, when
  the first of them lands, a successor record defines the common shape with a
  `schema_version` field (absent = the two legacy shapes above). Until then
  consumers of `sim/*/records/` must accept both legacy shapes.
- The smoke runner's no-record-on-klt-failure behaviour is kept; changing it
  changes what the runner writes and belongs with the unified schema.

## Alternatives considered

- **Unify the schema in this change.** Rejected: alters the record shape and
  needs a version field consumers do not yet read.
- **One mega-runner parameterised by bench.** Rejected: the benches differ in
  deck assembly, corner bundle and pass criteria; only the plumbing is shared.

## Consequences

- A new bench adds no copy of the gates or the exclusive write.
- Verified with `bash sim/tests/test-runner-lib.sh` (stub tools) and shellcheck.
  A local single-corner smoke run was not possible on this host (ngspice 42,
  no pinned SG13CMOS5L PDK), so the end-to-end runs remain unexercised here;
  the record dict construction is byte-for-byte untouched in the diff.
