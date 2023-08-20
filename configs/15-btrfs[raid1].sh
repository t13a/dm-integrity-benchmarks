#!/usr/bin/env bash

set -euxo pipefail

if [ -z "${DISK1_DEV:-}" ]; then echo "DISK1_DEV: not specified. skipping..." >&2; exit 0; fi
if [ -z "${DISK2_DEV:-}" ]; then echo "DISK2_DEV: not specified. skipping..." >&2; exit 0; fi
if [ -z "${TEST_MNT:-}" ]; then echo "TEST_MNT: not specified. skipping..." >&2; exit 0; fi

CONFIG_NAME="$(basename "${BASH_SOURCE[0]%.sh}")"
CONFIG_NUM="${CONFIG_NAME%%-*}"

BTRFS_LABEL="btrfs-${CONFIG_NUM}"
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
    mkdir -p "${TEST_MNT}"
    sudo mount -t btrfs "${BTRFS_DEV}" "${TEST_MNT}"
    sudo chmod a+rwx "${TEST_MNT}"
    sudo btrfs scrub start -B -f "${BTRFS_DEV}"

    # Print status.
    lsblk "${DISK1_DEV}" "${DISK2_DEV}"
}

function cmd_exec() {
    env \
        CONFIG_NAME="${CONFIG_NAME}" \
        CONFIG_NUM="${CONFIG_NUM}" \
        TEST_DEV="${BTRFS_DEV}" \
        TEST_MNT="${TEST_MNT}" \
        "${@}"
}

function cmd_down() {
    # Unmount btrfs.
    ! mountpoint "${TEST_MNT}" || sudo umount "${TEST_MNT}"
    ! [ -e "${TEST_MNT}" ] || sudo rmdir --ignore-fail-on-non-empty -p "${TEST_MNT}"
}

"cmd_${1}" "${@:2}"
