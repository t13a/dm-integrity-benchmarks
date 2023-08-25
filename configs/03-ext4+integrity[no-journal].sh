#!/usr/bin/env bash

set -euxo pipefail

if [ -z "${DISK1_DEV:-}" ]; then echo "DISK1_DEV: not specified. skipping..." >&2; exit 0; fi
if [ -z "${TEST_MNT:-}" ]; then echo "TEST_MNT: not specified. skipping..." >&2; exit 0; fi

CONFIG_NAME="$(basename "${BASH_SOURCE[0]%.sh}")"
CONFIG_NUM="${CONFIG_NAME%%-*}"

DISK1_INTEGRITY_NAME="disk1-integrity-${CONFIG_NUM}"
DISK1_INTEGRITY_DEV="/dev/mapper/${DISK1_INTEGRITY_NAME}"

function cmd_up() {
    # Create and open dm-integrity (no journal).
    sudo integritysetup format --sector-size=4096 --integrity-no-journal -q "${DISK1_DEV}"
    sudo integritysetup open --integrity-no-journal -q "${DISK1_DEV}" "${DISK1_INTEGRITY_NAME}"
    sudo integritysetup status "${DISK1_INTEGRITY_NAME}"

    # Create and mount ext4.
    sudo mkfs.ext4 -F "${DISK1_INTEGRITY_DEV}"
    mkdir -p "${TEST_MNT}"
    sudo mount -t ext4 "${DISK1_INTEGRITY_DEV}" "${TEST_MNT}"
    sudo chmod a+rwx "${TEST_MNT}"

    # Print status.
    lsblk "${DISK1_DEV}"
}

function cmd_exec() {
    env \
        CONFIG_NAME="${CONFIG_NAME}" \
        CONFIG_NUM="${CONFIG_NUM}" \
        TEST_DEV="${DISK1_INTEGRITY_DEV}" \
        TEST_MNT="${TEST_MNT}" \
        "${@}"
}

function cmd_down() {
    # Unmount ext4.
    ! mountpoint "${TEST_MNT}" || sudo umount "${TEST_MNT}"
    ! [ -e "${TEST_MNT}" ] || sudo rmdir --ignore-fail-on-non-empty -p "${TEST_MNT}"

    # Close dm-integrity.
    ! [ -e "${DISK1_INTEGRITY_DEV}" ] || sudo integritysetup close "${DISK1_INTEGRITY_NAME}"
}

"cmd_${1}" "${@:2}"
