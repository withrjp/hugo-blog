---
title: "树莓派搭建 K8s 集群 - Part 1 环境准备"
date: 2023-09-03T20:11:10+08:00
draft: false
---

## 前言

欢迎来到「树莓派搭建 K8s 集群」系列的第一篇文章！在这篇文章中，我将分享如何使用树莓派搭建 Kubernetes（K8s）集群。这个项目是我个人的探索，旨在深入了解 K8s 集群的搭建和管理，同时熟悉树莓派的使用和配置。

这篇文章的第一部分，我们将着重于环境的准备，包括硬件的准备，操作系统的安装，网络配置，以及静态 IP 的设置。请注意，这是基于个人实践的记录，并不一定适用于所有环境和场景。如果你在实践过程中遇到问题，欢迎在评论区提问。

现在，让我们开始吧！

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

     首次访问树莓派时，需要将树莓派连接到路由器上以获取访问地址。我们建议在镜像中提前配置好 WiFi，这样会更加便捷。

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

## 树莓派配置

### 设置静态IP

> 参考文章：[如何正确设置树莓派静态IP？](https://www.zhihu.com/question/372327727)

根据实际情况，选择合适的方式：

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

## 参考文章

- [2023年最新烧录和远程启动树莓派方法 - 知乎](https://zhuanlan.zhihu.com/p/615185775)
- [手把手教大家使用树莓派4B搭建K8s集群 - 知乎](https://zhuanlan.zhihu.com/p/390805379)
- [k8s折腾笔记——树莓派集群安装k3s - 咸鱼的小站](https://blog.xianyu.one/2021/11/16/Linux/tutorial/k8s-install/)
