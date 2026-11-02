#!/usr/bin/env bash
# Verifies set_db_ssl_flags in common/entrypoint.sh picks TLS flags the installed mysql client
# understands. Oracle's client (amd64 image) takes --ssl-mode=REQUIRED --enable-cleartext-plugin.
# MariaDB's client (arm64 image: Debian's default-mysql-client, since MySQL's apt repo has no arm64
# packages) rejects --ssl-mode ("unknown variable 'ssl-mode=REQUIRED'"), which made every DB setup
# and delete fail on Graviton against a TLS-only RDS. Its equivalent is --ssl plus
# --skip-ssl-verify-server-cert (TLS required, server certificate not verified: the same as
# REQUIRED); the cleartext plugin is built in and --enable-cleartext-plugin is obsolete there.
#
# `mysql` is faked with --help output shaped like the real clients (the MariaDB lines were captured
# from mariadb 11.8.6 in the arm64 image). Requires bash >= 4.
set -uo pipefail
cd "$(dirname "$(readlink -f "$0")")" || exit 1

fail=0
ok()  { echo "ok: $1"; }
bad() { echo "FAIL: $1"; echo "  expected: $2"; echo "  actual:   $3"; fail=1; }
check() { [ "$2" = "$3" ] && ok "$1" || bad "$1" "$2" "$3"; }

work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
mkdir -p "$work/mysql-oracle" "$work/mariadb" "$work/none"

cat > "$work/mysql-oracle/mysql" <<'FAKE'
#!/bin/sh
cat <<'HELP'
mysql  Ver 8.4.8 for Linux on x86_64 (MySQL Community Server - GPL)
  --ssl-mode=name     SSL connection mode.
  --ssl-ca=name       CA file in PEM format.
  --enable-cleartext-plugin
                      Enable/disable the clear text authentication plugin.
HELP
FAKE
cat > "$work/mariadb/mysql" <<'FAKE'
#!/bin/sh
cat <<'HELP'
mysql from 11.8.6-MariaDB, client 15.2 for debian-linux-gnu (aarch64)
  --ssl               Enable SSL for connection (automatically enabled with
  --ssl-ca=name       CA file in PEM format (check OpenSSL docs, implies
  --ssl-verify-server-cert
                      Verify server's "Common Name" in its cert against
HELP
FAKE
chmod +x "$work/mysql-oracle/mysql" "$work/mariadb/mysql"

print_log() { :; }   # the entrypoint's logger; not under test here
# The entrypoint defines RDS_CA_BUNDLE when it is sourced; here it is set by hand. It starts out pointing at a
# file that does not exist, so the historical checks below keep covering the no-bundle path even when this test
# is run inside the image, where the real /etc/ssl/rds/global-bundle.pem is present.
RDS_CA_BUNDLE="$work/no-such-bundle.pem"

# Pull in only the functions under test.
eval "$(sed -n '/^mysql_client_supports_ssl_mode() {/,/^}/p;/^mysql_verify_flags() {/,/^}/p;/^app_db_tls_flags() {/,/^}/p;/^set_db_ssl_flags(){/,/^}/p' common/entrypoint.sh)"

# flags_with <client dir|none> <DB_SSL_ENABLED value|unset>
flags_with() {
  ( PATH="$work/$1:/usr/bin:/bin"
    [ "$1" = none ] && PATH="$work/none:/nonexistent"
    if [ "$2" = unset ]; then unset DB_SSL_ENABLED; else DB_SSL_ENABLED="$2"; fi
    set_db_ssl_flags; printf '%s' "$DB_SSL_FLAGS" )
}

# Oracle client: behaviour must be exactly what it was (amd64 images depend on it).
check "oracle client + DB_SSL_ENABLED=true" "--ssl-mode=REQUIRED --enable-cleartext-plugin" "$(flags_with mysql-oracle true)"
# MariaDB client: no flag it rejects.
got=$(flags_with mariadb true)
check "mariadb client + DB_SSL_ENABLED=true" "--ssl --skip-ssl-verify-server-cert" "$got"
case "$got" in *--ssl-mode*) bad "mariadb flags must not contain --ssl-mode" "(none)" "$got";; *) ok "mariadb flags contain no --ssl-mode";; esac
case "$got" in *--enable-cleartext-plugin*) bad "mariadb flags must not contain the obsolete --enable-cleartext-plugin" "(none)" "$got";; *) ok "mariadb flags contain no --enable-cleartext-plugin";; esac
# Opt-in only: anything but exactly "true" leaves the connection unchanged, for either client.
for c in mysql-oracle mariadb; do
  for v in unset false TRUE 1 ""; do
    check "$c + DB_SSL_ENABLED='$v' -> no flags" "" "$(flags_with $c "$v")"
  done
done
# If the client cannot be asked (not on PATH), keep the historical flags rather than guess.
check "no mysql on PATH + DB_SSL_ENABLED=true keeps the historical flags" "--ssl-mode=REQUIRED --enable-cleartext-plugin" "$(flags_with none true)"

# ---- With the RDS CA bundle present the setup client VERIFIES the server certificate -----------------
# (the default bundle path does not exist on a CI host, so everything above still runs the historical path)
BUNDLE="$work/bundle.pem"; echo "-----BEGIN CERTIFICATE-----" > "$BUNDLE"
HIST_ORACLE="--ssl-mode=REQUIRED --enable-cleartext-plugin"; HIST_MARIA="--ssl --skip-ssl-verify-server-cert"

# vflags <client dir|none> <DB_SSL_ENABLED|unset> <DB_SSL_VERIFY|unset> <bundle path>
vflags() {
  ( PATH="$work/$1:/usr/bin:/bin"; [ "$1" = none ] && PATH="$work/none:/nonexistent"
    if [ "$2" = unset ]; then unset DB_SSL_ENABLED; else DB_SSL_ENABLED="$2"; fi
    if [ "$3" = unset ]; then unset DB_SSL_VERIFY; else DB_SSL_VERIFY="$3"; fi
    RDS_CA_BUNDLE="$4"; set_db_ssl_flags; printf '%s' "$DB_SSL_FLAGS" )
}
check "oracle + bundle: verify host name and chain" "--ssl-mode=VERIFY_IDENTITY --ssl-ca=$BUNDLE --enable-cleartext-plugin" "$(vflags mysql-oracle true unset "$BUNDLE")"
check "mariadb + bundle: verify (no --ssl-mode, no obsolete cleartext flag)" "--ssl-ca=$BUNDLE --ssl-verify-server-cert" "$(vflags mariadb true unset "$BUNDLE")"
check "no mysql on PATH + bundle: assumes Oracle's client" "--ssl-mode=VERIFY_IDENTITY --ssl-ca=$BUNDLE --enable-cleartext-plugin" "$(vflags none true unset "$BUNDLE")"
# the kill switch: back to encrypt-without-verify, no rebuild needed
check "oracle + bundle + DB_SSL_VERIFY=false: historical flags" "$HIST_ORACLE" "$(vflags mysql-oracle true false "$BUNDLE")"
check "mariadb + bundle + DB_SSL_VERIFY=false: historical flags" "$HIST_MARIA" "$(vflags mariadb true false "$BUNDLE")"
# a missing bundle must not break setup: fall back (the entrypoint logs it)
check "oracle + bundle missing: historical flags" "$HIST_ORACLE" "$(vflags mysql-oracle true unset "$work/nope.pem")"
check "mariadb + bundle missing: historical flags" "$HIST_MARIA" "$(vflags mariadb true unset "$work/nope.pem")"
# opt-in rule is unchanged: a bundle alone never turns TLS on
for c in mysql-oracle mariadb; do for v in unset false TRUE 1 ""; do
  check "$c + bundle present + DB_SSL_ENABLED='$v': still no flags" "" "$(vflags $c "$v" unset "$BUNDLE")"
done; done

# ---- Calls made with the app's own credentials (apply_mail_setting) follow the app's PHP connection --------
# aflags <client> <SIMPLERISK_DB_SSL_CERT_PATH|unset>
aflags() {
  ( PATH="$work/$1:/usr/bin:/bin"
    if [ "$2" = unset ]; then unset SIMPLERISK_DB_SSL_CERT_PATH; else SIMPLERISK_DB_SSL_CERT_PATH="$2"; fi
    app_db_tls_flags )
}
check "app flags: oracle + cert path set" "--ssl-mode=VERIFY_IDENTITY --ssl-ca=$BUNDLE" "$(aflags mysql-oracle "$BUNDLE")"
check "app flags: mariadb + cert path set" "--ssl-ca=$BUNDLE --ssl-verify-server-cert" "$(aflags mariadb "$BUNDLE")"
# the app does not silently fall back to plaintext when its CA file is missing; neither does this
check "app flags: cert path set but file missing: still verifies (fails loudly)" "--ssl-mode=VERIFY_IDENTITY --ssl-ca=$work/nope.pem" "$(aflags mysql-oracle "$work/nope.pem")"
check "app flags: oracle + no cert path: client default (unchanged)" "" "$(aflags mysql-oracle unset)"
check "app flags: empty cert path is the same as unset" "" "$(aflags mysql-oracle "")"
# MariaDB verifies by default and cannot chain RDS without a CA, so without one it must not verify (as Oracle's does not)
check "app flags: mariadb + no cert path: no verification (as Oracle's default)" "--skip-ssl-verify-server-cert" "$(aflags mariadb unset)"

exit $fail
