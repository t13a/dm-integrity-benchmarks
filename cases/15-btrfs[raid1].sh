#!/usr/bin/env bash

set -euxo pipefail

CASE_NAME="$(basename "${BASH_SOURCE[0]%.sh}")"
CASE_NUM="${CASE_NAME%%-*}"
CASE_MNT="${CASE_MNT}"

DISK1_DEV="${DISK1_DEV}"
DISK2_DEV="${DISK2_DEV}"

BTRFS_LABEL="btrfs-${CASE_NUM}"
BTRFS_DEV="${DISK1_DEV}"

function cmd_up() {
    # Create and mount btrfs.
    sudo mkfs.btrfs \
        -f \
        -d raid1 \
        -m raid1 \
        -L "${BTRFS_LABEL}" \
        "${DISK1_DEV}" \
        "${DISK2_DEV}"
    while ! [ -e "${BTRFS_DEV}" ]; do sleep 1; done # TODO: Wait properly.
    mkdir -p "${CASE_MNT}"
    sudo mount "${BTRFS_DEV}" "${CASE_MNT}"
    sudo chmod a+rwx "${CASE_MNT}"
    sudo btrfs scrub start -B -f "${BTRFS_DEV}"

    # Print status.
    lsblk "${DISK1_DEV}" "${DISK2_DEV}"
}

function cmd_exec() {
    env \
        CASE_NAME="${CASE_NAME}" \
        CASE_NUM="${CASE_NUM}" \
        CASE_DEV="${BTRFS_DEV}" \
        CASE_MNT="${CASE_MNT}" \
        "${@}"
}

function cmd_down() {
    # Unmount btrfs.
    ! mountpoint "${CASE_MNT}" || sudo umount "${CASE_MNT}"
    ! [ -e "${CASE_MNT}" ] || sudo rmdir --ignore-fail-on-non-empty -p "${CASE_MNT}"
}

"cmd_${1}" "${@:2}"
