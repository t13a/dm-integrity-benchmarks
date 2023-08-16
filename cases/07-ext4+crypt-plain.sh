#!/usr/bin/env bash

set -euxo pipefail

CASE_NAME="$(basename "${BASH_SOURCE[0]%.sh}")"
CASE_NUM="${CASE_NAME%%-*}"
CASE_MNT="${CASE_MNT}"

KEY_FILE="$(dirname "${BASH_SOURCE[0]}")/key.bin"

DISK1_DEV="${DISK1_DEV}"
DISK1_CRYPT_NAME="disk1-crypt-${CASE_NUM}"
DISK1_CRYPT_DEV="/dev/mapper/${DISK1_CRYPT_NAME}"

function cmd_up() {
    # Create and open dm-crypt (plain mode).
    sudo cryptsetup open --type plain --cipher aes-xts-plain64 --key-file "${KEY_FILE}" --key-size 512 -q "${DISK1_DEV}" "${DISK1_CRYPT_NAME}"
    sudo cryptsetup status "${DISK1_CRYPT_NAME}"

    # Create and mount ext4.
    sudo mkfs.ext4 -F "${DISK1_CRYPT_DEV}"
    mkdir -p "${CASE_MNT}"
    sudo mount "${DISK1_CRYPT_DEV}" "${CASE_MNT}"
    sudo chmod a+rwx "${CASE_MNT}"

    # Print status.
    lsblk "${DISK1_DEV}"
}

function cmd_exec() {
    env \
        CASE_NAME="${CASE_NAME}" \
        CASE_NUM="${CASE_NUM}" \
        CASE_DEV="${DISK1_CRYPT_DEV}" \
        CASE_MNT="${CASE_MNT}" \
        "${@}"
}

function cmd_down() {
    # Unmount ext4.
    ! mountpoint "${CASE_MNT}" || sudo umount "${CASE_MNT}"
    ! [ -e "${CASE_MNT}" ] || sudo rmdir --ignore-fail-on-non-empty -p "${CASE_MNT}"

    # Close dm-crypt.
    ! [ -e "${DISK1_CRYPT_DEV}" ] || sudo cryptsetup close "${DISK1_CRYPT_NAME}"
}

"cmd_${1}" "${@:2}"
