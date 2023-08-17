#!/usr/bin/env bash

set -euxo pipefail

CASE_NAME="$(basename "${BASH_SOURCE[0]%.sh}")"
CASE_NUM="${CASE_NAME%%-*}"
CASE_MNT="${CASE_MNT}"

KEY_FILE="$(dirname "${BASH_SOURCE[0]}")/key.bin"

DISK1_DEV="${DISK1_DEV}"
DISK1_INTEGRITY_NAME="disk1-integrity-${CASE_NUM}"
DISK1_INTEGRITY_DEV="/dev/mapper/${DISK1_INTEGRITY_NAME}"
DISK1_CRYPT_NAME="disk1-crypt-${CASE_NUM}"
DISK1_CRYPT_DEV="/dev/mapper/${DISK1_CRYPT_NAME}"

function cmd_up() {
    # Create and open dm-integrity (no journal).
    sudo integritysetup format --integrity sha256 --integrity-no-journal -q "${DISK1_DEV}"
    sudo integritysetup open --integrity sha256 --integrity-no-journal -q "${DISK1_DEV}" "${DISK1_INTEGRITY_NAME}"
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

    # Close dm-integrity.
    ! [ -e "${DISK1_INTEGRITY_DEV}" ] || sudo integritysetup close "${DISK1_INTEGRITY_NAME}"
}

"cmd_${1}" "${@:2}"