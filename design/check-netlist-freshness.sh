#!/usr/bin/env bash
# T1 item 1 freshness gate for one migrated SG13CMOS5L cell: re-export the committed
# schematic with `klt netlist` and compare the result against the committed netlist
# under the classified normalization of design/tools/netlist_pin_delta.py.
#
#   design/check-netlist-freshness.sh [cell ...]     # default: all four cells
#
# A cell is a bare base name (bandgap_amp, bandgap_core, bandgap_startup, bandgap_top).
# This is the command attest/item1.json declares as each derived netlist's `freshness`
# check, so its exit status is what grades T1 item 1. See
# spec/decision-records/0015-item1-netlist-freshness-gate.md for why the gate is a
# normalized compare rather than `klt netlist --check` (a raw byte compare), and for
# exactly which two differences are tolerated and why nothing else is.
#
# Needs xschem (the pinned 3.4.7), klt, and the PDK revision sim/pdk.json pins --
# sim/env.sh resolves and REFUSES any other revision. That makes this check
# `local_only` in the inventory: a GitHub runner has none of it.
#
# Netlisting goes through `klt netlist`, never a raw `xschem`: klt forces the headless
# flag set and kills a hung run, where a bare xschem initialises its GUI, writes a
# plausible-looking netlist and hangs in the Tk event loop.
#
# Exit 0 every requested cell is fresh, 1 at least one drifted, 2 setup/usage error.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cells_dir="${root}/design/sg13cmos5l"
tool="${root}/design/tools/netlist_pin_delta.py"
ALL_CELLS=(bandgap_amp bandgap_core bandgap_startup bandgap_top)

die() { echo "check-netlist-freshness: $*" >&2; exit 2; }

cells=("$@")
if [[ ${#cells[@]} -eq 0 ]]; then
  cells=("${ALL_CELLS[@]}")
fi
for cell in "${cells[@]}"; do
  [[ -f "${cells_dir}/${cell}.sch" ]] || die "no such cell: ${cell} (${cells_dir}/${cell}.sch is absent)"
done

command -v klt >/dev/null 2>&1 || die "klt is not on PATH"
command -v xschem >/dev/null 2>&1 || die "xschem is not on PATH"
[[ -f "${tool}" ]] || die "missing ${tool}"

# shellcheck source=/dev/null
source "${root}/sim/env.sh" >/dev/null || die "sim/env.sh refused this PDK install (see its error above)"

tmp="$(mktemp -d)" || die "cannot create a scratch directory"
trap 'rm -rf "${tmp}"' EXIT

rc=0
for cell in "${cells[@]}"; do
  fresh="${tmp}/${cell}.spice"
  # cwd is the cell directory: design/xschemrc puts [pwd] first on the xschem library
  # path, which is what resolves the sibling .sym files of this PDK variant ahead of
  # design/'s identically-named SG13G2 originals.
  if ! ( cd "${cells_dir}" && klt netlist "${cell}.sch" -o "${fresh}" --rcfile ../xschemrc ) >"${tmp}/${cell}.log" 2>&1; then
    echo "ERROR ${cell}: klt netlist failed"
    sed 's/^/  | /' "${tmp}/${cell}.log"
    rc=2
    continue
  fi
  out="$(python3 -I "${tool}" --committed "${cells_dir}/netlist/${cell}.spice" --regenerated "${fresh}")"
  cmp_rc=$?
  if [[ ${cmp_rc} -eq 0 ]]; then
    echo "FRESH ${cell}: $(printf '%s\n' "${out}" | sed -n '2p')"
  elif [[ ${cmp_rc} -ne 1 ]]; then
    echo "ERROR ${cell}: the comparison tool exited ${cmp_rc}"
    printf '%s\n' "${out}" | sed 's/^/  | /'
    rc=2
  else
    echo "DRIFT ${cell}:"
    printf '%s\n' "${out}" | sed 's/^/  | /'
    [[ ${rc} -eq 2 ]] || rc=1
  fi
done

echo
case "${rc}" in
  0) echo "All ${#cells[@]} requested cell(s) are fresh against their schematics." ;;
  1) echo "At least one cell drifted from its schematic. This is a design-source finding, not a tolerance to widen." ;;
  *) echo "The check could not be completed (see the errors above)." ;;
esac
exit "${rc}"
