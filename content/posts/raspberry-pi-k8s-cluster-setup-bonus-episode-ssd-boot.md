---
title: "树莓派搭建 K8s 集群 - 番外篇 - 使用 SSD 启动树莓派"
date: 2023-09-08T23:08:19+08:00
draft: false
---

在这篇文章中，我将使用 Argon ONE NVMe 扩展板，将 M.2 接口转换成 USB 3.0 接口，实现树莓派 SSD 启动。

![argon-one-nvme](https://gd2.alicdn.com/imgextra/i3/63628442/O1CN01tRaMdQ2CEUPXoxF1T_!!63628442.jpg_400x400.jpg)

## 硬件介绍

- SAMSUNG SSD 980 500G
- Argon ONE Pi 4 V2
- Argon ONE NVMe

> 注意：**Argon ONE NVMe 板（可能）比 SATA 慢**，请参考这篇文章检查你的 Argon ONE NVMe Board：https://www.martinrowan.co.uk/2023/01/argon-one-nvme-board-slower-than-sata。

## SSD - 操作系统烧录

<font color="red">网上很多文章都是错的，不需要先将系统烧录到 TF 卡上，使用 Raspberry Pi Imager 将系统烧录到 SSD 上即可。</font>

1. 先将 USB Boot 烧录到 SSD 上：

![image-20230909235950701](https://s2.loli.net/2023/09/09/E26AChKV7GFfyjW.png)

![image-20230910000013131](https://s2.loli.net/2023/09/10/RlepALkI6JGHKdO.png)

![image-20230910002253718](https://s2.loli.net/2023/09/10/bPMGWNYluQa3sCD.png)

2. 再将操作系统烧录到 SSD 上（参考[镜像烧录](/posts/raspberry-pi-k8s-cluster-setup-part-1-environment-preparation/#镜像烧录)）。

3. 启动树莓派。

## Benchmark

简单测试下 SSD 和 TF 卡的读写性能。

### SSD

写入：

```bash
$ time dd if=/dev/zero of=test bs=8k count=10000 oflag=direct
10000+0 records in
10000+0 records out
81920000 bytes (82 MB, 78 MiB) copied, 1.73789 s, 47.1 MB/s

real	0m1.744s
user	0m0.019s
sys	0m0.648s
```

读取：

```bash
$ time dd if=test of=/dev/null bs=8k count=10000 iflag=direct && rm ./test
10000+0 records in
10000+0 records out
81920000 bytes (82 MB, 78 MiB) copied, 1.18337 s, 69.2 MB/s

real	0m1.189s
user	0m0.022s
sys	0m0.377s
```

### TF

写入

```bash
$ time dd if=/dev/zero of=test bs=8k count=10000 oflag=direct && rm ./test
10000+0 records in
10000+0 records out
81920000 bytes (82 MB, 78 MiB) copied, 12.8542 s, 6.4 MB/s

real	0m12.859s
user	0m0.034s
sys	0m0.836s
```

读取

```bash
$ time dd if=test of=/dev/null bs=8k count=10000 iflag=direct && rm ./test
10000+0 records in
10000+0 records out
81920000 bytes (82 MB, 78 MiB) copied, 4.78741 s, 17.1 MB/s

real	0m4.791s
user	0m0.013s
sys	0m0.311s
```

显而易见，SSD 读写速度明显高于 TF 卡。

> 受限于 USB 3.0 接口，SSD 无法发挥出完整的性能。The Raspberry Pi 4’s USB 3.0 ports support data rates of [5 Gbit/s (500 MB/s after encoding overhead)](https://en.wikipedia.org/wiki/USB_3.0) 

## Trim Support

> SSD TRIM 是一种用于固态硬盘（SSD）的特殊命令，用于优化和维护 SSD 的性能和寿命。当文件被删除或移动时，操作系统通常会将相应的存储空间标记为可重新使用。然而，对于固态硬盘而言，这种标记并不意味着存储空间实际上已经被清空，而是只是逻辑上的标记。
>
> SSD TRIM 命令的作用是通知固态硬盘哪些存储空间已经不再使用，可以被擦除和重写。这样，固态硬盘就可以在写入新数据之前，提前准备好可用的存储空间，从而提高写入性能。TRIM 命令还有助于减少固态硬盘的写入放大效应，延长固态硬盘的使用寿命。
>
> 总之，SSD TRIM 命令可以提高固态硬盘的性能和寿命，确保其持续高效地工作。大多数现代操作系统和固态硬盘都支持 TRIM 命令，因此在使用 SSD 时，建议启用 TRIM 功能以获得最佳性能和寿命。

Argon ONE 扩展板需要进行一些修改，才能支持 Trim。**其他扩展板可以忽略前两步**：

1. 修改 `/etc/udev/rules.d/10-trim.rules`，添加如下内容：

   ```bash
   ACTION=="add|change", ATTRS{idVendor}=="174c", ATTRS{idProduct}=="2362", SUBSYSTEM=="scsi_disk", ATTR{provisioning_mode}="unmap"
   ```

2. 重启系统。

3. 查看 fstrim 命令是否正常：`sudo fstrim -v /`。

4. 开启每周自动 Trim：`sudo systemctl enable fstrim.timer`。

## 参考文章

- [Argon ONE NVMe Board (maybe) Slower than SATA - Martin Rowan](https://www.martinrowan.co.uk/2023/01/argon-one-nvme-board-slower-than-sata/)
- [Argon ONE NVMe Board - Fixed! - Martin Rowan](https://www.martinrowan.co.uk/2023/02/argon-one-nvme-board-fixed/)
- [【树莓派学习笔记】从固态硬盘启动树莓派 - Dennis的主页](https://www.dennisyu.top/article/ssd-on-pi.html)
