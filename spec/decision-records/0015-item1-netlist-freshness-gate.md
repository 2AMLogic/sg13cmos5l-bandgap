# 0015: Attest T1 item 1 on a normalized netlist-freshness gate, not a raw byte compare

- **Status**: ratified, effective when the PR for issue #26 merges
- **Date**: 2026-11-14
- **Decided by**: Loom Builder agent, issue #26 (amends [`0006`](0006-migrate-sg13cmos5l-design-sources.md) for the freshness check only; migrates no bytes)

## Context

[`0006`](0006-migrate-sg13cmos5l-design-sources.md) migrated the four SG13CMOS5L
cells and their derived netlists from `2AMLogic/sg13g2-bandgap` at
`52535387e6ccf0a89f6490901a9abb2b78144176` so that T1 item 1 (design sources)
could be attested at all — `klt signoff --attest 1` binds only repo-relative
files and has no pinned-external form. It left item 1 `unmet`, because the
freshness check it declared, `klt netlist --check`, is a **raw byte compare** and
reported `drifted` on all four cells.

Re-measured on this host at this repo's declared pins — xschem **3.4.7**, PDK
`ihp-sg13cmos5l` revision `f7bca32694fe3d58be0cc7d9df4b9f5db7161a14`
(`sim/pdk.json`, resolved and revision-checked by `sim/env.sh`), `klt
0.9.2.dev1022`, netlisted via `klt netlist` from `design/sg13cmos5l/` with
`--rcfile ../xschemrc` — the regenerated export differs from the committed bytes
in exactly two ways, and in no other way at all:

1. **Provenance header comments.** xschem writes `** sch_path:` / `** sym_path:`
   lines carrying the *absolute* path of the generating checkout (here
   `/Users/rwalters/GitHub/sg13g2-bandgap/.loom/worktrees/issue-73/…` and
   `/home/ubuntu/GitHub/sg13g2-bandgap/.loom/worktrees/issue-68/…`), and `klt
   netlist` prepends its own `** klt-netlist-inputs:` line. All three differ on
   every checkout and every tool revision.

2. **`mm_ok=1` on the four classified device models.** The regenerated netlist
   adds one ` mm_ok=1` token to every `sg13_hv_pmos`, `sg13_hv_nmos`, `rppd` and
   `rhigh` instance card (9, 5, 3 and 17 tokens for amp, core, startup and top).
   The committed netlists carry none: they were exported against the **archived**
   PDK revision `607e18d4`, whose symbols did not emit it. `mm_ok` gates the
   per-instance `agauss()` mismatch spread in the PDK's `*_mismatch` model
   sections (`resistors_mod_mismatch.lib`: `nsmm_rsh='agauss(0, 1, (mm_ok != 1 ?
   0 : 1))'`) and is an accepted-but-unused parameter in the non-mismatch sections
   (`resistors_mod.lib`: `.param … mm_ok=0 …`) that every corner this block has
   simulated so far uses.

Two findings that earlier passes recorded as blockers do **not** reproduce and
are closed by this measurement:

- The `bandgap_amp` **subckt port-order** difference (committed `in_p in_n vss
  out vdd` against a regenerated `vdd vss in_p in_n out`) is an xschem 3.4.4 /
  3.4.7 export difference, as @rjwalters ruled on issue #26 on 2026-11-06
  (attended `/fleet:decide` round 20261106-r7 q25, cross-filed
  `sg13g2-bandgap#441`/`#442`). At the fleet-pinned 3.4.7 the two sides are
  identical, including that line.
- `pnpMPA` instances no longer come out as `?`, and there are no blank-line
  differences.

What remains is therefore not a design-source defect. It is a pin mismatch
between the bytes and the installed PDK, and `2AMLogic/sg13g2-bandgap` — which
owns these cells by lineage — has already ruled on it: its **#405** (closed) and
**#406** (merged) *keep* the archived-pin netlists and classify `mm_ok=1` as the
expected delta, explicitly **rejecting** "regenerate the four netlists now
(stales sim evidence, needs a re-run that #322 defers)". Regeneration lives in
that repo's **#322**.

This repo cannot regenerate them either, for a second independent reason:

- every item-5 envelope's record names `source_file_sha256:
  a29624d3bbcc…` for `design/sg13cmos5l/netlist/bandgap_top.spice` and a
  `staged_dut_sha256` derived from it, so the block's whole corner-verification
  evidence chain would cite bytes no longer in the repo; and
- `sim/tests/test-pex-device-inventory.sh` hard-compares that file against the
  committed item-7 record's `schematic_dut.sha256`, so CI would go red until a
  fresh `klt pex` run and five re-run PVT grids landed.

Trading a graded, documented, classified delta for an unevidenced netlist and a
red CI run is the wrong trade, and making it is not this issue's call.

## Decision

T1 item 1's declared freshness check is **`design/check-netlist-freshness.sh`**,
one invocation per cell, declared `local_only` in `attest/item1.json`. It
re-exports the committed schematic with `klt netlist` (never a raw `xschem`) and
compares the result against the committed netlist through
`design/tools/netlist_pin_delta.py`, which normalizes **exactly** the two
differences established above and nothing else:

- drops the three provenance comment kinds `** sch_path:`, `** sym_path:` and
  `** klt-netlist-inputs:`;
- removes a single ` mm_ok=1` token, and only at that literal value, and only
  from an `X…` instance card naming one of `sg13_hv_nmos`, `sg13_hv_pmos`,
  `rppd`, `rhigh`. Removal is symmetric and the per-side token counts are
  reported, so the tolerance that was applied is visible in the check output and
  in the attestation envelope.

Every other byte is compared verbatim: every device card, model name, net name,
device size, multiplier and body-tie parameter, every `.subckt` and `**.subckt`
port list, every `*.iopin` declaration, every blank line and every other
comment. `mm_ok=0`, `mm_ok=2`, or `mm_ok=1` on any other model — `pnpMPA` above
all, the device this block's accuracy actually turns on — is drift, not a
tolerated delta.

`design/tests/test-netlist-pin-delta.sh` holds the negative controls that keep
that true (a resize, a deleted device, a renamed net, a changed multiplier, a
reordered port list, an added blank line, an added non-provenance comment,
`mm_ok` at the wrong value or on the wrong model), plus a re-derivation from the
committed netlists that they still carry no `mm_ok` token at all — the premise
the whole normalization rests on. It needs only bash and python3, so CI runs it
on every push even though the gate itself cannot run there.

`attest/item1.json` lists `design/check-netlist-freshness.sh` and
`design/tools/netlist_pin_delta.py` among its `sources`, so item 1's binding
hashes the predicate itself: the tolerance cannot be widened without
re-attesting and re-pinning the manifest.

No design byte is edited, no netlist is regenerated, no pin is bumped, and no
spec row changes.

## Alternatives considered

- **Regenerate the four netlists at this repo's PDK pin.** This is the only route
  to a passing raw `klt netlist --check`, and [`0006`](0006-migrate-sg13cmos5l-design-sources.md)
  left the door open to it ("until the source regenerates (or this repo does,
  under a new record)"). Rejected: `sg13g2-bandgap` #405/#406 ratified the
  opposite and deferred regeneration to its #322; and it would orphan every
  item-5 envelope's `source_file_sha256` and break
  `sim/tests/test-pex-device-inventory.sh` against the item-7 record, costing a
  fresh `klt pex` run and five re-run PVT grids to restore — all to satisfy a
  gate, with no design change behind it.
- **Keep `klt netlist --check` and leave item 1 `unmet`.** Rejected: at the 0.8.0
  pin `--attest` writes **no envelope** when a check fails (exit 3, nothing
  written), so the item would stay `no_evidence` — it could not even be cited
  the way the failing `psrr_dc` row and the item-7 `klt pex` report are. A check
  that does run, and whose one tolerance is named and bounded, is strictly more
  informative than no evidence at all.
- **`klt netlist --check --ignore-comments`.** Rejected: it removes difference 1
  but not difference 2, so it still exits 3 — and it drops *all* comment lines,
  including the `**.subckt` line that carries the top block's port order, which
  is precisely the line the xschem-version finding above turned on. The gate here
  drops three named comment kinds and keeps that one.
- **A `recorded` freshness record** (`derived_sha256` plus per-source digests)
  instead of a `check` command. Rejected: it re-hashes files and runs nothing, so
  it would assert that these derived bytes accompany these source bytes without
  ever re-exporting the schematic — weaker than what a provisioned host can
  actually prove, and it would have made both differences above invisible rather
  than classified.
- **Hand-edit the committed netlists' header paths.** Rejected: editing generated
  files, forbidden by [`0006`](0006-migrate-sg13cmos5l-design-sources.md), and it
  would not address `mm_ok` anyway.

## Consequences

- **T1 item 1 grades `met`**: `evidence/item1.json` (18/18 attestation checks
  passed, all four freshness checks actually executed on a provisioned host, not
  skipped) is cited in `manifests/sg13cmos5l-bandgap.json` with the inventory's
  `content_hash`, and `manifests/sg13cmos5l-bandgap.signoff.json` moves from 4 to
  **5 of 11** T1 items met.
- **It is `met` on a normalized gate, and the report says so.** Anyone reading
  the manifest sees the `_comment` entry naming the two tolerated differences and
  pointing here; anyone running the check sees the tolerated token counts. This
  is not a claim that the committed netlists are what this repo's PDK pin
  produces — they are not, and `mm_ok` is the difference.
- **The `mm_ok` question stays open upstream, where it belongs**:
  `sg13g2-bandgap` #322. If that regeneration lands and is migrated here under a
  new record, the normalization's `mm_ok` leg becomes a no-op; the premise check
  in `design/tests/test-netlist-pin-delta.sh` fails at that point rather than
  letting it quietly become decorative, which is the signal to retire it.
- **Mismatch Monte Carlo (issue #31, T1 item 6) must settle `mm_ok` explicitly.**
  `mm_ok=1` is what *enables* per-instance mismatch in the PDK's `*_mismatch`
  sections, and the committed netlists do not carry it. A mismatch bench built on
  these bytes would therefore run with mismatch disabled on every MOS and
  resistor, and silently report a spread that is bipolar-only. That is a bench
  precondition, not a freshness question, and it is recorded here because this is
  where the fact was measured.
- **At the klt 0.8.0 pin the manifest `content_hash` is the inventory's own
  sha256**, not an item-1 input-set digest (set binding ships after 0.8.0), so a
  schematic edit does not by itself change the manifest pin. The CI
  `klt signoff --attest 1 --inventory attest/item1.json --check evidence/item1.json`
  step is what catches it — verified: appending one byte to
  `design/sg13cmos5l/bandgap_amp.sch` makes that step report `drifted` and exit 3.
  This is the same division of labour item 9 already relies on.
- **CI gains two steps** in `.github/workflows/signoff.yml`: the PDK-free
  negative-control suite, and the item-1 attestation drift check. The four
  freshness commands are `local_only` and are listed as `[SKIP]` with their
  committed outcome carried, so a green CI run does **not** re-prove the
  re-export; only a provisioned host's `--attest` does.
