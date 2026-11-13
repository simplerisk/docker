#!/usr/bin/env bash
# Regression checks for the *_FILE secrets support in common/entrypoint.sh.
set -uo pipefail
cd "$(dirname "$(readlink -f "$0")")" || exit 1

fail=0
ok()   { echo "ok: $1"; }
bad()  { echo "FAIL: $1"; fail=1; }

# Load only the helpers under test; fatal_error is stubbed to exit the subshell.
helpers=$(sed -n '/^file_env() {/,/^}/p;/^load_file_envs() {/,/^}/p' common/entrypoint.sh)
run() { bash -c 'set -eo pipefail; fatal_error(){ echo "FATAL: $1"; exit 1; }; '"$helpers"'; '"$1"; }

dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
printf 'p@ss w/&|\n' > "$dir/secret"

out=$(DB_SETUP_PASS_FILE="$dir/secret" run 'load_file_envs; [ "$DB_SETUP_PASS" = "p@ss w/&|" ] && [ -z "${DB_SETUP_PASS_FILE:-}" ] && echo pass') 
[ "$out" = pass ] && ok "reads file, strips newline, unsets _FILE" || bad "reads file (got: $out)"

SIMPLERISK_DB_PASSWORD=x SIMPLERISK_DB_PASSWORD_FILE="$dir/secret" run 'load_file_envs' >/dev/null \
  && bad "VAR and VAR_FILE together should be rejected" || ok "VAR and VAR_FILE together rejected"

MAIL_PASSWORD_FILE="$dir/missing" run 'load_file_envs' >/dev/null \
  && bad "unreadable _FILE should be rejected" || ok "unreadable _FILE rejected"

SIMPLERISK_DB_PASSWORD=keep run 'load_file_envs; [ "$SIMPLERISK_DB_PASSWORD" = keep ]' \
  && ok "plain VAR untouched when no _FILE" || bad "plain VAR changed"

exit $fail
