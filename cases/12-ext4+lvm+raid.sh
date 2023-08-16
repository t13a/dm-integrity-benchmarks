#!/usr/bin/env bash

set -euxo pipefail

CASE_NAME="$(basename "${BASH_SOURCE[0]%.sh}")"
CASE_NUM="${CASE_NAME%%-*}"
CASE_MNT="${CASE_MNT}"

DISK1_DEV="${DISK1_DEV}"
DISK2_DEV="${DISK2_DEV}"

MD_NAME="md-${CASE_NUM}"
MD_DEV="/dev/md/${MD_NAME}"

VG_NAME="vg-${CASE_NUM}"

LV_NAME="lv"
LV_DEV="/dev/${VG_NAME}/${LV_NAME}"

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

    # Create PV.
    sudo pvcreate -f "${MD_DEV}"
    sudo pvs "${MD_DEV}"

    # Create VG.
    sudo vgcreate -f "${VG_NAME}" "${MD_DEV}"
    sudo vgs "${VG_NAME}"

    # Create LV.
    sudo lvcreate -l '100%FREE' -n "${LV_NAME}" -y -Z y "${VG_NAME}"
    sudo lvs "${LV_DEV}"

    # Create and mount ext4.
    sudo mkfs.ext4 -F "${LV_DEV}"
    mkdir -p "${CASE_MNT}"
    sudo mount "${LV_DEV}" "${CASE_MNT}"
    sudo chmod a+rwx "${CASE_MNT}"

    # Print status.
    lsblk "${DISK1_DEV}" "${DISK2_DEV}"
}

function cmd_exec() {
    env \
        CASE_NAME="${CASE_NAME}" \
        CASE_NUM="${CASE_NUM}" \
        CASE_DEV="${LV_DEV}" \
        CASE_MNT="${CASE_MNT}" \
        "${@}"
}

function cmd_down() {
    # Unmount ext4.
    ! mountpoint "${CASE_MNT}" || sudo umount "${CASE_MNT}"
    ! [ -e "${CASE_MNT}" ] || sudo rmdir --ignore-fail-on-non-empty -p "${CASE_MNT}"

    # Remove LV.
    ! sudo lvs "${LV_DEV}" || sudo lvremove -f "${LV_DEV}"

    # Remove VG.
    ! sudo vgs "${VG_NAME}" || sudo vgremove -f "${VG_NAME}"

    # Remove PV.
    ! sudo pvs "${MD_DEV}" || sudo pvremove -f "${MD_DEV}"

    # Remove dm-raid.
    ! [ -e "${MD_DEV}" ] || sudo mdadm --stop "${MD_DEV}"
    sudo mdadm --zero-superblock "${DISK1_DEV}" || true
    sudo mdadm --zero-superblock "${DISK2_DEV}" || true
}

"cmd_${1}" "${@:2}"
