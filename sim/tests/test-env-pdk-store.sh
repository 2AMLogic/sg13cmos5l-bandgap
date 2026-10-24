#!/usr/bin/env bash
# Fake-tree test for the fleet PDK store proof in sim/env.sh. Needs only bash and python3:
# no real PDK, no network, no ngspice. Run: bash sim/tests/test-env-pdk-store.sh
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
pin="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["revision"])' "${root}/sim/pdk.json")"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
fails=0

# mk <name>: fake PDK tree under ${tmp}/<name>; echoes its path.
mk() {
  local d="${tmp}/$1"
  mkdir -p "${d}/ihp-sg13cmos5l/libs.tech/ngspice/models"
  : > "${d}/ihp-sg13cmos5l/libs.tech/ngspice/models/cornerMOShv.lib"
  echo "${d}"
}

# expect <label> <PDK_ROOT> <ok|TOKEN>
expect() {
  local out rc
  out="$(PDK_ROOT="$2" bash -c "source '${root}/sim/env.sh'" 2>&1)"; rc=$?
  if [[ "$3" == ok ]]; then
    if [[ ${rc} -eq 0 && "${out}" == *"revision=${pin}"* ]]; then echo "PASS $1"; else echo "FAIL $1 (rc=${rc}): ${out}"; fails=$((fails+1)); fi
  else
    if [[ ${rc} -ne 0 && "${out}" == *"[$3]"* ]]; then echo "PASS $1"; else echo "FAIL $1 (want $3, rc=${rc}): ${out}"; fails=$((fails+1)); fi
  fi
}

d="$(mk accept)"; echo "{\"name\":\"ihp-sg13cmos5l\",\"version\":\"${pin}\"}" > "${d}/ihp-sg13cmos5l/.pdk-store.json"
expect "marker matches" "${d}" ok

d="$(mk ws)"; printf '{"name":"ihp-sg13cmos5l","version":" %s \\n"}' "${pin}" > "${d}/ihp-sg13cmos5l/.pdk-store.json"
expect "version with whitespace" "${d}" ok

d="$(mk other-version)"; echo '{"name":"ihp-sg13cmos5l","version":"deadbeef"}' > "${d}/ihp-sg13cmos5l/.pdk-store.json"
expect "other version refused" "${d}" PDK_STORE_VERSION_MISMATCH

d="$(mk wrong-name)"; echo "{\"name\":\"ihp-sg13g2\",\"version\":\"${pin}\"}" > "${d}/ihp-sg13cmos5l/.pdk-store.json"
expect "wrong name refused" "${d}" PDK_STORE_NAME_MISMATCH

d="$(mk not-json)"; echo 'not json' > "${d}/ihp-sg13cmos5l/.pdk-store.json"
expect "malformed JSON refused" "${d}" PDK_STORE_MARKER_UNREADABLE

d="$(mk no-version)"; echo '{"name":"ihp-sg13cmos5l"}' > "${d}/ihp-sg13cmos5l/.pdk-store.json"
expect "missing version refused" "${d}" PDK_STORE_MARKER_UNREADABLE

d="$(mk no-proof)"
expect "no proof at all" "${d}" REVISION_UNKNOWN

d="$(mk rev-ok)"; echo "${pin}" > "${d}/.pdk-revision"
expect ".pdk-revision still accepted" "${d}" ok

d="$(mk rev-bad)"; echo "deadbeef" > "${d}/.pdk-revision"
expect ".pdk-revision mismatch still refused" "${d}" PDK_REVISION_MISMATCH

# Precedence: .pdk-revision wins over a (matching) marker.
d="$(mk rev-wins)"; echo "deadbeef" > "${d}/.pdk-revision"
echo "{\"name\":\"ihp-sg13cmos5l\",\"version\":\"${pin}\"}" > "${d}/ihp-sg13cmos5l/.pdk-store.json"
expect ".pdk-revision takes precedence over marker" "${d}" PDK_REVISION_MISMATCH

d="$(mk sibling)"; rm "${d}/ihp-sg13cmos5l/libs.tech/ngspice/models/cornerMOShv.lib"
echo "{\"name\":\"ihp-sg13cmos5l\",\"version\":\"${pin}\"}" > "${d}/ihp-sg13cmos5l/.pdk-store.json"
expect "missing sibling reported first" "${d}" SIBLING_MISSING

[[ ${fails} -eq 0 ]] && echo "all passed" || { echo "${fails} failed"; exit 1; }
