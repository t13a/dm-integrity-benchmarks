#!/usr/bin/env bash

set -euxo pipefail

CASE_NAME="$(basename "${BASH_SOURCE[0]%.sh}")"
CASE_NUM="${CASE_NAME%%-*}"
CASE_MNT="${CASE_MNT}"

DISK1_DEV="${DISK1_DEV}"
DISK1_INTEGRITY_NAME="disk1-integrity-${CASE_NUM}"
DISK1_INTEGRITY_DEV="/dev/mapper/${DISK1_INTEGRITY_NAME}"

function cmd_up() {
    # Create and open dm-integrity.
    sudo integritysetup format --integrity crc32 -q "${DISK1_DEV}"
    sudo integritysetup open --integrity crc32 -q "${DISK1_DEV}" "${DISK1_INTEGRITY_NAME}"
    sudo integritysetup status "${DISK1_INTEGRITY_NAME}"

    # Create and mount ext4.
    sudo mkfs.ext4 -F "${DISK1_INTEGRITY_DEV}"
    mkdir -p "${CASE_MNT}"
    sudo mount "${DISK1_INTEGRITY_DEV}" "${CASE_MNT}"
    sudo chmod a+rwx "${CASE_MNT}"

    # Print status.
    lsblk "${DISK1_DEV}"
}

function cmd_exec() {
    env \
        CASE_NAME="${CASE_NAME}" \
        CASE_NUM="${CASE_NUM}" \
        CASE_DEV="${DISK1_INTEGRITY_DEV}" \
        CASE_MNT="${CASE_MNT}" \
        "${@}"
}

function cmd_down() {
    # Unmount ext4.
    ! mountpoint "${CASE_MNT}" || sudo umount "${CASE_MNT}"
    ! [ -e "${CASE_MNT}" ] || sudo rmdir --ignore-fail-on-non-empty -p "${CASE_MNT}"

    # Close dm-integrity.
    ! [ -e "${DISK1_INTEGRITY_DEV}" ] || sudo integritysetup close "${DISK1_INTEGRITY_NAME}"
}

"cmd_${1}" "${@:2}"
