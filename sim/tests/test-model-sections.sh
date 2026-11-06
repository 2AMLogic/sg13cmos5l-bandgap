#!/usr/bin/env bash
# Fake-tree test for sim/tools/check-model-sections.py exit-code contract. Needs only bash and
# python3: no real PDK, no network, no ngspice. Run: bash sim/tests/test-model-sections.sh
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tool="${root}/sim/tools/check-model-sections.py"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
fails=0

# lib <file> <section>...: write a corner file defining each section.
lib() {
  local f="$1"; shift
  : > "${f}"
  local s
  for s in "$@"; do printf '.lib %s\n* body\n.endl %s\n' "${s}" "${s}" >> "${f}"; done
}

# mk <name>: complete fake models dir (all 12 required sections); echoes its path.
mk() {
  local d="${tmp}/$1"
  mkdir -p "${d}"
  lib "${d}/cornerPNP.lib" typ bcs wcs stat
  lib "${d}/cornerMOShv.lib" mos_tt mos_ff mos_ss mos_sf mos_fs
  lib "${d}/cornerRES.lib" res_typ res_bcs res_wcs
  echo "${d}"
}

# expect <label> <models-dir> <exit-code> [output-substring]
expect() {
  local out rc
  out="$(python3 -I "${tool}" --models-dir "$2" 2>&1)"; rc=$?
  if [[ ${rc} -eq $3 && ( -z "${4:-}" || "${out}" == *"$4"* ) ]]; then
    echo "PASS $1"
  else
    echo "FAIL $1 (want rc=$3 ${4:+containing '$4'}, got rc=${rc}): ${out}"; fails=$((fails+1))
  fi
}

d="$(mk complete)"
expect "all 12 required sections present" "${d}" 0 "12/12 required sections found"

d="$(mk no-stat)"; lib "${d}/cornerPNP.lib" typ bcs wcs
expect "stat missing from cornerPNP.lib" "${d}" 1 "stat"

d="$(mk bad-include)"
# typ carries a .include whose target does not exist; the other sections are plain.
{ printf '.lib typ\n.include missing-target.lib\n.endl typ\n'
  for s in bcs wcs stat; do printf '.lib %s\n.endl %s\n' "${s}" "${s}"; done; } > "${d}/cornerPNP.lib"
expect "required section with missing .include target" "${d}" 1 "missing-target.lib"

d="$(mk dangling)"; rm "${d}/cornerMOShv.lib"; ln -s "${tmp}/does-not-exist.lib" "${d}/cornerMOShv.lib"
expect "cornerMOShv.lib dangling symlink" "${d}" 1 "dangling symlink"

expect "models dir does not exist" "${tmp}/no-such-dir" 2

# Mismatch candidates are informational only: adding or removing them leaves the exit code alone.
d="$(mk mismatch-added)"; lib "${d}/cornerMOShv.lib" mos_tt mos_ff mos_ss mos_sf mos_fs mos_tt_stat
expect "mismatch-candidate section added: exit unchanged" "${d}" 0 "mos_tt_stat"

d="$(mk mismatch-removed)"; lib "${d}/cornerMOShv.lib" mos_tt mos_ff mos_ss mos_sf mos_fs mos_tt_stat
lib "${d}/cornerMOShv.lib" mos_tt mos_ff mos_ss mos_sf mos_fs
expect "mismatch-candidate section removed: exit unchanged" "${d}" 0 "12/12 required sections found"

if [[ ${fails} -ne 0 ]]; then echo "${fails} case(s) FAILED"; exit 1; fi
echo "all cases passed"
