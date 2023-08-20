#!/usr/bin/env bash

set -euxo pipefail

CONFIG_NAME="$(basename "${BASH_SOURCE[0]%.sh}")"
CONFIG_NUM="${CONFIG_NAME%%-*}"
TEST_MNT="${TEST_MNT}"

DISK1_DEV="${DISK1_DEV}"

VG_NAME="vg-${CONFIG_NUM}"

LV_NAME="lv"
LV_DEV="/dev/${VG_NAME}/${LV_NAME}"

function cmd_up() {
    # Create PV.
    sudo pvcreate -f "${DISK1_DEV}"
    sudo pvs "${DISK1_DEV}"

    # Create VG.
    sudo vgcreate -f "${VG_NAME}" "${DISK1_DEV}"
    sudo vgs "${VG_NAME}"

    # Create LV.
    sudo lvcreate -l '100%FREE' -n "${LV_NAME}" -y -Z y "${VG_NAME}"
    sudo lvs "${LV_DEV}"

    # Create and mount ext4.
    sudo mkfs.ext4 -F "${LV_DEV}"
    mkdir -p "${TEST_MNT}"
    sudo mount "${LV_DEV}" "${TEST_MNT}"
    sudo chmod a+rwx "${TEST_MNT}"

    # Print status.
    lsblk "${DISK1_DEV}"
}

function cmd_exec() {
    env \
        CONFIG_NAME="${CONFIG_NAME}" \
        CONFIG_NUM="${CONFIG_NUM}" \
        TEST_DEV="${LV_DEV}" \
        TEST_MNT="${TEST_MNT}" \
        "${@}"
}

function cmd_down() {
    # Unmount ext4.
    ! mountpoint "${TEST_MNT}" || sudo umount "${TEST_MNT}"
    ! [ -e "${TEST_MNT}" ] || sudo rmdir --ignore-fail-on-non-empty -p "${TEST_MNT}"

    # Remove LV.
    ! sudo lvs "${LV_DEV}" || sudo lvremove -f "${LV_DEV}"

    # Remove VG.
    ! sudo vgs "${VG_NAME}" || sudo vgremove -f "${VG_NAME}"

    # Remove PV.
    ! sudo pvs "${DISK1_DEV}" || sudo pvremove -f "${DISK1_DEV}"
}

"cmd_${1}" "${@:2}"
