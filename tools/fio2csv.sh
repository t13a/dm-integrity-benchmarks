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
        "jobname_order": (.jobname as $s | ["seq-read", "seq-write", "rand-read", "rand-write"] | index($s)),
        "case": $case,
        "bw_bytes": (.read.bw_bytes + .write.bw_bytes),
    }
)
| sort_by(.jobname_order, .case)
| .[]
| "\(.jobname),\(.case),\(.bw_bytes),\(.bw_bytes * 100 / 1024 / 1024 | floor | . / 100)"
' "${@}"