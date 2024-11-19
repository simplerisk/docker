#!/usr/bin/env bash

set -euo pipefail

SCRIPT_LOCATION="$(dirname "$(readlink -f "$0")")"
readonly SCRIPT_LOCATION

[ -z "${1:-}" ] && echo "No release version provided. Aborting." && exit 1 || release=$1

for workflow in "$SCRIPT_LOCATION"/.github/workflows/push*; do
  sed -i -r "s/(version:) \"[0-9]{8,}-[0-9]{3,}\"/\1 \"${release}\"/g" "$workflow"
done
