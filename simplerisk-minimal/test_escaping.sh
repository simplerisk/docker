#!/usr/bin/env bash
# Regression checks that credential values containing shell/PHP/SQL/sed
# metacharacters are neutralised by the escaping helpers in common/entrypoint.sh.
# Requires bash >= 5 and GNU sed (as in the image and ubuntu CI runners); macOS
# /bin/bash 3.2 and BSD sed give false failures, so run it inside the image there.
set -uo pipefail
cd "$(dirname "$(readlink -f "$0")")" || exit 1

fail=0
ok()  { echo "ok: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

work=$(mktemp -d); trap 'rm -rf "$work"' EXIT

# Pull in only the helpers under test.
helpers=$(sed -n '/^sed_escape() {/,/^}/p;/^php_sq_escape() {/,/^}/p;/^sql_str_escape() {/,/^}/p;/^sql_ident_escape() {/,/^}/p;/^config_define() {/,/^}/p;/^set_csrf_secret(){/,/^}/p' common/entrypoint.sh \
  | sed "s|/var/www/simplerisk/vendor/simplerisk/csrf-magic/csrf-secret.php|$work/csrf-secret.php|")
eval "$helpers"

# A value hitting every metacharacter class: " ' \ $ ` & | newline and $(cmd).
nasty=$'a"b\'c\\d$(touch '"$work"$'/PWNED)`touch '"$work"$'/PWNED2`&e|f\ng'

# --- sed_escape: round-trips through a real sed substitution, newline included
printf 'X\n' > "$work/in"
sed -i "s|X|$(sed_escape "$nasty")|" "$work/in"
[ "$(cat "$work/in")" = "$nasty" ] && ok "sed_escape round-trips nasty value" || bad "sed_escape round-trip"

# --- SQL escapers
[ "$(sql_str_escape "a'b\\c")" = "a\\'b\\\\c" ] && ok "sql_str_escape" || bad "sql_str_escape"
[ "$(sql_ident_escape 'a"b')" = 'a""b' ] && ok "sql_ident_escape" || bad "sql_ident_escape"

# --- PHP: config.php define and csrf-secret.php must evaluate back to the exact value
if command -v php >/dev/null 2>&1; then
  CONFIG_PATH="$work/config.php"
  printf "<?php\ndefine('DB_PASSWORD', 'x');\n" > "$CONFIG_PATH"
  config_define DB_PASSWORD "$nasty"
  got=$(php -r "include '$CONFIG_PATH'; echo DB_PASSWORD;")
  [ "$got" = "$nasty" ] && ok "config_define yields exact value in PHP" || bad "config_define (got: $got)"

  SIMPLERISK_CSRF_SECRET="$nasty" set_csrf_secret
  got=$(php -r "include '$work/csrf-secret.php'; echo \$secret;")
  [ "$got" = "$nasty" ] && ok "set_csrf_secret yields exact value in PHP" || bad "set_csrf_secret (got: $got)"
else
  echo "skip: php not installed (PHP round-trip checks)"
fi

# --- nothing in the nasty value may have been executed
[ ! -e "$work/PWNED" ] && [ ! -e "$work/PWNED2" ] && ok "no command substitution executed" || bad "injected command executed"

exit $fail
