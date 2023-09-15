---
title: "树莓派搭建 K8s 集群 - Part 1 环境准备"
date: 2023-09-02T20:11:10+08:00
draft: false
#cover:
    #image: "https://s2.loli.net/2023/09/10/3vAdgbCYulZqneK.png"
    # can also paste direct link from external site
    # ex. https://i.ibb.co/K0HVPBd/paper-mod-profilemode.png
    #alt: "树莓派 x 3"
    #caption: "树莓派 x 3"
    #relative: false # To use relative path for cover image, used in hugo Page-bundles
---

本文将介绍使用树莓派搭建 Kubernetes（K8s）集群的环境准备工作，包括操作系统安装、网络配置，以及 Docker 的安装。

请注意，这是基于个人实践的记录，并不一定适用于所有环境和场景。如果你在实践过程中遇到问题，欢迎在评论区留言。

![image-20230910121512995](https://s2.loli.net/2023/09/10/3vAdgbCYulZqneK.png)

## 硬件介绍

- Raspberry Pi 4B 8G x 3
- 电源 5V 3A x 3
- SanDisk TF 64G x 2
- SAMSUNG SSD 980 500G x 1

> 我们选择在其中一台服务器上使用 SSD 作为存储设备，主要原因如下：
>
> 1. 与 TF 卡相比，SSD 的耐用性更高，并且价格也相对亲民。
> 2. 我们计划在后续配置中引入 NFS 作为 K8s 存储，因此需要更大容量、更高性能的硬盘。
>
> 当然，选择使用三张 TF 卡也没有问题。因为我们的主要目的是学习 K8s 集群的构建。

## 操作系统安装

### 格式化 TF 卡

> 如果是新的 TF 卡，可以跳过此步骤

1. 下载并安装 [SD Card Formatter](https://www.sdcard.org/downloads/formatter/)。

2. 选择对应的 TF 卡，点击 **Format**，完成格式化。
   ![image-20230903143237843](https://s2.loli.net/2023/09/03/46zi7Hw9fblA5Bc.png)

### 镜像烧录

1. 下载并安装[官方镜像烧录器](https://www.raspberrypi.com/software/)。

2. 选择合适的操作系统：

   根据你购买的树莓派型号和个人喜好，选择合适的操作系统。

   > 注意：树莓派 4B 系列需要使用 64 位操作系统。

   ![image-20230903151259831](https://s2.loli.net/2023/09/03/QTnmYf1xa5oSj7A.png)

   ![image-20230903151216216](https://s2.loli.net/2023/09/03/2Y1HBrqFIEojzdD.png)

3. 选择存储卡。

4. 镜像设置（**重要**）：

   ![image-20230903151006683](https://s2.loli.net/2023/09/03/2GuDZ1mqV7Hi4vQ.png)

   - 配置 WiFi

     首次访问树莓派时，需要将树莓派连接到路由器上以获取访问地址。建议在镜像中提前配置好 WiFi，这样会更加便捷。

   - 开启 SSH 服务

     远程登录需要。

   - 镜像自定义选项，选择【永久保存】

     如果你计划配置多台树莓派，建议选择【永久保存】，这将避免每次重新配置。

   完整配置如下：

   ![image-20230903160903980](https://s2.loli.net/2023/09/03/4Ya92RUS6KETwrc.png)

5. 开始烧录。

6. 烧录完成：

   ![image-20230903161545740](https://s2.loli.net/2023/09/03/DIwE9a4VCyJSN17.png)

## 远程访问树莓派

树莓派启动后，可以登录路由器查看树莓派的 IP 地址：

![image-20230903181237147](https://s2.loli.net/2023/09/03/fiGamdCKyT7PzFq.png)

接下来，你就可以通过 SSH 实现远程访问树莓派啦~

## 设置静态IP

根据实际情况，选择合适的配置方式（参考[如何正确设置树莓派静态IP？](https://www.zhihu.com/question/372327727)）：

- 通过路由器为树莓派分配静态 IP （**推荐**）

  路由器型号不同，设置方法也不同，请自行查找相关文档。

- 修改树莓派的 `/etc/dhcpcd.conf` 文件

  ```shell
  interface wlan0
  static ip_address=192.168.0.10/24 # 自定义静态 IP 地址
  static routers=192.168.0.1 # 默认网关（路由器）的 IP 地址
  static domain_name_servers=114.114.114.114 # DNS（域名服务器）的 IP 地址
  ```

  保存后，重启 dhcpcd 服务：`sudo systemctl restart dhcpcd`

## apt 换源

> apt 自带的源在海外，访问速度比较慢，更换成清华源后访问速度会快很多。

修改 `/etc/apt/sources.list` 文件，使用以下内容替换：

```bash
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware

deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware

deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware

# deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware
# # deb-src https://mirrors.tuna.tsinghua.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware

deb https://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
# deb-src https://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
```

如果遇到无法拉取 HTTPS 源的情况，请先使用 HTTP 源并安装：

```bash
sudo apt install apt-transport-https ca-certificates
```

详细步骤参考：[debian | 镜像站使用帮助 | 清华大学开源软件镜像站 | Tsinghua Open Source Mirror](https://mirror.tuna.tsinghua.edu.cn/help/debian/)。

> 注意：
>
> - 请根据树莓派的操作系统架构，选择合适的版本。比如 `Raspbian armv7l` 请参考：[raspbian | 镜像站使用帮助 | 清华大学开源软件镜像站 | Tsinghua Open Source Mirror](https://mirror.tuna.tsinghua.edu.cn/help/raspbian/)
> - 更换前请备份 `/etc/apt/sources.list` 文件，方便异常时回滚

## 安装 Docker

如果安装过 docker，先删掉：

```bash
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done
```

首先安装依赖：

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
```

信任 Docker 的 GPG 公钥并添加仓库：

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

最后安装：

```bash
sudo apt-get update

# 二选一
# 不指定版本
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
# 指定版本
VERSION_STRING=5:20.10.24~3-0~debian-bullseye
sudo apt-get install docker-ce=$VERSION_STRING docker-ce-cli=$VERSION_STRING containerd.io docker-buildx-plugin docker-compose-plugin
```

建立 docker 用户组：

默认情况下，`docker` 命令会使用 [Unix socket](https://en.wikipedia.org/wiki/Unix_domain_socket) 与 Docker 引擎通讯。而只有 `root` 用户和 `docker` 组的用户才可以访问 Docker 引擎的 Unix socket。出于安全考虑，一般 Linux 系统上不会直接使用 `root` 用户。因此，更好地做法是将需要使用 `docker` 的用户加入 `docker` 用户组。

建立 docker 组：`$ sudo groupadd docker`

将当前用户加入 docker 组：`$ sudo usermod -aG docker $USER`

测试 Docker 是否安装正确：

```shell
$ docker run --rm hello-world
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
c4018b8bf438: Pull complete
Digest: sha256:dcba6daec718f547568c562956fa47e1b03673dd010fe6ee58ca806767031d1c
Status: Downloaded newer image for hello-world:latest

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (arm32v7)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started/
```

详细步骤参考：[docker-ce | 镜像站使用帮助 | 清华大学开源软件镜像站 | Tsinghua Open Source Mirror](https://mirror.tuna.tsinghua.edu.cn/help/docker-ce/)

> 注意：在下一章中，我们要安装的 K8s 版本为 v1.23.3 ，**建议 Docker 版本不要超过 20.10，否则安装 K8s 时会出错**。

## 参考文章

- [2023年最新烧录和远程启动树莓派方法 - 知乎](https://zhuanlan.zhihu.com/p/615185775)
- [手把手教大家使用树莓派4B搭建K8s集群 - 知乎](https://zhuanlan.zhihu.com/p/390805379)
- [k8s折腾笔记——树莓派集群安装k3s - 咸鱼的小站](https://blog.xianyu.one/2021/11/16/Linux/tutorial/k8s-install/)
- [AOSP | 镜像站使用帮助 | 清华大学开源软件镜像站 | Tsinghua Open Source Mirror](https://mirror.tuna.tsinghua.edu.cn/help/AOSP/)
