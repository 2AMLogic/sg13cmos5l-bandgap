# Source me:  source sim/env.sh
#
# Resolves the IHP SG13CMOS5L PDK for this repo's benches and REFUSES (return 1,
# named error) unless the install is the revision pinned in sim/pdk.json.
# Search order for PDK_ROOT, first hit wins: $PDK_ROOT, sim/build/IHP-Open-PDK
# (the documented in-tree cold-start location, gitignored), /usr/share/pdk,
# /usr/local/share/pdk, ~/share/pdk, ~/.ciel, ~/.volare -- the same order as
# 2AMLogic/sg13g2-bandgap sim/env.sh, with the PDK name and the revision
# refusal changed (see sim/ENV-DECISION.md for why this file is its own).
# Revision proof, first hit wins: $PDK_ROOT/.pdk-revision, git HEAD, then the fleet PDK store
# marker $PDK_ROOT/$PDK/.pdk-store.json (name + version).
# Needs python3 (stdlib only) and, to read the revision, git.
#
# Sourced, not executed: no shebang. Do not `set -e` here; callers keep their own.
# shellcheck shell=bash

_cm5_self="${BASH_SOURCE[0]:-$0}"
_cm5_sim_dir="$(cd "$(dirname "${_cm5_self}")" && pwd)"
_cm5_pin="${_cm5_sim_dir}/pdk.json"

_cm5_fail() {
  echo "sg13cmos5l env: ERROR [$1] $2" >&2
  unset -f _cm5_fail
  unset _cm5_self _cm5_sim_dir _cm5_pin _cm5_candidate _cm5_want _cm5_have _cm5_name _cm5_marker _cm5_mname
  return 1
}

_cm5_name="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["pdk"])' "${_cm5_pin}")" \
  || { _cm5_fail PIN_UNREADABLE "cannot read ${_cm5_pin}"; return 1; }
_cm5_want="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["revision"])' "${_cm5_pin}")" \
  || { _cm5_fail PIN_UNREADABLE "cannot read revision from ${_cm5_pin}"; return 1; }

export PDK="${_cm5_name}"

if [[ -z "${PDK_ROOT:-}" ]]; then
  for _cm5_candidate in "${_cm5_sim_dir}/build/IHP-Open-PDK" /usr/share/pdk /usr/local/share/pdk \
                        "${HOME}/share/pdk" "${HOME}/.ciel" "${HOME}/.volare"; do
    if [[ -d "${_cm5_candidate}/${PDK}/libs.tech/ngspice" ]]; then
      export PDK_ROOT="${_cm5_candidate}"
      break
    fi
  done
fi

if [[ -z "${PDK_ROOT:-}" || ! -d "${PDK_ROOT}/${PDK}/libs.tech/ngspice" ]]; then
  _cm5_fail PDK_NOT_FOUND "no ${PDK} install under PDK_ROOT or the usual prefixes; see sim/README.md 'Cold start' (pinned ${_cm5_want})"
  return 1
fi

# The shared MOS/resistor models are symlinks into ../ihp-sg13g2; without that sibling they dangle.
if [[ ! -e "${PDK_ROOT}/${PDK}/libs.tech/ngspice/models/cornerMOShv.lib" ]]; then
  _cm5_fail SIBLING_MISSING "${PDK_ROOT}/ihp-sg13g2 is absent, so the shared model symlinks dangle; use a combined IHP-Open-PDK checkout"
  return 1
fi

if [[ -f "${PDK_ROOT}/.pdk-revision" ]]; then
  _cm5_have="$(head -n1 "${PDK_ROOT}/.pdk-revision")"
elif _cm5_have="$(git -C "${PDK_ROOT}" rev-parse HEAD 2>/dev/null)"; then
  :
elif [[ -f "${PDK_ROOT}/${PDK}/.pdk-store.json" ]]; then
  # Fleet PDK store tree: no .git, no .pdk-revision; the sync writes this marker into the
  # ${PDK} subtree ({name, version, sha256, synced, bucket, key}). Only name and version are checked.
  _cm5_marker="${PDK_ROOT}/${PDK}/.pdk-store.json"
  if ! _cm5_have="$(python3 -I -c '
import json, sys
d = json.load(open(sys.argv[1]))
print(str(d["name"]).strip() + "\n" + str(d["version"]).strip())
' "${_cm5_marker}" 2>/dev/null)"; then
    _cm5_fail PDK_STORE_MARKER_UNREADABLE "${_cm5_marker} is not JSON with name and version; cannot prove ${PDK_ROOT} is ${_cm5_want}"
    return 1
  fi
  _cm5_mname="${_cm5_have%%$'\n'*}"
  _cm5_have="${_cm5_have#*$'\n'}"
  if [[ "${_cm5_mname}" != "${PDK}" ]]; then
    _cm5_fail PDK_STORE_NAME_MISMATCH "${_cm5_marker} names '${_cm5_mname}', expected '${PDK}'"
    return 1
  fi
  if [[ "${_cm5_have}" != "${_cm5_want}" ]]; then
    _cm5_fail PDK_STORE_VERSION_MISMATCH "${_cm5_marker} names version ${_cm5_have}, sim/pdk.json pins ${_cm5_want}"
    return 1
  fi
else
  _cm5_fail REVISION_UNKNOWN "${PDK_ROOT} is not a git checkout and has no .pdk-revision or ${PDK}/.pdk-store.json; cannot prove it is ${_cm5_want}"
  return 1
fi

if [[ "${_cm5_have}" != "${_cm5_want}" ]]; then
  _cm5_fail PDK_REVISION_MISMATCH "installed ${_cm5_have} at ${PDK_ROOT}, sim/pdk.json pins ${_cm5_want}"
  return 1
fi

export CM5_PDK_REVISION="${_cm5_have}"
export CM5_NGSPICE_MODELS="${PDK_ROOT}/${PDK}/libs.tech/ngspice/models"
export CM5_OSDI_DIR="${PDK_ROOT}/${PDK}/libs.tech/ngspice/osdi"
echo "sg13cmos5l env: PDK_ROOT=${PDK_ROOT} PDK=${PDK} revision=${CM5_PDK_REVISION} (matches sim/pdk.json)"
echo "sg13cmos5l env: models=${CM5_NGSPICE_MODELS}"
echo "sg13cmos5l env: osdi=${CM5_OSDI_DIR}"
if [[ ! -f "${CM5_OSDI_DIR}/psp103.osdi" ]]; then
  echo "sg13cmos5l env: WARNING psp103.osdi not built yet; MOS devices will not simulate (sim/README.md 'OSDI build')" >&2
fi

unset -f _cm5_fail
unset _cm5_self _cm5_sim_dir _cm5_pin _cm5_candidate _cm5_want _cm5_have _cm5_name _cm5_marker _cm5_mname
