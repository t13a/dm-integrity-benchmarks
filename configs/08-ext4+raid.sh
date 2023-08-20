#!/usr/bin/env bash

set -euxo pipefail

CONFIG_NAME="$(basename "${BASH_SOURCE[0]%.sh}")"
CONFIG_NUM="${CONFIG_NAME%%-*}"
TEST_MNT="${TEST_MNT}"

DISK1_DEV="${DISK1_DEV}"
DISK2_DEV="${DISK2_DEV}"

MD_NAME="md-${CONFIG_NUM}"
MD_DEV="/dev/md/${MD_NAME}"

function cmd_up() {
    # Create dm-raid.
    sudo mdadm \
        --create \
        --force \
        --metadata=1.2 \
        --raid-devices=2 \
        --level=1 \
        "${MD_DEV}" \
        "${DISK1_DEV}" \
        "${DISK2_DEV}"
    sudo mdadm --wait "${MD_DEV}"
    sudo mdadm --detail "${MD_DEV}"

    # Create and mount ext4.
    sudo mkfs.ext4 -F "${MD_DEV}"
    mkdir -p "${TEST_MNT}"
    sudo mount "${MD_DEV}" "${TEST_MNT}"
    sudo chmod a+rwx "${TEST_MNT}"

    # Print status.
    lsblk "${DISK1_DEV}" "${DISK2_DEV}"
}

function cmd_exec() {
    env \
        CONFIG_NAME="${CONFIG_NAME}" \
        CONFIG_NUM="${CONFIG_NUM}" \
        TEST_DEV="${MD_DEV}" \
        TEST_MNT="${TEST_MNT}" \
        "${@}"
}

function cmd_down() {
    # Unmount ext4.
    ! mountpoint "${TEST_MNT}" || sudo umount "${TEST_MNT}"
    ! [ -e "${TEST_MNT}" ] || sudo rmdir --ignore-fail-on-non-empty -p "${TEST_MNT}"

    # Remove dm-raid.
    ! [ -e "${MD_DEV}" ] || sudo mdadm --stop "${MD_DEV}"
    sudo mdadm --zero-superblock "${DISK1_DEV}" || true
    sudo mdadm --zero-superblock "${DISK2_DEV}" || true
}

"cmd_${1}" "${@:2}"
