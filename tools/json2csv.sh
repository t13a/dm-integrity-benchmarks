#!/usr/bin/env bash

set -euo pipefail

echo 'drive,config,rw,bw_mbps'

[ "${#@}" -gt 0 ] || exit 0

jq -nr '
reduce inputs as $s (.; .[input_filename] += $s)
| to_entries
| map(
    (.key | split("/")[-2]) as $drive
    | (.key | split("/")[-1] | split(".")[0]) as $config
    | .value.jobs[]
    | {
        "drive": $drive,
        "config": $config,
        "rw": .jobname,
        "bw_mbps": ((.read.bw_bytes + .write.bw_bytes) * 100 / 1000 / 1000 | floor | . / 100),
    }
)
| sort_by(.drive, .config, .io)
| .[]
| "\(.drive),\(.config),\(.rw),\(.bw_mbps)"
' "${@}"