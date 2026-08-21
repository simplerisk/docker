#!/usr/bin/env bash
# Regression checks for generate_dockerfile.sh version/source-mode decoupling.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

# generate_dockerfile.sh hardcodes its output to the tracked Dockerfile in this
# directory; back it up and restore it on exit (pass or fail) so this checker
# never leaves the committed Dockerfile overwritten.
cp Dockerfile "/tmp/Dockerfile.bak.$$" 2>/dev/null || true
trap 'cp "/tmp/Dockerfile.bak.$$" Dockerfile 2>/dev/null || git checkout -- Dockerfile 2>/dev/null || true; rm -f "/tmp/Dockerfile.bak.$$"' EXIT

fail=0
check() { if grep -qF "$2" Dockerfile; then echo "ok: $1"; else echo "FAIL: $1 (missing: $2)"; fail=1; fi; }
absent() { if grep -qF "$2" Dockerfile; then echo "FAIL: $1 (should be absent: $2)"; fail=1; else echo "ok: $1"; fi; }

# context mode with a real version: no downloader, COPY-from-context, real ENV version, php 8.5 default
./generate_dockerfile.sh 20260709-001 context
check  "context: real ENV version"      "ENV version=20260709-001"
check  "context: COPY app from context" "COPY simplerisk/ /var/www/simplerisk"
absent "context: no downloader stage"   "FROM alpine/curl"
check  "context: php default 8.5"       "ARG php_version=8.5"

# download mode (explicit): downloader present, COPY-from-downloader, real ENV version
./generate_dockerfile.sh 20260709-001 download
check  "download: downloader stage"        "FROM alpine/curl"
check  "download: COPY from downloader"    "COPY --from=downloader /var/www/simplerisk /var/www/simplerisk"
check  "download: real ENV version"        "ENV version=20260709-001"

# back-compat: literal "testing" with no mode arg still selects context recipe
./generate_dockerfile.sh testing
absent "testing back-compat: no downloader" "FROM alpine/curl"
check  "testing back-compat: COPY context"  "COPY simplerisk/ /var/www/simplerisk"

# invalid source-mode is rejected
if ./generate_dockerfile.sh 20260709-001 bogus >/tmp/bogus-mode.out.$$ 2>&1; then
  echo "FAIL: invalid source-mode should be rejected (exited 0)"; fail=1
else
  echo "ok: invalid source-mode rejected"
fi
rm -f "/tmp/bogus-mode.out.$$"

# idempotence: re-running the same context args does not double anything
./generate_dockerfile.sh 20260709-001 context
copy_count=$(grep -cF "COPY simplerisk/ /var/www/simplerisk" Dockerfile)
if [ "$copy_count" -eq 1 ]; then
  echo "ok: idempotence (single COPY simplerisk/ line after re-run)"
else
  echo "FAIL: idempotence (expected 1 COPY simplerisk/ line, found $copy_count)"; fail=1
fi

exit $fail
