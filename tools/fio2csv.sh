#!/usr/bin/env bash

set -euo pipefail

[ "${#@}" -gt 0 ] || exit 0

jq -nr '
reduce inputs as $s (.; .[input_filename] += $s)
| to_entries
| map(
    (.key | split("/")[-1] | split(".")[0]) as $case
    | .value.jobs[]
    | {
        "jobname": .jobname,
        "case": $case,
        "bw_bytes": (.read.bw_bytes + .write.bw_bytes),
    }
)
| sort_by(.jobname, .case)
| .[]
| "\(.jobname),\(.case),\(.bw_bytes),\(.bw_bytes * 100 / 1000 / 1000 | floor | . / 100)"
' "${@}"