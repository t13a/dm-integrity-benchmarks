# `dm-integrity` Benchmarks

## Summary

(TODO)

## Motivation

(TODO)

## Test Cases

| #   | Description                                                                      | Detect corruption | Repair corruption |
| --- | -------------------------------------------------------------------------------- | ----------------- | ----------------- |
| 1   | `ext4`                                                                           | ❌                | ❌                |
| 2   | `ext4` on `dm-integrity`                                                         | ✅                | ❌                |
| 3   | `ext4` on `dm-integrity` (no journal)                                            | ✅                | ❌                |
| 4   | `ext4` on `dm-integrity` (bitmap mode)                                           | ✅                | ❌                |
| 5   | `ext4` on `dm-crypt`                                                             | ❌                | ❌                |
| 6   | `ext4` on `dm-crypt` (with `--integrity` option)                                 | ✅                | ❌                |
| 7   | `ext4` on `dm-crypt` (plain mode)                                                | ❌                | ❌                |
| 8   | `ext4` on `dm-crypt` (plain mode) on `dm-integrity`                              | ✅                | ❌                |
| 9   | `ext4` on `dm-raid` (RAID 1)                                                     | ❌                | ❌                |
| 10  | `ext4` on `dm-raid` (RAID 1) on `dm-integrity` (no-journal)                      | ✅                | ✅                |
| 11  | `ext4` on LVM                                                                    | ❌                | ❌                |
| 12  | `ext4` on LVM on `dm-raid` (RAID 1)                                              | ❌                | ❌                |
| 13  | `ext4` on LVM on `dm-raid` (RAID 1) on `dm-integrity` (no-journal)               | ✅                | ✅                |
| 14  | `ext4` on LVM on `dm-raid` (RAID 1) on `dm-integrity` (no-journal) on `dm-crypt` | ✅                | ✅                |
| 15  | `btrfs`                                                                          | ✅                | ✅                |
| 16  | `btrfs` (RAID 1)                                                                 | ✅                | ✅                |
| 17  | `btrfs` (RAID 1) on `dm-crypt`                                                   | ✅                | ✅                |

## Testing

### Prepare

In this study, I will use Lenovo ThinkStation P500 workstation. It is a bit old, but it was a great bargain that sold for ¥30,000 in 2020.

- CPU: Intel Xeon E5-1620 v3
- Memory: 48 GiB
- Storage:
  - 500 GB SATA SSD
  - 12 TB SATA HDD (**Target Disk #1**)
  - 12 TB SATA HDD (**Target Disk #2**)
- OS: Debian 12.1 Bookworm

Install additional packages.

```
$ sudo apt install fio jq make
```

Disable write cache on target disks (`/dev/sdb` and `/dev/sdc`).

```
$ sudo hdparm -W0 /dev/{sdb,sdc}

/dev/sdb:
 setting drive write-caching to 0 (off)
 write-caching =  0 (off)

/dev/sdc:
 setting drive write-caching to 0 (off)
 write-caching =  0 (off)
```

To save time, create small 1 GiB partitions (`/dev/sdb1` and `/dev/sdc1`) on target disks.

```
$ sudo fdisk /dev/sdb
...
$ sudo fdisk /dev/sdc
...
$ lsblk /dev/{sdb,sdc}
NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
sdb      8:16   0  10.9T  0 disk
└─sdb1   8:17   0  1023M  0 part
sdc      8:32   0  10.9T  0 disk
└─sdc1   8:33   0  1023M  0 part
```

### IO Performance

Remove old result.

```
$ make clean
```

Test all cases.

```
$ export DISK1_DEV=/dev/sdb1 # WARNING: Change to your environment.
$ export DISK2_DEV=/dev/sdc1 # WARNING: Change to your environment.
$ make test
...
```

Generate the result.

```
$ make report
...
```

For details, see `gen/` directory.
