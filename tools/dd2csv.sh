#!/usr/bin/env bash

set -euo pipefail

[ "${#@}" -gt 0 ] || exit 0

for LOG_FILE in "${@}"
do
    awk \
        -F' ' \
        -v log_access="$(basename "${LOG_FILE%.log}" | cut -d- -f1-2)" \
        -v log_case="$(basename "${LOG_FILE%.log}" | cut -d- -f3-)" \
        '{ if ($8) { printf("%s,%s,%.2f,%.2f\n", log_access, log_case, $1 / $8, $1 / $8 / 1024 / 1024) } }' \
        "${LOG_FILE}"
done
