#!/usr/bin/env bash

set -euo pipefail

PAYLOAD_FILE="${CASE_MNT}/payload.bin"
PAYLOAD_SIZE='512M'

dd if=/dev/urandom of="${PAYLOAD_FILE}" bs="${PAYLOAD_SIZE}" count=1 status=none >&2
trap "rm -f '${PAYLOAD_FILE}'" EXIT

case "${1}" in
    seq-*)
        BS='1M'
        COUNT='100'
        ;;
    rand-*)
        BS='4K'
        COUNT='100'
        ;;
    *)
        exit 1
        ;;
esac

case "${1}" in
    *-read)
        IF="${PAYLOAD_FILE}"
        OF=/dev/null
        ;;
    *-write)
        IF=/dev/zero
        OF="${PAYLOAD_FILE}"
        ;;
    *)
        exit 1
        ;;
esac

for i in $(seq 1 10)
do
    sudo sync
    sudo tee /proc/sys/vm/drop_caches <<< '3' >/dev/null
    dd if="${IF}" of="${OF}" bs="${BS}" count="${COUNT}" 2>&1
done
