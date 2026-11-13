#!/usr/bin/env bash
# Stub-tool test for sim/runner-lib.sh and sim/tools/cm5_record.py. Needs only bash and
# python3: no PDK, no ngspice, no klt. Run: bash sim/tests/test-runner-lib.sh
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
fails=0
check() { if [[ "$2" == "$3" ]]; then echo "PASS $1"; else echo "FAIL $1: got '$2', want '$3'"; fails=$((fails+1)); fi; }

mkdir -p "${tmp}/bin"
stub() { printf '#!/bin/sh\necho "%s"\n' "$2" > "${tmp}/bin/$1"; chmod +x "${tmp}/bin/$1"; }
gate() { PATH="${tmp}/bin:${PATH}" bash -c "source '${root}/sim/runner-lib.sh'; cm5_gate t ngspice; echo \$NGSPICE_VERSION" 2>&1; }

stub ngspice "** ngspice-42 : x"
check "gate refuses ngspice 42" "$(gate | head -1 | cut -c1-40)" "t: ngspice-42 cannot load the OSDI v0.4 "
stub ngspice "** ngspice-46.1 : x"
check "gate accepts ngspice 46.1" "$(gate)" "ngspice-46.1"
check "gate names a missing tool" "$(PATH="${tmp}/bin" "$(command -v bash)" -c "source '${root}/sim/runner-lib.sh'; cm5_gate t nosuchtool" 2>&1)" "t: nosuchtool not on PATH."

mkdir -p "${tmp}/rec"
git init -q "${tmp}/repo" && git -C "${tmp}/repo" -c user.email=a@b -c user.name=t commit -q --allow-empty -m x
rp() { bash -c "source '${root}/sim/runner-lib.sh'; cm5_record_path t '${tmp}/repo' '${tmp}/rec'; echo \"\$REC\"; : > \"\$REC\""; }
rec="$(rp)"; check "record path created" "$([[ -f "${rec}" ]] && echo yes)" yes
rm -f "${tmp}"/rec/*
out="$(bash -c "source '${root}/sim/runner-lib.sh'; date() { echo FIXED; }; git() { command git \"\$@\"; }; : > '${tmp}/rec/FIXED-'\"\$(git -C '${tmp}/repo' rev-parse --short HEAD)\".json; cm5_record_path t '${tmp}/repo' '${tmp}/rec'" 2>&1)"; rc=$?
check "existing record refused (exit 4)" "${rc}:${out##*; }" "4:records are append-only."

# ---- cm5_stage_dut: the .SUBCKT-wrapped staged DUT (issue #80, decision record 0013) ----
# The DUT the benches .include is derived at staging time, never committed and never edited
# in design/: the attested source's commented-out top block becomes a live
# `.subckt sg13cmos5l_bandgap_top vdd vref vss` (the EXTRACTED netlist's cell name and pin
# order, so `klt pex` fires neither flat_dut_mismatch nor pin_order_mismatch) and the final
# `.end` card is dropped. Run against the real committed netlist -- needs no PDK or klt.
dut="${root}/design/sg13cmos5l/netlist/bandgap_top.spice"
mkdir -p "${tmp}/work"
out="$(bash -c "source '${root}/sim/runner-lib.sh'
cm5_stage_dut t '${root}' '${tmp}/work'
echo \"\${CM5_DUT_SUBCKT} \${CM5_DUT_SHA256}\"" 2>&1)"
staged="${tmp}/work/bandgap_top.spice"
check "stage_dut reports the wrapper cell and the staged hash" "${out}" \
  "sg13cmos5l_bandgap_top $(sha256sum "${staged}" 2>/dev/null | cut -d' ' -f1)"
check "staged top block is the extracted .subckt header, in the extracted pin order" \
  "$(grep -c '^\.subckt sg13cmos5l_bandgap_top vdd vref vss$' "${staged}")" 1
check "staged top block is closed by a named .ends" \
  "$(grep -c '^\.ends sg13cmos5l_bandgap_top$' "${staged}")" 1
check "staged DUT leaves no commented-out top block behind" \
  "$(grep -c '^\*\*\.\(subckt\|ends\)' "${staged}")" 0
check "staged DUT still carries the three leaf subckts" \
  "$(grep -c '^\.subckt bandgap_\(core\|amp\|startup\) ' "${staged}")" 3
check "staged DUT has no .end card (the including deck's is the only one)" \
  "$(grep -c -x '\.end' "${staged}")" 0
check "staged DUT is the source plus exactly those two rewritten lines" \
  "$(diff <(grep -v -x '\.end' "${dut}") "${staged}" | grep -c '^[<>]')" 4
check "fetched copy is byte-identical to the attested source" \
  "$(cmp -s "${dut}" "${tmp}/work/bandgap_top.fetched.spice" && echo same)" same

# Refusal: an unexpected top block is exit 6 with a named reason, never a silent flat stage.
# A changed pin order is the case that matters most -- it is what pin_order_mismatch is.
stage_refusal() {
  local expr="$2" dir="${tmp}/bad-${1}" out rc
  mkdir -p "${dir}/design/sg13cmos5l/netlist" "${dir}/work"
  sed -e "${expr}" "${dut}" > "${dir}/design/sg13cmos5l/netlist/bandgap_top.spice"
  # Captured, not piped: a `| head -1` would SIGPIPE the refusal and report 141, not 6.
  out="$(bash -c "source '${root}/sim/runner-lib.sh'; cm5_stage_dut t '${dir}' '${dir}/work'" 2>&1)"
  rc=$?
  printf '%s' "${out%%:*}"
  return "${rc}"
}
for bad in \
  'pin-order:s|^\*\*\.subckt bandgap_top vdd vss vref$|**.subckt bandgap_top vdd vref vss|' \
  'no-footer:/^\*\*\.ends$/d' \
  'duplicate:s|^\*\*\.subckt bandgap_top vdd vss vref$|&\n&|'
do
  reason="$(stage_refusal "${bad%%:*}" "${bad#*:}")"; rc=$?
  check "stage_dut refuses a ${bad%%:*} top block (exit 6, named)" \
    "${rc}:${reason}" "6:TOP_BLOCK_UNEXPECTED"
done

py="$(python3 -I - "${root}/sim/tools" "${tmp}/rec/new.json" <<'PY'
import sys, json
sys.path.insert(0, sys.argv[1])
from cm5_record import collect, write_record
env = {"a": [{"name": "x", "value": 1.5}, {"y": 2}], "z": {"w": "no"}}
print(sorted(collect(env, ("x", "y", "w")).items()))
write_record(sys.argv[2], {"k": 1})
try:
    write_record(sys.argv[2], {"k": 2})
except FileExistsError:
    print("exclusive")
PY
)"
check "collect + exclusive write" "${py}" "[('x', 1.5), ('y', 2)]
exclusive"
exit "${fails}"
