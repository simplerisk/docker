#!/bin/bash
# Exercises set_apache_workers() from common/entrypoint.sh without starting
# Apache: the function is extracted and run against a temporary conf path.
# Usage: ./test_set_apache_workers.sh

set -eo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# print_log is what the entrypoint defines; capture its output so the tests
# can assert on what an operator would see
print_log(){ echo "[$1] $2"; }

# Pull just the function out of the entrypoint (from its header to the first
# closing brace at column 0). Fails loudly if the function moves or is renamed.
func="$(awk '/^set_apache_workers\(\) *\{/{p=1} p{print} p&&/^}/{exit}' "$here/common/entrypoint.sh")"
[ -n "$func" ] || { echo "FAIL: set_apache_workers not found in entrypoint.sh"; exit 1; }
eval "$func"

export APACHE_MPM_CONF_PATH="$tmp/simplerisk-mpm.conf"
failures=0
log=""

check(){
	local name="$1"; shift
	if "$@"; then echo "ok   $name"; else echo "FAIL $name"; failures=$((failures+1)); fi
}

# run <value>: run the function in a subshell with the variable set to <value>
# (or unset for an empty argument) and keep what it logged in $log
run(){ log="$( unset APACHE_MAX_REQUEST_WORKERS; [ -z "${1:-}" ] || export APACHE_MAX_REQUEST_WORKERS="$1"; set_apache_workers 2>&1 )"; }

has(){ grep -q -- "$1" "$APACHE_MPM_CONF_PATH"; }
hasnt(){ ! grep -q -- "$1" "$APACHE_MPM_CONF_PATH"; }
absent(){ [ ! -e "$APACHE_MPM_CONF_PATH" ]; }
logged(){ [[ "$log" == *"$1"* ]]; }

expected_300=$'# Written by the container entrypoint from APACHE_MAX_REQUEST_WORKERS\n<IfModule mpm_prefork_module>\n\tServerLimit 300\n\tMaxRequestWorkers 300\n</IfModule>'

run ""             ; check "unset writes nothing"                     absent
run 40             ; check "40 sets MaxRequestWorkers"                has "MaxRequestWorkers 40"
run 40             ; check "40 leaves ServerLimit alone"              hasnt ServerLimit
run 40             ; check "40 logs the cap"                          logged "at most 40"
run 1              ; check "lower bound 1 is accepted"                has "MaxRequestWorkers 1$"
run 256            ; check "256 does not raise ServerLimit"           hasnt ServerLimit
run 257            ; check "257 raises ServerLimit"                   has "ServerLimit 257"
run 2000           ; check "upper bound 2000 is accepted"             has "MaxRequestWorkers 2000"
run 300            ; check "300 writes the exact expected file"       test "$(cat "$APACHE_MPM_CONF_PATH")" = "$expected_300"
run 0040           ; check "leading zeros are normalised"             has "MaxRequestWorkers 40$"
run 000000000000000000000040 ; check "long zero padding is normalised" has "MaxRequestWorkers 40$"
run ""             ; check "unsetting removes the earlier file"       absent

# Rejected values: no file, a warning, and never a claim that a cap was applied
for bad in abc 0 00 2001 -5 1.5 " 40" "40 " "4 0" 18446744073709553616 99999999999999999999 "40; rm -rf /" '$(touch x)' '`id`' $'40\n41' '٣'; do
	run "$bad"
	check "rejects '${bad//$'\n'/\\n}'" bash -c '[ ! -e "$1" ]' _ "$APACHE_MPM_CONF_PATH"
	check "  and warns instead of claiming a cap" bash -c '[[ "$1" == *"[apache_setup:warn]"* && "$1" != *"at most"* ]]' _ "$log"
done

# A conf path that cannot be written: say so, write nothing, and do not claim the cap
saved="$APACHE_MPM_CONF_PATH"
export APACHE_MPM_CONF_PATH="$tmp/no-such-dir/simplerisk-mpm.conf"
run 40
check "unwritable path logs an error"          logged "[apache_setup:error]"
check "unwritable path does not claim a cap"   bash -c '[[ "$1" != *"at most"* ]]' _ "$log"
check "unwritable path leaves no file"         absent
export APACHE_MPM_CONF_PATH="$saved"

# The entrypoint must actually call the function, before it hands off to Apache
call_line="$(grep -n '^[[:space:]]*set_apache_workers$' "$here/common/entrypoint.sh" | head -1 | cut -d: -f1)"
exec_line="$(grep -n '^[[:space:]]*exec "\$@"' "$here/common/entrypoint.sh" | tail -1 | cut -d: -f1)"
check "entrypoint calls set_apache_workers before exec" bash -c '[ -n "$1" ] && [ -n "$2" ] && [ "$1" -lt "$2" ]' _ "$call_line" "$exec_line"

[ "$failures" -eq 0 ] || { echo "$failures check(s) failed"; exit 1; }
echo "all checks passed"
