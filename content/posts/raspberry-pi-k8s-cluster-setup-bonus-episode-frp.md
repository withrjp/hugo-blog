---
title: "树莓派搭建 K8s 集群 - 番外篇 - 内网穿透"
date: 2023-09-11T00:34:50+08:00
draft: false
---

众所周知，现如今家庭宽带几乎无法申请到 IPv4 地址，而公司网络又不支持 IPv6。在这种情况下，内网穿透应运而生，为我们提供了远程访问局域网应用的方法。

在众多内网穿透方案中，我选择了 frp，frp 是一个专注于内网穿透的高性能的反向代理应用，支持 TCP、UDP、HTTP、HTTPS 等多种协议，且支持 P2P 通信。可以将内网服务以安全、便捷的方式通过具有公网 IP 节点的中转暴露到公网。

接下来就简单说明下使用 frp 通过 SSH 访问内网机器的操作步骤。

> 注意：搭建 frp 的前提是你要有一个公网 IP 地址，比如各大云服务商的轻量服务器。

## 服务端安装 frps

在具有公网 IP 的机器上部署 frps。

1. 访问 frp 的 Github 的 [Release](https://github.com/fatedier/frp/releases) 页面，下载对应版本的客户端和服务端二进制文件，所有文件被打包在一个压缩包中。以 v0.51.3 版本为例，下载命令：

   ```bash
   wget https://github.com/fatedier/frp/releases/download/v0.51.3/frp_0.51.3_linux_arm64.tar.gz
   ```

   - 客户端：frpc

   - 服务端：frps

2. 解压压缩包：`tar xvf frp_0.51.3_linux_arm64.tar.gz`。

3. 修改 frps.ini 文件：

   ```bash
   [common]
   bind_port = 7000 # 公网服务器要暴露的端口，记得打开防火墙
   ```

4. 部署 frps：`./frps -c ./frps.ini`。

## 客户端安装 frpc

在需要被访问的内网机器上部署 frpc。

1. 与「服务端安装 frps」的1，2步相同，下载并解压压缩包。

2. 修改 frpc.ini 文件：

   ```bash
   [common]
   server_addr = x.x.x.x #  frps 所在服务器的公网 IP 地址
   server_port = 7000 # 对应 frps.ini 的 bind_port
   
   [ssh] # 多台机器不要重复
   type = tcp
   local_ip = 127.0.0.1 # 本地需要暴露到公网的服务地址
   local_port = 22 # 本地需要暴露到公网的端口
   remote_port = 6000 # frps 监听的端口，访问此端口的流量将会被转发到本地服务对应的端口
   ```

3. 部署 frpc：`./frpc -c ./frpc.ini`。

## SSH 访问内网机器

假设用户名为 test：

`ssh -oPort=6000 test@x.x.x.x`

frp 会将请求 `x.x.x.x:6000` 的流量转发到内网机器的 22 端口。

## 设置开机自启

建议客户端和服务端都配置下，避免因为 frp 没开启导致服务无法访问。配置方式参考官方文档：[使用 systemd | frp](https://gofrp.org/docs/setup/systemd/)

## 参考文章

- [frp](https://gofrp.org/)
