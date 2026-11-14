# 0015: Grid benches on an identical supply stimulus share one deck fixture

- **Status**: ratified, effective when the PR for issue #99 merges
- **Amends**: decision record
  [`0011`](0011-corner-verification-pvt-grids.md) §6 ("the five benches differ
  only in a deck template, a request file and a criteria string — all three
  data in the bench directory") and decision record
  [`0014`](0014-substrate-net-global.md) Decision §1 (the five-template
  enumeration). Neither record's text is rewritten; both amendments narrow an
  enumeration, not what is attested.
- **Date**: 2026-11-14
- **Decided by**: Loom Curator proposal, Champion-approved (issue #99);
  implemented by the Loom Builder agent

## Context

Decision record 0011 §6 superseded 0008's "one mega-runner" rejection on the
premise that the five item-5 benches "differ only in a deck template, a request
file and a criteria string". Measured against `origin/main` (2026-11-14), that
premise does not hold in one of its three terms: the five deck templates carry
**three** distinct card bodies, not five. Stripping comments and blank lines,
`closed-loop-iq/deck.cir.tmpl`, `closed-loop-vref-pvt-boxtc/deck.cir.tmpl` and
`closed-loop-vref-pvt/vref.cir.tmpl` are byte-identical to each other (36 card
lines across the five templates, 30 identical in all five; the only line that
differs is the supply stimulus, and it is identical in three of the five).

`sim/grid-run.sh` resolves `deck_template` by plain path join, so the filename
indirection 0011 §6 itself ratified — `bench.json` names the deck template
rather than fixing it — already permits more than one bench to name the same
file. `attest/README.md` states the inventory convention: each bench
contributes its **deck template** and its committed **`klt sim` request** —
"what the bench is" — while `bench.json` and `sim/grid-run.sh` are runner
plumbing and are deliberately not inventoried. The supply stimulus is a circuit
fact, not plumbing, so consolidation must not move it out of an inventoried
template; it may only remove byte-identical duplicates.

The duplication has a standing cost: every one of the five templates restates
the same five explanations (no SPICE title line, the `rshunt`/`gmin` convergence
aids, the `.global sub!` substrate tie, the `Xdut` staged-DUT wrapper,
`osdi_preload` instead of a `.control` block), so a corrected fact has to land
in five places inside the attested surface, each forcing a provisioned-host
re-attestation; and it grows one ~40-line copy per new bench on an existing
stimulus.

## Decision

1. **A bench whose supply stimulus is byte-identical to another bench's names
   the existing fixture instead of copying it.** `closed-loop-iq` and
   `closed-loop-vref-pvt-boxtc` set `deck_template:
   ../closed-loop-vref-pvt/vref.cir.tmpl` and `testbench:
   sim/closed-loop-vref-pvt/vref.cir.tmpl` in their `bench.json`;
   `sim/closed-loop-iq/deck.cir.tmpl` and
   `sim/closed-loop-vref-pvt-boxtc/deck.cir.tmpl` are deleted. What a bench
   runs is whatever deck file its `bench.json` names — fixture by filename, not
   fixture by directory. The surviving fixtures keep their paths
   (`vref.cir.tmpl` stays put because `spec/target-spec.md` cites it for the
   ratified `vref_nominal` binding condition), their cards are unchanged
   byte-for-byte, and their headers are reduced to the bench's own note plus a
   pointer; the five shared explanations move to `sim/README.md` under "Deck
   fixture conventions". Every distinct supply stimulus stays inside an
   inventoried `*.cir.tmpl`; item 9 narrows from 11 entries to 9 by deleting
   two byte-identical duplicate files and nothing else.

2. **This sets the convention for new benches**: a bench on an
   already-attested stimulus names the existing fixture; a bench with a new
   stimulus contributes a new fixture. The acceptance test is mechanical: no
   two templates named by any `bench.json` may have equal card bodies.

## Alternatives considered

- **One fixture with a `@@SUPPLY@@` placeholder supplied by
  `deck_substitutions`.** Rejected: it moves the one circuit fact that
  distinguishes these benches into `bench.json`, the file the inventory
  declares not inventoried, so item 9 would stop pinning the stimulus; it also
  inherits the `str.replace`-ordering hazard in `sim/grid-run.sh`'s
  substitution loop.
- **One fixture plus inventorying the five `bench.json`s.** Rejected on
  recurring cost: it couples every routine plumbing edit (`spec_rows`,
  `criteria`, `osdi`, `request`) to a provisioned-host re-attestation cycle and
  contradicts the convention `attest/README.md` and 0011 §6 both state.
- **A neutral `sim/deck-common.cir.tmpl` instead of keeping
  `vref.cir.tmpl`.** Rejected: it deletes the path `spec/target-spec.md` cites
  for a ratified spec row's binding condition. A ratified evidence citation
  should not move for a dedup.
- **Leave the five templates as they are.** Rejected: the five-copy rationale
  cost stands inside the attested surface and grows with each new bench.

## Consequences

- T1 item 9's inventory carries 9 entries instead of 11; its envelope carries
  12 passed checks instead of 14 (9 testbench present-checks + 1 cold start +
  2 pin checks). The inventory, envelope, manifest `content_hash`, signoff
  record and the cold start's new smoke record are regenerated in the same PR
  (`attest/README.md` § Extending).
- `template_sha256` in future grid records is the shared fixture's hash for the
  three benches that share it — which is the point: three benches running the
  same cards record the same template hash. Committed records are append-only
  and keep the hashes of what they actually ran.
- Generated decks are unchanged byte-for-byte: the deleted templates' card
  bodies were identical to the survivor's, `grid-run.sh` strips every `*` line,
  and the substituted values did not change.
- `sim/tests/test-grid-benches.sh` runs its fixture assertions once per
  distinct template (three, not five-or-six) and keeps its per-bench
  placeholder and request checks.
- No ratified spec row, measured figure, committed record or attested circuit
  fact changes.
