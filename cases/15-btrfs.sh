#!/usr/bin/env bash

set -euxo pipefail

CASE_NAME="$(basename "${BASH_SOURCE[0]%.sh}")"
CASE_NUM="${CASE_NAME%%-*}"
CASE_MNT="${CASE_MNT}"

DISK1_DEV="${DISK1_DEV}"

function cmd_up() {
    # Create and mount btrfs.
    sudo mkfs.btrfs -f "${DISK1_DEV}"
    mkdir -p "${CASE_MNT}"
    sudo mount "${DISK1_DEV}" "${CASE_MNT}"
    sudo chmod a+rwx "${CASE_MNT}"

    # Print status.
    lsblk "${DISK1_DEV}"
}

function cmd_exec() {
    env \
        CASE_NAME="${CASE_NAME}" \
        CASE_NUM="${CASE_NUM}" \
        CASE_DEV="${DISK1_DEV}" \
        CASE_MNT="${CASE_MNT}" \
        "${@}"
}

function cmd_down() {
    # Unmount btrfs.
    ! mountpoint "${CASE_MNT}" || sudo umount "${CASE_MNT}"
    ! [ -e "${CASE_MNT}" ] || sudo rmdir --ignore-fail-on-non-empty -p "${CASE_MNT}"
}

"cmd_${1}" "${@:2}"
