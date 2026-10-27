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
