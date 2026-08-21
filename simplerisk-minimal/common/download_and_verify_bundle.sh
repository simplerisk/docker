#!/bin/sh
# Download the released SimpleRisk bundle for the given version, verify it against
# the sha256 (md5 fallback) published in the production updates feed, then extract
# it into /var/www. Run from the alpine/curl downloader stage of the generated
# Dockerfile.
#
# Fail-closed by default: a RELEASED image (PREGA_BUNDLE_FALLBACK unset/false) is
# built ONLY from the prod bundle and ONLY if it matches its published hash -- a
# missing prod bundle, a missing feed hash, or a mismatch aborts the build, so a
# swapped S3 object can never be baked into a published image. The bundle (S3
# public/bundles) and its hash (served updates feed) are stored independently.
#
# PRE-GA CI ONLY: before GA the prod bundle/hash for a new version do not exist
# yet (they land at GA). When PREGA_BUNDLE_FALLBACK=true AND the prod bundle is
# absent, fall back to the testing bundle WITHOUT verification (there is no
# published hash to check yet) and warn loudly. This path is never taken for a
# released image.
set -eu

VERSION="${1:?usage: download_and_verify_bundle.sh <YYYYMMDD-NNN>}"
case "$VERSION" in
  [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9]) : ;;
  *) echo "ERROR: bad version format: $VERSION" >&2; exit 1 ;;
esac

FEED="https://updates.simplerisk.com/releases.xml"
PROD_URL="https://simplerisk-downloads.s3.amazonaws.com/public/bundles/simplerisk-${VERSION}.tgz"
TEST_URL="https://bundles-test.simplerisk.com/simplerisk-${VERSION}.tgz"
TGZ="/tmp/simplerisk-${VERSION}.tgz"

if curl -fsSL -o "$TGZ" "$PROD_URL"; then
  echo "Downloaded prod bundle for ${VERSION}; resolving published hash from ${FEED} ..."
  ENTRY="$(curl -fsSL "$FEED" | sed -n "/<release version=\"${VERSION}\">/,/<\/release>/p")"
  EXPECTED="$(printf '%s\n' "$ENTRY" | grep -oE '<bundle_sha256>[0-9a-f]{64}</bundle_sha256>' | grep -oE '[0-9a-f]{64}' | head -1 || true)"
  ALGO=sha256
  if [ -z "$EXPECTED" ]; then
    EXPECTED="$(printf '%s\n' "$ENTRY" | grep -oE '<bundle_md5>[0-9a-f]{32}</bundle_md5>' | grep -oE '[0-9a-f]{32}' | head -1 || true)"
    ALGO=md5
  fi
  if [ -z "$EXPECTED" ]; then
    echo "ERROR: no bundle_sha256 or bundle_md5 for ${VERSION} in ${FEED} -- refusing to extract an unverifiable prod bundle" >&2
    exit 1
  fi
  ACTUAL="$(${ALGO}sum "$TGZ" | cut -d' ' -f1)"
  if [ "$ACTUAL" != "$EXPECTED" ]; then
    echo "ERROR: bundle ${ALGO} mismatch for ${VERSION} -- expected ${EXPECTED}, got ${ACTUAL}" >&2
    exit 1
  fi
  echo "Bundle ${ALGO} verified (${ACTUAL})."
elif [ "${PREGA_BUNDLE_FALLBACK:-false}" = "true" ]; then
  echo "WARNING: prod bundle simplerisk-${VERSION}.tgz absent -- PRE-GA CI fallback to bundles-test (UNVERIFIED: the release has no published hash yet)." >&2
  curl -fsSL -o "$TGZ" "$TEST_URL"
else
  echo "ERROR: prod bundle simplerisk-${VERSION}.tgz not found and PREGA_BUNDLE_FALLBACK != true -- refusing to build a release from unverified bytes" >&2
  exit 1
fi

mkdir -p /var/www
tar xzf "$TGZ" -C /var/www
rm -f "$TGZ"
echo "Extracted bundle to /var/www."
