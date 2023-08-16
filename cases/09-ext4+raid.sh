#!/usr/bin/env bash

set -euxo pipefail

CASE_NAME="$(basename "${BASH_SOURCE[0]%.sh}")"
CASE_NUM="${CASE_NAME%%-*}"
CASE_MNT="${CASE_MNT}"

DISK1_DEV="${DISK1_DEV}"
DISK2_DEV="${DISK2_DEV}"

MD_NAME="md-${CASE_NUM}"
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
    mkdir -p "${CASE_MNT}"
    sudo mount "${MD_DEV}" "${CASE_MNT}"
    sudo chmod a+rwx "${CASE_MNT}"

    # Print status.
    lsblk "${DISK1_DEV}" "${DISK2_DEV}"
}

function cmd_exec() {
    env \
        CASE_NAME="${CASE_NAME}" \
        CASE_NUM="${CASE_NUM}" \
        CASE_DEV="${MD_DEV}" \
        CASE_MNT="${CASE_MNT}" \
        "${@}"
}

function cmd_down() {
    # Unmount ext4.
    ! mountpoint "${CASE_MNT}" || sudo umount "${CASE_MNT}"
    ! [ -e "${CASE_MNT}" ] || sudo rmdir --ignore-fail-on-non-empty -p "${CASE_MNT}"

    # Remove dm-raid.
    ! [ -e "${MD_DEV}" ] || sudo mdadm --stop "${MD_DEV}"
    sudo mdadm --zero-superblock "${DISK1_DEV}" || true
    sudo mdadm --zero-superblock "${DISK2_DEV}" || true
}

"cmd_${1}" "${@:2}"
