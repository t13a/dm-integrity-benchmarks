#!/usr/bin/env bash

set -euxo pipefail

if [ -z "${DISK1_DEV:-}" ]; then echo "DISK1_DEV: not specified. skipping..." >&2; exit 0; fi
if [ -z "${DISK2_DEV:-}" ]; then echo "DISK2_DEV: not specified. skipping..." >&2; exit 0; fi
if [ -z "${TEST_MNT:-}" ]; then echo "TEST_MNT: not specified. skipping..." >&2; exit 0; fi

CONFIG_NAME="$(basename "${BASH_SOURCE[0]%.sh}")"
CONFIG_NUM="${CONFIG_NAME%%-*}"

KEY_FILE="$(dirname "${BASH_SOURCE[0]}")/key.bin"

DISK1_CRYPT_NAME="disk1-crypt-${CONFIG_NUM}"
DISK1_CRYPT_DEV="/dev/mapper/${DISK1_CRYPT_NAME}"

DISK2_CRYPT_NAME="disk2-crypt-${CONFIG_NUM}"
DISK2_CRYPT_DEV="/dev/mapper/${DISK2_CRYPT_NAME}"

BTRFS_LABEL="btrfs-${CONFIG_NUM}"
BTRFS_DEV="${DISK1_CRYPT_DEV}"

function cmd_up() {
    # Create and open dm-crypt.
    sudo cryptsetup luksFormat --key-file "${KEY_FILE}" -q "${DISK1_DEV}"
    sudo cryptsetup luksFormat --key-file "${KEY_FILE}" -q "${DISK2_DEV}"
    sudo cryptsetup open \
        --key-file "${KEY_FILE}" \
        --perf-same_cpu_crypt \
        --perf-submit_from_crypt_cpus \
        --perf-no_{read,write}_workqueue \
        --batch-mode \
        "${DISK1_DEV}" \
        "${DISK1_CRYPT_NAME}"
    sudo cryptsetup open \
        --key-file "${KEY_FILE}" \
        --perf-same_cpu_crypt \
        --perf-submit_from_crypt_cpus \
        --perf-no_{read,write}_workqueue \
        --batch-mode \
        "${DISK2_DEV}" \
        "${DISK2_CRYPT_NAME}"
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
    mkdir -p "${TEST_MNT}"
    sudo mount "${BTRFS_DEV}" "${TEST_MNT}"
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

    # Close dm-crypt.
    ! [ -e "${DISK1_CRYPT_DEV}" ] || sudo cryptsetup close "${DISK1_CRYPT_NAME}"
    ! [ -e "${DISK2_CRYPT_DEV}" ] || sudo cryptsetup close "${DISK2_CRYPT_NAME}"
}

"cmd_${1}" "${@:2}"
