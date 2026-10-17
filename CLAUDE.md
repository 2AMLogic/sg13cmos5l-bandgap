# sg13cmos5l-bandgap — agent instructions

Open-source canary block: a CMOS bandgap voltage reference on IHP
SG13CMOS5L, the CMOS-only reduced-metal-stack sibling of SG13G2, designed
and verified by AI agents. A port of `sg13g2-bandgap`.

- **PDK**: IHP SG13CMOS5L (open PDK, IHP-GmbH/IHP-Open-PDK). Open-source
  flow: xschem + ngspice for design/sim, klayout-tools (`klt`) for layout,
  DRC, LVS and extraction. The shared MOS, `pnpMPA` and resistor symbols and
  models link into the SG13G2 tree, so an SG13CMOS5L-only install has
  dangling links; install inside a combined IHP-Open-PDK checkout and pin
  the release you use.
- **The PDK is the variable, not the design.** Start from
  `sg13g2-bandgap`'s SG13CMOS5L branch (`spec/porting-plan-sg13cmos5l.md`,
  decision records 0004/0005, `design/sg13cmos5l/`, `sim/sg13cmos5l-*`,
  `layout/sg13cmos5l-*`) and from the gf180/sky130 bandgaps' parasitic-PNP
  precedent. Anything that breaks should be assumed to be the PDK, the deck
  or the tools before it is assumed to be the circuit.
- **The central risk is the bipolar device and the capacitors.** With no
  HBT, the core runs on `pnpMPA`, whose current gain is near unity: base
  current is a first-order error term in every accuracy budget, not a
  correction. With no MIM, compensation uses MoM or MOS capacitors, and the
  MoM models carry no corner or mismatch spread — any row whose evidence
  depends on that spread is `insufficient-evidence`, not a pass.
- **Scope discipline: designed once.** `sg13g2-bandgap` is the master by
  lineage. Do not redesign what its SG13CMOS5L branch already carries; take
  it by a pinned reference (`reuse.lock.json`, a pushed 40-hex commit) or
  migrate it with a decision record that says what moved and from which
  commit. `spec/porting-plan.md` names the commit of every sibling read.
  Findings that bear on the source (a defect, a model fact) are filed on
  `sg13g2-bandgap`.
- **Friction protocol (the canary's job)**: every time klayout-tools is
  awkward, missing a capability, or wrong for what you need, file an issue at
  `2AMLogic/klayout-tools` describing the tool gap generically — that tracker
  is scoped to the tool, so keep design-specific detail out of it and describe
  the gap, not the design. The SG13CMOS5L deck is starter-grade; an LVS
  device it cannot extract is friction to file, not a reason to waive.
- **Verification is the product**: no claim without a testbench. PVT corners
  on every recorded result; `sim/` results are append-only evidence. Every
  simulated figure is labelled as simulated, with its corner and testbench.
- Spec changes go through `spec/` with a decision record; agents do not relax
  the ratified spec to make results pass.
