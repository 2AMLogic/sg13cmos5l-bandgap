# Source me from a bench runner, after `source sim/env.sh`:  source sim/runner-lib.sh
#
# Shared runner steps (issue #37): tool and ngspice gate, append-only record path.
# Sets/exports for the caller: NGSPICE_VERSION, STAMP, SHA, REC. The envelope parsing and
# the exclusive record write live in sim/tools/cm5_record.py. Record shapes stay with each
# runner (decision record 0008).
#
# Sourced, not executed: no shebang. Do not `set -e` here; callers keep their own.
# shellcheck shell=bash

# cm5_gate <tag> <tool>...: exit 3 unless every tool is on PATH and ngspice is >= 43.
cm5_gate() {
  local tag="$1" tool; shift
  for tool in "$@"; do
    command -v "${tool}" >/dev/null 2>&1 || { echo "${tag}: ${tool} not on PATH." >&2; exit 3; }
  done
  NGSPICE_VERSION="$(ngspice --version 2>&1 | grep -m1 -oE 'ngspice-[0-9]+(\.[0-9]+)*')"
  local major="${NGSPICE_VERSION#ngspice-}"; major="${major%%.*}"
  if (( major < 43 )); then
    echo "${tag}: ${NGSPICE_VERSION} cannot load the OSDI v0.4 objects the pinned openvaf-r builds (needs >= 43; sim/pdk.json 'simulator')." >&2
    exit 3
  fi
}

# cm5_osdi_gate <tag> <object>...: exit 3 unless each ${CM5_OSDI_DIR}/<object>.osdi exists.
cm5_osdi_gate() {
  local tag="$1" obj; shift
  for obj in "$@"; do
    [[ -f "${CM5_OSDI_DIR}/${obj}.osdi" ]] \
      || { echo "${tag}: ${CM5_OSDI_DIR}/${obj}.osdi missing; build it first (sim/README.md 'OSDI build')." >&2; exit 3; }
  done
}

# cm5_record_path <tag> <repo_dir> <records_dir>: sets STAMP, SHA, REC; exit 4 if REC exists.
cm5_record_path() {
  STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
  SHA="$(git -C "$2" rev-parse --short HEAD)"
  REC="$3/${STAMP}-${SHA}.json"
  [[ ! -e "${REC}" ]] || { echo "$1: ${REC} exists; records are append-only." >&2; exit 4; }
}
