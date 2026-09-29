#!/usr/bin/env bash
# Build a Slack incoming-webhook payload from the grype JSON reports of one
# container-validation run.
#
# Usage: grype-slack-digest.sh <dir>
#   <dir>/<grype-LABEL>/grype.json   one report per scanned image (download-artifact layout)
#
# Env (all optional, used only for the message header/links):
#   RUN_URL  link to the workflow run      REF  branch or PR ref
#
# Prints the JSON payload on stdout, or nothing when there are no findings.
# Findings are de-duplicated across images (one line per package + vulnerability,
# listing every image it affects), sorted by package, then severity (worst first),
# then vulnerability ID, so the message reads as "what is vulnerable right now".
set -euo pipefail

dir="${1:?usage: $0 <dir>}"
shopt -s nullglob
files=("$dir"/*/grype.json)
[ "${#files[@]}" -gt 0 ] || exit 0

jq -n \
  --arg run_url "${RUN_URL:-}" \
  --arg ref "${REF:-}" \
  --argjson max_blocks 45 \
  --argjson max_chars 2900 '
  def rank: {"Critical":0,"High":1,"Medium":2,"Low":3,"Negligible":4}[.] // 5;

  def chunk($lines):
    reduce $lines[] as $l ([""];
      if (.[-1] | length) + ($l | length) + 1 > $max_chars then . + [$l]
      else .[-1] += (if .[-1] == "" then "" else "\n" end) + $l
      end);

  [inputs
   | (input_filename | split("/")[-2] | ltrimstr("grype-")) as $label
   | .matches[]
   | {pkg: .artifact.name, ver: .artifact.version,
      fixed: ((.vulnerability.fix.versions // []) | join(", ")),
      id: .vulnerability.id, sev: .vulnerability.severity,
      url: (.vulnerability.dataSource // ""), label: $label}] as $rows
  | if ($rows | length) == 0 then empty else
    ($rows | group_by([.pkg, .id]) | map(. + [] | {
        pkg: .[0].pkg, id: .[0].id, sev: .[0].sev, url: .[0].url,
        ver: ([.[].ver] | unique | join(", ")),
        fixed: ([.[].fixed] | unique | join(" | ")),
        images: ([.[].label] | unique | join(", "))})
     | sort_by([.pkg, (.sev | rank), .id])) as $vulns
    | ($vulns | map(
        "`\(.pkg)` \(.ver) → \(.fixed) · " +
        (if .url != "" then "<\(.url)|\(.id)>" else .id end) +
        " · *\(.sev)* · \(.images)")) as $lines
    | chunk($lines) as $chunks
    | ($vulns | group_by(.sev) | map({(.[0].sev): length}) | add) as $by_sev
    | ($by_sev | to_entries | sort_by(.key | rank) | map("\(.value) \(.key)") | join(", ")) as $summary
    | {
        text: "Grype: \($vulns | length) vulnerabilities in \($rows | map(.label) | unique | length) image(s)",
        blocks: (
          [{type: "header", text: {type: "plain_text",
             text: "Grype findings: \($vulns | length) unique (\($summary))"}},
           {type: "context", elements: [{type: "mrkdwn",
             text: ("`\($ref)`" + (if $run_url != "" then " · <\($run_url)|workflow run>" else "" end))}]}]
          + ($chunks[:$max_blocks] | map({type: "section", text: {type: "mrkdwn", text: .}}))
          + (if ($chunks | length) > $max_blocks
             then [{type: "context", elements: [{type: "mrkdwn",
                    text: "List truncated; see the workflow run for the full report."}]}]
             else [] end))
      }
    end
' "${files[@]}"
