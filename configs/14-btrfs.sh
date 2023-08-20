#!/usr/bin/env bash

set -euxo pipefail

CONFIG_NAME="$(basename "${BASH_SOURCE[0]%.sh}")"
CONFIG_NUM="${CONFIG_NAME%%-*}"
TEST_MNT="${TEST_MNT}"

DISK1_DEV="${DISK1_DEV}"

function cmd_up() {
    # Create and mount btrfs.
    sudo mkfs.btrfs -f "${DISK1_DEV}"
    mkdir -p "${TEST_MNT}"
    sudo mount "${DISK1_DEV}" "${TEST_MNT}"
    sudo chmod a+rwx "${TEST_MNT}"

    # Print status.
    lsblk "${DISK1_DEV}"
}

function cmd_exec() {
    env \
        CONFIG_NAME="${CONFIG_NAME}" \
        CONFIG_NUM="${CONFIG_NUM}" \
        TEST_DEV="${DISK1_DEV}" \
        TEST_MNT="${TEST_MNT}" \
        "${@}"
}

function cmd_down() {
    # Unmount btrfs.
    ! mountpoint "${TEST_MNT}" || sudo umount "${TEST_MNT}"
    ! [ -e "${TEST_MNT}" ] || sudo rmdir --ignore-fail-on-non-empty -p "${TEST_MNT}"
}

"cmd_${1}" "${@:2}"
