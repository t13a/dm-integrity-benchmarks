#!/usr/bin/env bash

set -euxo pipefail

CASE_NAME="$(basename "${BASH_SOURCE[0]%.sh}")"
CASE_NUM="${CASE_NAME%%-*}"
CASE_MNT="${CASE_MNT}"

KEY_FILE="$(dirname "${BASH_SOURCE[0]}")/key.bin"

DISK1_DEV="${DISK1_DEV}"
DISK1_CRYPT_NAME="disk1-crypt-${CASE_NUM}"
DISK1_CRYPT_DEV="/dev/mapper/${DISK1_CRYPT_NAME}"

DISK2_DEV="${DISK2_DEV}"
DISK2_CRYPT_NAME="disk2-crypt-${CASE_NUM}"
DISK2_CRYPT_DEV="/dev/mapper/${DISK2_CRYPT_NAME}"

BTRFS_LABEL="btrfs-${CASE_NUM}"
BTRFS_DEV="/dev/disk/by-label/${BTRFS_LABEL}"

function cmd_up() {
    # Create and open dm-crypt.
    sudo cryptsetup luksFormat --key-file "${KEY_FILE}" -q "${DISK1_DEV}"
    sudo cryptsetup luksFormat --key-file "${KEY_FILE}" -q "${DISK2_DEV}"
    sudo cryptsetup open --key-file "${KEY_FILE}" -q "${DISK1_DEV}" "${DISK1_CRYPT_NAME}"
    sudo cryptsetup open --key-file "${KEY_FILE}" -q "${DISK2_DEV}" "${DISK2_CRYPT_NAME}"
    sudo cryptsetup status "${DISK1_CRYPT_NAME}"
    sudo cryptsetup status "${DISK2_CRYPT_NAME}"

    # Create and mount btrfs.
    sudo mkfs.btrfs \
        -f \
        -d raid1 \
        -m raid1 \
        -L "${BTRFS_LABEL}" \
        "${DISK1_CRYPT_DEV}" \
        "${DISK2_CRYPT_DEV}"
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

    # Close dm-crypt.
    ! [ -e "${DISK1_CRYPT_DEV}" ] || sudo cryptsetup close "${DISK1_CRYPT_NAME}"
    ! [ -e "${DISK2_CRYPT_DEV}" ] || sudo cryptsetup close "${DISK2_CRYPT_NAME}"
}

"cmd_${1}" "${@:2}"
