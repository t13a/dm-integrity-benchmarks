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

ZFS_POOL=tank
ZFS_FS=data

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

    # Create and mount ZFS.
    sudo zpool create -f "${ZFS_POOL}" mirror "${DISK1_CRYPT_DEV}" "${DISK2_CRYPT_DEV}"
    sudo zfs create \
        -o mountpoint="$(realpath "${TEST_MNT}")" \
        -o primarycache=none \
        "${ZFS_POOL}/${ZFS_FS}"
    sudo zfs list "${ZFS_POOL}" "${ZFS_POOL}/${ZFS_FS}"
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
    # Unmount and delete ZFS.
    ! sudo zfs list "${ZFS_POOL}/${ZFS_FS}" || sudo zfs destroy "${ZFS_POOL}/${ZFS_FS}"
    ! sudo zpool list "${ZFS_POOL}" || sudo zpool destroy "${ZFS_POOL}"
    ! [ -e "${TEST_MNT}" ] || sudo rmdir --ignore-fail-on-non-empty -p "${TEST_MNT}"
}

"cmd_${1}" "${@:2}"
