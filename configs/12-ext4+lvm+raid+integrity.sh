#!/usr/bin/env bash

set -euxo pipefail

if [ -z "${DISK1_DEV:-}" ]; then echo "DISK1_DEV: not specified. skipping..." >&2; exit 0; fi
if [ -z "${DISK2_DEV:-}" ]; then echo "DISK2_DEV: not specified. skipping..." >&2; exit 0; fi
if [ -z "${TEST_MNT:-}" ]; then echo "TEST_MNT: not specified. skipping..." >&2; exit 0; fi

CONFIG_NAME="$(basename "${BASH_SOURCE[0]%.sh}")"
CONFIG_NUM="${CONFIG_NAME%%-*}"

DISK1_INTEGRITY_NAME="disk1-integrity-${CONFIG_NUM}"
DISK1_INTEGRITY_DEV="/dev/mapper/${DISK1_INTEGRITY_NAME}"

DISK2_INTEGRITY_NAME="disk2-integrity-${CONFIG_NUM}"
DISK2_INTEGRITY_DEV="/dev/mapper/${DISK2_INTEGRITY_NAME}"

MD_NAME="md-${CONFIG_NUM}"
MD_DEV="/dev/md/${MD_NAME}"

VG_NAME="vg-${CONFIG_NUM}"

LV_NAME="lv"
LV_DEV="/dev/${VG_NAME}/${LV_NAME}"

function cmd_up() {
    # Create and open dm-integrity.
    sudo integritysetup format \
        --sector-size=4096 \
        --batch-mode \
        "${DISK1_DEV}"
    sudo integritysetup format \
        --sector-size=4096 \
        --batch-mode \
        "${DISK2_DEV}"
    sudo integritysetup open \
        --journal-commit-time=5000 \
        --batch-mode \
        "${DISK1_DEV}" \
        "${DISK1_INTEGRITY_NAME}"
    sudo integritysetup open \
        --journal-commit-time=5000 \
        --batch-mode \
        "${DISK2_DEV}" \
        "${DISK2_INTEGRITY_NAME}"
    sudo integritysetup status "${DISK1_INTEGRITY_NAME}"
    sudo integritysetup status "${DISK2_INTEGRITY_NAME}"

    # Create dm-raid.
    sudo mdadm \
        --create \
        --force \
        --metadata=1.2 \
        --raid-devices=2 \
        --level=1 \
        "${MD_DEV}" \
        "${DISK1_INTEGRITY_DEV}" \
        "${DISK2_INTEGRITY_DEV}"
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
    mkdir -p "${TEST_MNT}"
    sudo mount -t ext4 "${LV_DEV}" "${TEST_MNT}"
    sudo chmod a+rwx "${TEST_MNT}"

    # Print status.
    lsblk "${DISK1_DEV}" "${DISK2_DEV}"
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
    ! sudo pvs "${MD_DEV}" || sudo pvremove -f "${MD_DEV}"

    # Remove dm-raid.
    ! [ -e "${MD_DEV}" ] || sudo mdadm --stop "${MD_DEV}"
    sudo mdadm --zero-superblock "${DISK1_INTEGRITY_DEV}" || true
    sudo mdadm --zero-superblock "${DISK2_INTEGRITY_DEV}" || true

    # Close dm-integrity.
    ! [ -e "${DISK1_INTEGRITY_DEV}" ] || sudo integritysetup close "${DISK1_INTEGRITY_NAME}"
    ! [ -e "${DISK2_INTEGRITY_DEV}" ] || sudo integritysetup close "${DISK2_INTEGRITY_NAME}"
}

"cmd_${1}" "${@:2}"
