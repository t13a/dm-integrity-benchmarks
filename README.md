# dm-integrity Benchmarks

Measure dm-integrity IO performance using Fio.

This research is a personal project for summer vacation 2023. 🌞

## Introduction

No one wants to lose their data. However, gigantic cloud providers ruthlessly close your account one day and do not respond to your complaint. Or, like many cloud storage services that were popular for a while, the next thing you know, that service has already shut down and is gone with the data. Everyone should have their own storage, to prepare for the coming days. Linux offers a variety of options to meet your needs.

### Silent data corruption

Build a RAID for redundancy and make consistent backups from snapshots. My and my family's data are safe. Is it true? dm-raid, the software RAID implemented in Linux kernel, can detect bad sectors and repair them, but cannot correct bad data in good sectors occured by some reason. If left as is, the correct backup could be overwritten with bad data. Just thinking of it is scary.

This phenomenon is called [silent data corruption](https://en.wikipedia.org/wiki/Data_corruption#Silent) (as known as **bit rot**). It is caused by incomplete insulation, high temperature environment, cosmic radiation impact, etc. Although the probability is low, it is a non-negligible cause of failure for me who wants to maintain data reliably over the long term.

[dm-integrity](https://docs.kernel.org/admin-guide/device-mapper/dm-integrity.html) is (TODO).

### Finding the best configuration for long term storage

(TODO)

## Methodology

### Test drives

In this study, I use Lenovo ThinkStation P500 workstation. It was a bit old, but a great bargain that sold for ¥30,000 in 2020.

| Component       | Description                                     | Test drive          |
| --------------- | ----------------------------------------------- | ------------------- |
| CPU             | 4 Core 8 Threads (Intel Xeon E5-1620 v3)        | -                   |
| **RAM**         | **48 GB DDR4 ECC RDIMM**                        | ✅ (`/dev/ram0`)    |
| SATA SSD #1     | 500 GB SATA SSD (Trancend SSD370 TS512GSSD370S) | ❌                  |
| **SATA HDD #1** | **12 TB SATA HDD (WD Red Plus WD120EFBX)**      | ✅ (`/dev/sdb`)     |
| **SATA HDD #2** | **12 TB SATA HDD (WD Red Plus WD120EFBX)**      | ✅ (`/dev/sdc`)     |
| SATA HDD #3     | 12 TB SATA HDD (WD Red Plus WD120EFBX)          | ❌                  |
| SATA HDD #4     | 12 TB SATA HDD (WD Red Plus WD120EFBX)          | ❌                  |
| **NVMe SSD #1** | **1 TB NVMe SSD (WD Red SN700)**                | ✅ (`/dev/nvme0n1`) |
| OS              | Linux 6.1.0 (Debian 12.1 Bookworm)              | -                   |

Install additional packages.

```sh
$ sudo apt install zfs-dkms zfsutils-linux
...
```

The versions of the package are as follows.

```sh
$ apt list --installed 2>/dev/null | grep -E '^(btrfs-progs|cryptsetup-bin|lvm2|mdadm|zfs*)/'
btrfs-progs/stable,now 6.2-1 amd64 [installed,automatic]
cryptsetup-bin/stable,now 2:2.6.1-4~deb12u1 amd64 [installed,automatic]
lvm2/stable,now 2.03.16-2 amd64 [installed,automatic]
mdadm/stable,now 4.2-5 amd64 [installed,automatic]
zfs-dkms/stable,now 2.1.11-1 all [installed]
zfs-zed/stable,now 2.1.11-1 amd64 [installed,automatic]
zfsutils-linux/stable,now 2.1.11-1 amd64 [installed]
```

Disable write cache for SATA HDD \#1~2.

```sh
$ sudo hdparm -W0 /dev/{sdb,sdc}

/dev/sdb:
 setting drive write-caching to 0 (off)
 write-caching =  0 (off)

/dev/sdc:
 setting drive write-caching to 0 (off)
 write-caching =  0 (off)
```

Set IO scheduler to `none` for SATA HDD \#1~2.

```sh
$ echo none | sudo tee /sys/block/{sdb,sdc}/queue/scheduler
none
$ cat /sys/block/{sdb,sdc,nvme0n1,ram0}/queue/scheduler
[none] mq-deadline
[none] mq-deadline
[none] mq-deadline
none
```

For saving time, create small partitions on SATA HDD \#1~2 and NVMe SSD \#1.

```sh
$ sudo fdisk /dev/sdb
...
$ sudo fdisk /dev/sdc
...
$ sudo fdisk /dev/nvme0n1
...
$ lsblk /dev/{sdb,sdc,nvme0n1}
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
sdb           8:16   0  10.9T  0 disk
└─sdb1        8:17   0     1G  0 part
sdc           8:32   0  10.9T  0 disk
└─sdc1        8:33   0     1G  0 part
nvme0n1     259:0    0 931.5G  0 disk
└─nvme0n1p1 259:2    0     1G  0 part
```

Create RAM drive with a larger capacity. Since btrfs has a problem of running out of free space during random writes when running on a RAM drive.

```
$ sudo modprobe brd rd_nr=1 rd_size=8388608
$ $ lsblk /dev/ram0
NAME MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
ram0   1:0    0   8G  0 disk
```

### Test configurations

The following are candidate configurations suitable for long-term storage ~~based on the features merged into the Linux kernel~~ combined filesystems widely used in Linux.

| #   | Configuration                                               | Encryption | Redundancy | Scrubbing | Snapshot |
| --- | ----------------------------------------------------------- | ---------- | ---------- | --------- | -------- |
| 1   | ext4                                                        | ❌         | ❌         | ❌        | ❌       |
| 2   | ext4 on dm-integrity                                        | ❌         | ❌         | ❌        | ❌       |
| 3   | ext4 on dm-integrity (no journal)                           | ❌         | ❌         | ❌        | ❌       |
| 4   | ext4 on dm-integrity (bitmap mode)                          | ❌         | ❌         | ❌        | ❌       |
| 5   | ext4 on dm-crypt                                            | ✅         | ❌         | ❌        | ❌       |
| 6   | ext4 on dm-crypt (with `--integrity=hmac-sha256`)           | ✅         | ❌         | ❌        | ❌       |
| 7   | ext4 on dm-crypt on dm-integrity                            | ✅         | ❌         | ❌        | ❌       |
| 8   | ext4 on dm-raid (RAID 1)                                    | ❌         | ✅         | ⚠️        | ❌       |
| 9   | ext4 on dm-raid (RAID 1) on dm-integrity                    | ❌         | ✅         | ✅        | ❌       |
| 10  | ext4 on LVM                                                 | ❌         | ❌         | ❌        | ✅       |
| 11  | ext4 on LVM on dm-raid (RAID 1)                             | ❌         | ✅         | ⚠️        | ✅       |
| 12  | ext4 on LVM on dm-raid (RAID 1) on dm-integrity             | ❌         | ✅         | ✅        | ✅       |
| 13  | ext4 on LVM on dm-raid (RAID 1) on dm-integrity on dm-crypt | ✅         | ✅         | ✅        | ✅       |
| 14  | btrfs                                                       | ❌         | ❌         | ✅        | ✅       |
| 15  | btrfs (RAID 1)                                              | ❌         | ✅         | ✅        | ✅       |
| 16  | btrfs (RAID 1) on dm-crypt                                  | ✅         | ✅         | ✅        | ✅       |
| 17  | ZFS                                                         | ❌         | ❌         | ✅        | ✅       |
| 18  | ZFS (RAID 1)                                                | ❌         | ✅         | ✅        | ✅       |
| 19  | ZFS (RAID 1) on dm-crypt                                    | ✅         | ✅         | ✅        | ✅       |

⚠️...dm-raid cannot correct bad data (can only bad sectors).

**ext4** (\#1) is the most common Linux filesystem as of 2023.

**ext4 on dm-integrity** (\#2~4) is (TODO).

**ext4 on dm-crypt** (\#5~7) is (TODO). Performance related parameters are tuned based on [the Cloudflare blog post](https://blog.cloudflare.com/speeding-up-linux-disk-encryption/).

**ext4 on dm-raid** (\#8~9) is (TODO). Data correction is possible by building dm-raid on top of dm-raid.

**ext4 on LVM** (\#10~13) is (TODO). There is also a command `lvmraid` to build RAID on LV, but it is out of the scope of this study.

**btrfs** (\#14~16) has all features except encryption. (TODO).

**ZFS** (\#17~19) is (TODO).

### Data collection

Measure the following throughput performance for each drive and configuration using [fio](https://github.com/axboe/fio). Parameters are based on [CrystalDiskMark](https://crystalmark.info/en/category/crystaldiskmark/)'s "[Peak Performance](https://crystalmark.info/en/software/crystaldiskmark/crystaldiskmark-main-menu/)" profile and [the Nutanix knowledge base](https://portal.nutanix.com/page/documents/kbs/details?targetId=kA07V000000LX7xSAG).

| Test                   | Read/Write       | Block Size | Queue Size | Threads | `fsync(2)`     |
| ---------------------- | ---------------- | ---------- | ---------- | ------- | -------------- |
| `seq-1m-q8-t1-read`    | Sequential Read  | 1 MiB      | 8          | 1       | on file close  |
| `seq-1m-q8-t1-write`   | Sequential Write | 1 MiB      | 8          | 1       | on file close  |
| `rnd-4k-q32-t16-read`  | Random Read      | 4 kiB      | 32         | 16      | on every write |
| `rnd-4k-q32-t16-write` | Random Write     | 4 kiB      | 32         | 16      | on every write |

Install additional packages.

```

$ sudo apt install fio make

```

Run all tests.

```sh
$ export HDD1_DEV=/dev/sdb1 # WARNING: Change to your environment.
$ export HDD2_DEV=/dev/sdc1 # WARNING: Change to your environment.
$ export SSD1_DEV=/dev/nvme0n1p1 # WARNING: Change to your environment.
$ export RAM1_DEV=/dev/ram0 # WARNING: Change to your environment.
$ make test
...
```

### Data analysis

Nothing special. All I do is plot the throughput per test result on a bar chart using [R](https://www.r-project.org/).

Install additional packages.

```sh
$ sudo apt install jq r-base r-cran-dplyr r-cran-ggplot2 r-cran-gridextra
```

Generate CSV and SVG from JSON of test results.

```sh
$ make report
...
```

For details, see `out.sample/` directory.

## Results & discussion

### SATA HDD #1~2

![FIO](out.sample/all.hdd.svg)

(TODO)

### NVMe SSD #1

![FIO](out.sample/all.ssd.svg)

(TODO)

### RAM

![FIO](out.sample/all.ram.svg)

(TODO)

### ext4 vs dm-integrity

![FIO](out.sample/ext4+integrity.svg)

(TODO)

### ext4 vs dm-crypt

![FIO](out.sample/ext4+crypt.svg)

(TODO)

### ext4 vs dm-raid

![FIO](out.sample/ext4+raid.hdd.svg)

(TODO)

### ext4 vs LVM

![FIO](out.sample/ext4+lvm.hdd.svg)

(TODO)

### ext4 vs btrfs

![FIO](out.sample/btrfs.hdd.svg)

(TODO)

### ext4 vs ZFS

![FIO](out.sample/zfs.hdd.svg)

(TODO)

### ext4 vs the full-featured configurations

![FIO](out.sample/full-featured.hdd.svg)

(TODO)

- dm-integrity の使用は書き込み性能を大きく悪化させる。特にシーケンシャルリードでは 75% も下がる。ランダムリードの方は 50% の低下。ただし、ジャーナルを不使用にするかビットマップモードを使用することで 10% 程度の低下に抑えることができる。
- dm-raid との併用はシーケンシャルライトは 40% も低下してしまう。
- dm-crypt や LVM の併用はほとんど性能に影響しない。
- btrfs は \#13 と同等以上の機能を持っていながら良好な性能を示している。ただし、 `17-btrfs-raid1-crypt` の `rand-write` は明らかに不正確。もしかすると btrfs が全般的に正しくないかも知れない。

## Conclusion

(TODO)

ベンチマークの結果、 dm-integrity の書き込み性能の悪さが浮き彫りとなった。

dm-integrity が適するのは下記の用途であろう。

- 書き込み頻度の少ない NAS
- バックアップ用ストレージ

btrfs を比較対象に測ってみたが、世間で言われているより良好なのは意外だった。

作図のために R 言語に初めて触った。言語仕様はほとんど理解していないが、 ggplot2 が偉大であるということだけはよく分かった。
