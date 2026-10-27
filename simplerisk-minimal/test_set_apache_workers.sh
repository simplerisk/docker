#!/bin/bash
# Exercises set_apache_workers() from common/entrypoint.sh without starting
# Apache: the function is extracted and run against a temporary conf path.
# Usage: ./test_set_apache_workers.sh

set -eo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

print_log(){ echo "$1 $2"; }

# Pull just the function out of the entrypoint
func="$(awk '/^set_apache_workers\(\)\{/{p=1} p{print} p&&/^}/{exit}' "$here/common/entrypoint.sh")"
[ -n "$func" ] || { echo "FAIL: set_apache_workers not found in entrypoint.sh"; exit 1; }
eval "$func"

export APACHE_MPM_CONF_PATH="$tmp/simplerisk-mpm.conf"
failures=0

check(){
	local name="$1"; shift
	if "$@"; then echo "ok   $name"; else echo "FAIL $name"; failures=$((failures+1)); fi
}

run(){ ( unset APACHE_MAX_REQUEST_WORKERS; [ -z "${1:-}" ] || export APACHE_MAX_REQUEST_WORKERS="$1"; set_apache_workers >/dev/null ); }

has(){ grep -q -- "$1" "$APACHE_MPM_CONF_PATH"; }
absent(){ [ ! -e "$APACHE_MPM_CONF_PATH" ]; }

run ""            ; check "unset writes nothing"                 absent
run 40            ; check "40 sets MaxRequestWorkers"            has "MaxRequestWorkers 40"
run 40            ; check "40 leaves ServerLimit alone"          bash -c "! grep -q ServerLimit '$APACHE_MPM_CONF_PATH'"
run 300           ; check "300 raises ServerLimit too"           has "ServerLimit 300"
run 0040          ; check "leading zeros are normalised"         has "MaxRequestWorkers 40"
run ""            ; check "unsetting removes the earlier file"   absent
run abc           ; check "non-numeric is ignored"               absent
run 0             ; check "zero is ignored"                      absent
run 2001          ; check "over 2000 is ignored"                 absent
run "40; rm -rf /"; check "shell metacharacters are ignored"     absent

[ "$failures" -eq 0 ] || { echo "$failures check(s) failed"; exit 1; }
echo "all checks passed"
