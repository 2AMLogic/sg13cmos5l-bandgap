# design

Design sources for the SG13CMOS5L bandgap. `xschemrc` and `sg13cmos5l/`
(`*.sch`, `*.sym`, `netlist/*.spice`) are migrated unedited from
`2AMLogic/sg13g2-bandgap` at the commit named in
[`spec/decision-records/0006-migrate-sg13cmos5l-design-sources.md`](../spec/decision-records/0006-migrate-sg13cmos5l-design-sources.md);
`reuse.lock.json` lists them under `mode: "migrate"`. Everything else
(including `sg13cmos5l/README.md`) stays pinned there. Do not edit migrated
files without a decision record.

Re-run the freshness check from `design/sg13cmos5l/` with the pinned PDK
(`PDK_ROOT`, `PDK=ihp-sg13cmos5l`):

```bash
klt netlist bandgap_top.sch -o netlist/bandgap_top.spice --rcfile ../xschemrc --check
```

It currently reports `drifted` on all four cells; see the record's Consequences.
