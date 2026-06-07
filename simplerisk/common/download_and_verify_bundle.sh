#!/bin/sh
# Download the released SimpleRisk bundle for the given version and verify it
# against the sha256 (or md5 fallback) published in the production updates feed
# before extracting into /var/www. Fail-closed: the build aborts if the bundle
# does not match its published hash, or if the feed publishes no hash for the
# version. Run from the alpine/curl downloader stage of the generated Dockerfile.
#
# The bundle (S3 public/bundles) and the hash (served updates feed) are
# independently stored, so a swapped S3 object fails the build instead of being
# baked into a published image.
set -eu

VERSION="${1:?usage: download_and_verify_bundle.sh <YYYYMMDD-NNN>}"
case "$VERSION" in
  [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9]) : ;;
  *) echo "ERROR: bad version format: $VERSION" >&2; exit 1 ;;
esac

FEED="https://updates.simplerisk.com/releases.xml"
BUNDLE_URL="https://simplerisk-downloads.s3.amazonaws.com/public/bundles/simplerisk-${VERSION}.tgz"
TGZ="/tmp/simplerisk-${VERSION}.tgz"

echo "Downloading bundle for ${VERSION} ..."
curl -fsSL -o "$TGZ" "$BUNDLE_URL"

echo "Resolving published hash from ${FEED} ..."
ENTRY="$(curl -fsSL "$FEED" | sed -n "/<release version=\"${VERSION}\">/,/<\/release>/p")"
EXPECTED="$(printf '%s\n' "$ENTRY" | grep -oE '<bundle_sha256>[0-9a-f]{64}</bundle_sha256>' | grep -oE '[0-9a-f]{64}' | head -1 || true)"
ALGO=sha256
if [ -z "$EXPECTED" ]; then
  EXPECTED="$(printf '%s\n' "$ENTRY" | grep -oE '<bundle_md5>[0-9a-f]{32}</bundle_md5>' | grep -oE '[0-9a-f]{32}' | head -1 || true)"
  ALGO=md5
fi
if [ -z "$EXPECTED" ]; then
  echo "ERROR: no bundle_sha256 or bundle_md5 for ${VERSION} in the updates feed -- refusing to extract an unverifiable bundle" >&2
  exit 1
fi

ACTUAL="$(${ALGO}sum "$TGZ" | cut -d' ' -f1)"
if [ "$ACTUAL" != "$EXPECTED" ]; then
  echo "ERROR: bundle ${ALGO} mismatch for ${VERSION} -- expected ${EXPECTED}, got ${ACTUAL}" >&2
  exit 1
fi
echo "Bundle ${ALGO} verified (${ACTUAL})."

mkdir -p /var/www
tar xzf "$TGZ" -C /var/www
rm -f "$TGZ"
echo "Extracted bundle to /var/www."
