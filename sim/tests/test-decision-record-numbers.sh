#!/usr/bin/env bash
# Decision-record numbering guard for spec/decision-records/. Three offline
# assertions, needing only bash and python3:
#
#   1. No two NNNN-*.md files share a four-digit record number. The series has
#      been renumbered by hand five times (0016-statistical-mc-sections-and-window.md
#      alone moved 0012 -> 0013 -> 0014 -> 0016, and PR #111's shared-deck-fixtures
#      record was drafted 0015, renumbered after #98 took 0015, then still landed a
#      second 0016 at its branch head) -- every one caught by hand, none by any
#      check, because no check existed. A collision matters beyond cosmetics: a
#      bare "decision record NNNN" citation becomes ambiguous repo-wide the
#      moment one lands, including inside hash-pinned attestation artifacts,
#      where the repair is a provisioned-host re-attestation cycle (issue #123).
#   2. Every record's '# NNNN:' H1 matches its own filename prefix, so the
#      number a reader sees inside the file is the number the filename cites.
#   3. Every record is indexed in spec/README.md by a '](decision-records/NNNN-'
#      link. 0021 landed unindexed (PR #178) because nothing checked this; the
#      link form is matched, not the bare path, so a code-span mention does
#      not count as an index entry.
#
# Deliberately NOT checked: contiguity (0003-0005 are sg13g2-bandgap's records;
# the gaps are permanent and correct) and bare-citation resolution (the frozen
# sim/closed-loop-vref-mc/ evidence cites "decision record 0012" for what is
# now 0016 by design -- the literals live inside append-only evidence and
# inputs whose sha256 is recorded in that evidence, so a resolver would be
# permanently red on bytes nobody may touch; see 0016's numbering note).
#
# Run: bash sim/tests/test-decision-record-numbers.sh
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
fails=0

# check_tree <tree-root>: the guard itself, run against the real repo in the
# final case and against fake trees in the negative cases below.
check_tree() {
  python3 -I - "$1" <<'PY'
import glob, os, re, sys

root = sys.argv[1]
rel = lambda p: os.path.relpath(p, root)
paths = sorted(glob.glob(os.path.join(root, "spec", "decision-records",
                                      "[0-9][0-9][0-9][0-9]-*.md")))
fails = []

if not paths:
    fails.append("no spec/decision-records/[0-9][0-9][0-9][0-9]-*.md records found "
                 "-- glob or layout changed")

by_prefix = {}
for p in paths:
    prefix = os.path.basename(p)[:4]
    by_prefix.setdefault(prefix, []).append(rel(p))
for prefix in sorted(by_prefix):
    ps = by_prefix[prefix]
    if len(ps) > 1:
        fails.append("record number %s is claimed by %d files: %s"
                     % (prefix, len(ps), ", ".join(sorted(ps))))

for p in paths:
    prefix = os.path.basename(p)[:4]
    with open(p, encoding="utf-8", errors="replace") as fh:
        h1 = next((line.rstrip("\n") for line in fh if line.startswith("# ")), "")
    m = re.match(r"^# (\d{4}):", h1)
    if not m:
        fails.append("%s: no '# NNNN:' H1 line found" % rel(p))
    elif m.group(1) != prefix:
        fails.append("%s: H1 says #%s but the filename prefix is %s"
                     % (rel(p), m.group(1), prefix))

readme = None
if paths:
    try:
        with open(os.path.join(root, "spec", "README.md"),
                  encoding="utf-8", errors="replace") as fh:
            readme = fh.read()
    except OSError:
        fails.append("spec/README.md not found -- cannot check that every "
                     "decision record is indexed")
if readme is not None:
    for p in paths:
        prefix = os.path.basename(p)[:4]
        if "](decision-records/%s-" % prefix not in readme:
            fails.append("%s: no '](decision-records/%s-' link in "
                         "spec/README.md -- every record must be indexed"
                         % (rel(p), prefix))

if fails:
    for f in fails:
        print("FAIL", f)
    sys.exit(1)
print("PASS %d decision record%s: unique four-digit prefixes, every "
      "'# NNNN:' H1 matches its filename, every record indexed in "
      "spec/README.md"
      % (len(paths), "" if len(paths) == 1 else "s"))
PY
}

# expect <label> <tree-root> <want-rc> [output-substring ...]
expect() {
  local label="$1" dir="$2" want="$3"; shift 3
  local out rc s ok=1
  out="$(check_tree "$dir")"; rc=$?
  for s in "$@"; do [[ "${out}" == *"$s"* ]] || ok=0; done
  if [[ ${rc} -eq ${want} && ${ok} -ne 0 ]]; then
    echo "PASS ${label}"
  else
    echo "FAIL ${label} (want rc=${want}${*:+ containing '$*'}, got rc=${rc}): ${out}"
    fails=$((fails+1))
  fi
}

# ---- negative cases: duplicate prefix ----------------------------------------
d="${tmp}/dup-prefix"
mkdir -p "${d}/spec/decision-records"
printf '# 0016: The statistical Monte Carlo bench\n' \
  > "${d}/spec/decision-records/0016-statistical-mc.md"
printf '# 0016: Grid benches share one deck fixture\n' \
  > "${d}/spec/decision-records/0016-shared-deck-fixtures.md"
printf -- '- [x](decision-records/0016-statistical-mc.md)\n- [x](decision-records/0016-shared-deck-fixtures.md)\n' \
  > "${d}/spec/README.md"
expect "duplicate four-digit prefix rejected, naming both colliding files" "${d}" 1 \
  "record number 0016 is claimed by 2 files" \
  "0016-statistical-mc.md" "0016-shared-deck-fixtures.md"

# ---- negative cases: H1 does not match the filename ---------------------------
d="${tmp}/h1-mismatch"
mkdir -p "${d}/spec/decision-records"
printf '# 0017: Wrong record number in the heading\n' \
  > "${d}/spec/decision-records/0016-record.md"
printf -- '- [x](decision-records/0016-record.md)\n' > "${d}/spec/README.md"
expect "H1 number not matching the filename rejected, naming file and both numbers" \
  "${d}" 1 "0016-record.md" "H1 says #0017" "filename prefix is 0016"

# ---- negative cases: H1 absent ------------------------------------------------
d="${tmp}/h1-absent"
mkdir -p "${d}/spec/decision-records"
printf 'Prose only, no heading.\n' > "${d}/spec/decision-records/0009-orphan.md"
printf -- '- [x](decision-records/0009-orphan.md)\n' > "${d}/spec/README.md"
expect "record without a '# NNNN:' H1 rejected, naming the file" "${d}" 1 \
  "0009-orphan.md" "no '# NNNN:' H1 line found"

# ---- negative cases: record not indexed in spec/README.md ---------------------
d="${tmp}/unindexed"
mkdir -p "${d}/spec/decision-records"
printf '# 0021: Stop vendoring the T1 checklist\n' \
  > "${d}/spec/decision-records/0021-remove-vendored-tiers-checklist.md"
printf "# spec\n\nSee \`decision-records/0021-remove-vendored-tiers-checklist.md\` (mention, not a link).\n" \
  > "${d}/spec/README.md"
expect "record with no spec/README.md link rejected, naming the unindexed file" \
  "${d}" 1 "0021-remove-vendored-tiers-checklist.md" \
  "no '](decision-records/0021-' link in spec/README.md"

d="${tmp}/no-readme"
mkdir -p "${d}/spec/decision-records"
printf '# 0004: A record whose index is gone\n' \
  > "${d}/spec/decision-records/0004-lost-index.md"
expect "records with no spec/README.md at all rejected, not skipped" "${d}" 1 \
  "spec/README.md not found"

# ---- edge cases: empty / TEMPLATE-only directory fails loudly -----------------
d="${tmp}/empty"
mkdir -p "${d}/spec/decision-records"
expect "empty decision-records directory fails loudly, not vacuously" "${d}" 1 \
  "no spec/decision-records/[0-9][0-9][0-9][0-9]-*.md records found"

d="${tmp}/template-only"
mkdir -p "${d}/spec/decision-records"
cp "${root}/spec/decision-records/TEMPLATE.md" "${d}/spec/decision-records/TEMPLATE.md"
expect "TEMPLATE.md alone is not a record (its # 0000: is outside the glob)" "${d}" 1 \
  "no spec/decision-records/[0-9][0-9][0-9][0-9]-*.md records found"

# ---- edge cases: TEMPLATE.md excluded; non-contiguous numbering passes --------
d="${tmp}/template-plus-one"
mkdir -p "${d}/spec/decision-records"
cp "${root}/spec/decision-records/TEMPLATE.md" "${d}/spec/decision-records/TEMPLATE.md"
printf '# 0001: A real record\n' > "${d}/spec/decision-records/0001-real.md"
printf -- '- [x](decision-records/0001-real.md)\n' > "${d}/spec/README.md"
expect "TEMPLATE.md ignored, one numbered record passes" "${d}" 0 "1 decision record"

d="${tmp}/gaps"
mkdir -p "${d}/spec/decision-records"
printf '# 0002: First kept record\n' > "${d}/spec/decision-records/0002-a.md"
printf '# 0006: Next kept record\n' > "${d}/spec/decision-records/0006-b.md"
printf -- '- [x](decision-records/0002-a.md)\n- [x](decision-records/0006-b.md)\n' \
  > "${d}/spec/README.md"
expect "gaps in the sequence pass (0003-0005 live in sg13g2-bandgap)" "${d}" 0 \
  "2 decision records"

d="${tmp}/indexed"
mkdir -p "${d}/spec/decision-records"
printf '# 0002: First kept record\n' > "${d}/spec/decision-records/0002-a.md"
printf '# 0006: Next kept record\n' > "${d}/spec/decision-records/0006-b.md"
printf '# spec\n\nDecision records:\n\n- [0002-a.md](decision-records/0002-a.md): first\n- [0006-b.md](decision-records/0006-b.md): next\n' \
  > "${d}/spec/README.md"
expect "every record linked from spec/README.md passes" "${d}" 0 \
  "2 decision records" "every record indexed in spec/README.md"

# ---- real committed tree ------------------------------------------------------
out="$(check_tree "${root}")"; rc=$?
echo "${out}"
if [[ ${rc} -ne 0 ]]; then
  echo "FAIL real committed tree does not verify (rc=${rc})"
  fails=$((fails+1))
fi

if [[ ${fails} -ne 0 ]]; then echo "${fails} case(s) FAILED"; exit 1; fi
echo "all cases passed"
