#!/usr/bin/env bash

set -euxo pipefail

if [ -z "${DISK1_DEV:-}" ]; then echo "DISK1_DEV: not specified. skipping..." >&2; exit 0; fi
if [ -z "${DISK2_DEV:-}" ]; then echo "DISK2_DEV: not specified. skipping..." >&2; exit 0; fi
if [ -z "${TEST_MNT:-}" ]; then echo "TEST_MNT: not specified. skipping..." >&2; exit 0; fi

CONFIG_NAME="$(basename "${BASH_SOURCE[0]%.sh}")"
CONFIG_NUM="${CONFIG_NAME%%-*}"

ZFS_POOL=tank
ZFS_FS=data

function cmd_up() {
    # Create and mount ZFS.
    sudo zpool create -f "${ZFS_POOL}" mirror "${DISK1_DEV}" "${DISK2_DEV}"
    sudo zfs create \
        -o mountpoint="$(realpath "${TEST_MNT}")" \
        -o primarycache=metadata \
        -o secondarycache=metadata \
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
