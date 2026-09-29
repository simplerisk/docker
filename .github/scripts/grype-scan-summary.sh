#!/usr/bin/env bash
# Print a Markdown table with one row per scanned image, so a run always shows that
# every scan finished and what it found, including the all-clear case.
#
# Usage: grype-scan-summary.sh <dir> <label>=<job-result> ...
#   <dir>/grype-<label>/grype.json   report per image (download-artifact layout)
#   <job-result>                     the scan job's needs.<job>.result
#
# Status per image:
#   no report / job did not succeed -> scan did not complete (never shown as clean)
#   report with no matches          -> no findings
#   report with matches             -> findings, counted by severity
set -euo pipefail

dir="${1:?usage: $0 <dir> <label>=<result>...}"
shift

echo "### Grype scan results"
echo
echo "| Image | Result |"
echo "| --- | --- |"
for pair in "$@"; do
  label="${pair%%=*}"
  result="${pair#*=}"
  report="$dir/grype-$label/grype.json"
  if [ ! -s "$report" ]; then
    status="❌ scan did not complete (no report; job ${result})"
  else
    count="$(jq '.matches | length' "$report")"
    if [ "$count" -eq 0 ]; then
      status="✅ No findings"
    else
      detail="$(jq -r 'def rank: {"Critical":0,"High":1,"Medium":2,"Low":3,"Negligible":4}[.] // 5;
                .matches | group_by(.vulnerability.severity)
                | sort_by(.[0].vulnerability.severity | rank)
                | map("\(length) \(.[0].vulnerability.severity)") | join(", ")' "$report")"
      status="⚠️ ${count} findings (${detail})"
    fi
  fi
  echo "| \`${label}\` | ${status} |"
done
