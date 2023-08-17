#!/usr/bin/env bash

set -euo pipefail

echo 'IO,Case,Throughput (B/s),Throughput (MB/s)'

[ "${#@}" -gt 0 ] || exit 0

for LOG_FILE in "${@}"
do
    awk \
        -F' ' \
        -v log_io="$(basename "${LOG_FILE%.log}" | cut -d- -f1-2)" \
        -v log_case="$(basename "${LOG_FILE%.log}" | cut -d- -f3-)" \
        '{ if ($8) { printf("%s,%s,%.2f,%.2f\n", log_io, log_case, $1 / $8, $1 / $8 / 1000 / 1000) } }' \
        "${LOG_FILE}"
done
