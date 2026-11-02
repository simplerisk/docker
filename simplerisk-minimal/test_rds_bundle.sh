#!/usr/bin/env bash
# Integrity of the vendored AWS RDS CA bundle that the image ships at /etc/ssl/rds/global-bundle.pem and that
# the setup client, the health probe and (through SIMPLERISK_DB_SSL_CERT_PATH) the app verify the database
# server against. AWS publishes no checksum for it, so we pin our own in rds-global-bundle.sha256: a changed
# bundle must be a deliberate, reviewed change (see .github/workflows/rds-bundle-drift.yml).
# Needs openssl and a sha256 tool; runs on the CI runner and on macOS.
set -uo pipefail
cd "$(dirname "$(readlink -f "$0")")" || exit 1

fail=0
ok()  { echo "ok: $1"; }
bad() { echo "FAIL: $1"; [ -n "${2:-}" ] && echo "  $2"; fail=1; }

readonly BUNDLE=common/etc/ssl/rds/global-bundle.pem PIN=rds-global-bundle.sha256
sha() { if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }

[ -s "$BUNDLE" ] && ok "bundle exists" || { bad "bundle exists ($BUNDLE)"; exit 1; }
[ -s "$PIN" ] && ok "pin file exists" || { bad "pin file exists ($PIN)"; exit 1; }

# 1. the pinned hash
want=$(awk '{print $1; exit}' "$PIN"); got=$(sha "$BUNDLE")
[ "$want" = "$got" ] && ok "sha256 matches the pin" || bad "sha256 matches the pin" "pinned $want, file is $got (refresh both together, deliberately)"
[ "$(awk '{print $2; exit}' "$PIN")" = "$BUNDLE" ] && ok "pin names the shipped path" || bad "pin names the shipped path" "$(cat "$PIN")"

# 2. every certificate parses; nothing but certificates is in the file
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
awk -v d="$work" '/BEGIN CERTIFICATE/{n++} {print > (d "/c" sprintf("%03d", n) ".pem")}' "$BUNDLE"
total=0; unparsable=0; : > "$work/subjects"; : > "$work/enddates"
for f in "$work"/c*.pem; do
  total=$((total+1))
  if out=$(openssl x509 -in "$f" -noout -subject -enddate 2>/dev/null); then
    echo "$out" | sed -n 's/^subject=//p' >> "$work/subjects"; echo "$out" | sed -n 's/^notAfter=//p' >> "$work/enddates"
  else unparsable=$((unparsable+1)); fi
done
[ "$unparsable" = 0 ] && ok "all $total certificates parse" || bad "all certificates parse" "$unparsable of $total do not"
[ "$total" -ge 100 ] && ok "looks like the global bundle ($total certificates)" || bad "looks like the global bundle" "only $total certificates"
grep -q "PRIVATE KEY" "$BUNDLE" && bad "no private key material" "found a PRIVATE KEY block" || ok "no private key material"

# 3. the roots for every region we run, in the key type the CDK pins (rds-ca-rsa2048-g1)
for r in us-east-1 eu-central-1 ca-central-1; do
  grep -q "Amazon RDS $r Root CA RSA2048 G1" "$work/subjects" && ok "contains the $r RSA2048 G1 root" || bad "contains the $r RSA2048 G1 root"
done

# 4. nothing in it is about to expire (a stale bundle fails closed, so catch it early)
now=$(date +%s); soon=$((now + 3*365*24*3600)); early=""
while IFS= read -r d; do
  t=$(date -d "$d" +%s 2>/dev/null || date -j -f "%b %e %T %Y %Z" "$d" +%s 2>/dev/null || echo 0)
  [ "$t" -gt 0 ] && [ "$t" -lt "$soon" ] && early="$early|$d"
done < "$work/enddates"
[ -z "$early" ] && ok "no certificate expires within 3 years" || bad "no certificate expires within 3 years" "$early"

# 5. the image really ships it where the entrypoint looks: `COPY common/ /` maps common/etc/ssl/rds -> /etc/ssl/rds
grep -q '^COPY common/ /$' Dockerfile && ok "Dockerfile copies common/ to /" || bad "Dockerfile copies common/ to /"
grep -q 'RDS_CA_BUNDLE:-/etc/ssl/rds/global-bundle.pem' common/entrypoint.sh && ok "entrypoint default path is /etc/ssl/rds/global-bundle.pem" || bad "entrypoint default path is /etc/ssl/rds/global-bundle.pem"

exit $fail
