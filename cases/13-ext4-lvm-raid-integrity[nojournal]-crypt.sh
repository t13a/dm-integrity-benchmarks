#!/usr/bin/env bash

set -euxo pipefail

CASE_NAME="$(basename "${BASH_SOURCE[0]%.sh}")"
CASE_NUM="${CASE_NAME%%-*}"
CASE_MNT="${CASE_MNT}"

KEY_FILE="$(dirname "${BASH_SOURCE[0]}")/key.bin"

DISK1_DEV="${DISK1_DEV}"
DISK1_CRYPT_NAME="disk1-crypt-${CASE_NUM}"
DISK1_CRYPT_DEV="/dev/mapper/${DISK1_CRYPT_NAME}"
DISK1_INTEGRITY_NAME="disk1-integrity-${CASE_NUM}"
DISK1_INTEGRITY_DEV="/dev/mapper/${DISK1_INTEGRITY_NAME}"

DISK2_DEV="${DISK2_DEV}"
DISK2_CRYPT_NAME="disk2-crypt-${CASE_NUM}"
DISK2_CRYPT_DEV="/dev/mapper/${DISK2_CRYPT_NAME}"
DISK2_INTEGRITY_NAME="disk2-integrity-${CASE_NUM}"
DISK2_INTEGRITY_DEV="/dev/mapper/${DISK2_INTEGRITY_NAME}"

MD_NAME="md-${CASE_NUM}"
MD_DEV="/dev/md/${MD_NAME}"

VG_NAME="vg-${CASE_NUM}"

LV_NAME="lv"
LV_DEV="/dev/${VG_NAME}/${LV_NAME}"

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

    # Create and open dm-integrity (no journal).
    sudo integritysetup format --integrity-no-journal -q "${DISK1_CRYPT_DEV}"
    sudo integritysetup format --integrity-no-journal -q "${DISK2_CRYPT_DEV}"
    sudo integritysetup open --integrity-no-journal -q "${DISK1_CRYPT_DEV}" "${DISK1_INTEGRITY_NAME}"
    sudo integritysetup open --integrity-no-journal -q "${DISK2_CRYPT_DEV}" "${DISK2_INTEGRITY_NAME}"
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
    sudo mdadm --zero-superblock "${DISK1_INTEGRITY_DEV}" || true
    sudo mdadm --zero-superblock "${DISK2_INTEGRITY_DEV}" || true

    # Close dm-integrity.
    ! [ -e "${DISK1_INTEGRITY_DEV}" ] || sudo integritysetup close "${DISK1_INTEGRITY_NAME}"
    ! [ -e "${DISK2_INTEGRITY_DEV}" ] || sudo integritysetup close "${DISK2_INTEGRITY_NAME}"

    # Close dm-crypt.
    ! [ -e "${DISK1_CRYPT_DEV}" ] || sudo cryptsetup close "${DISK1_CRYPT_NAME}"
    ! [ -e "${DISK2_CRYPT_DEV}" ] || sudo cryptsetup close "${DISK2_CRYPT_NAME}"
}

"cmd_${1}" "${@:2}"
