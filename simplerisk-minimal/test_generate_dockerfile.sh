#!/usr/bin/env bash
# Regression checks for generate_dockerfile.sh version/source-mode decoupling.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
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

exit $fail
