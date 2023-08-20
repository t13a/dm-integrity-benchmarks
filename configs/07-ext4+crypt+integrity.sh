#!/usr/bin/env bash

set -euxo pipefail

if [ -z "${DISK1_DEV:-}" ]; then echo "DISK1_DEV: not specified. skipping..." >&2; exit 0; fi
if [ -z "${TEST_MNT:-}" ]; then echo "TEST_MNT: not specified. skipping..." >&2; exit 0; fi

CONFIG_NAME="$(basename "${BASH_SOURCE[0]%.sh}")"
CONFIG_NUM="${CONFIG_NAME%%-*}"

KEY_FILE="$(dirname "${BASH_SOURCE[0]}")/key.bin"

DISK1_INTEGRITY_NAME="disk1-integrity-${CONFIG_NUM}"
DISK1_INTEGRITY_DEV="/dev/mapper/${DISK1_INTEGRITY_NAME}"
DISK1_CRYPT_NAME="disk1-crypt-${CONFIG_NUM}"
DISK1_CRYPT_DEV="/dev/mapper/${DISK1_CRYPT_NAME}"

function cmd_up() {
    # Create and open dm-integrity (no journal).
    sudo integritysetup format -q "${DISK1_DEV}"
    sudo integritysetup open -q "${DISK1_DEV}" "${DISK1_INTEGRITY_NAME}"
    sudo integritysetup status "${DISK1_INTEGRITY_NAME}"

    # Create and open dm-crypt.
    sudo cryptsetup luksFormat --key-file "${KEY_FILE}" -q "${DISK1_INTEGRITY_DEV}"
    sudo cryptsetup open \
        --key-file "${KEY_FILE}" \
        --perf-same_cpu_crypt \
        --perf-submit_from_crypt_cpus \
        --perf-no_{read,write}_workqueue \
        --batch-mode \
        "${DISK1_INTEGRITY_DEV}" \
        "${DISK1_CRYPT_NAME}"
    sudo cryptsetup status "${DISK1_CRYPT_NAME}"

    # Create and mount ext4.
    sudo mkfs.ext4 -F "${DISK1_CRYPT_DEV}"
    mkdir -p "${TEST_MNT}"
    sudo mount "${DISK1_CRYPT_DEV}" "${TEST_MNT}"
    sudo chmod a+rwx "${TEST_MNT}"

    # Print status.
    lsblk "${DISK1_DEV}"
}

function cmd_exec() {
    env \
        CONFIG_NAME="${CONFIG_NAME}" \
        CONFIG_NUM="${CONFIG_NUM}" \
        TEST_DEV="${DISK1_CRYPT_DEV}" \
        TEST_MNT="${TEST_MNT}" \
        "${@}"
}

function cmd_down() {
    # Unmount ext4.
    ! mountpoint "${TEST_MNT}" || sudo umount "${TEST_MNT}"
    ! [ -e "${TEST_MNT}" ] || sudo rmdir --ignore-fail-on-non-empty -p "${TEST_MNT}"

    # Close dm-crypt.
    ! [ -e "${DISK1_CRYPT_DEV}" ] || sudo cryptsetup close "${DISK1_CRYPT_NAME}"

    # Close dm-integrity.
    ! [ -e "${DISK1_INTEGRITY_DEV}" ] || sudo integritysetup close "${DISK1_INTEGRITY_NAME}"
}

"cmd_${1}" "${@:2}"
