---
title: "树莓派搭建 K8s 集群 - Part 2 K8s 安装"
date: 2023-09-03T20:11:10+08:00
draft: false
---

这篇文章主要介绍如何将 K8s 部署到三台树莓派上，实现一主两从的架构模式。

## 更改主机名

由于 K8s 使用主机名来区分集群里的节点，所以每个节点的 hostname 必须不能重名。你需要修改 `/etc/hostname` 这个文件，把它改成容易辨识的名字，比如我的三台树莓派名称分别为 rpi1 rpi2 rpi3。

```bash
sudo vi /etc/hostname
```

同样更改下 `/etc/hosts` 文件：

将文件中的

```bash
127.0.0.1   raspberry
```

更改为

```bash
127.0.0.1   rpi1
```

## 修改 Docker 配置

```shell
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

sudo systemctl enable docker
sudo systemctl daemon-reload
sudo systemctl restart docker
```

## 设置流量转发

修改 iptables 的配置，启用 `br_netfilter` 模块，让 K8s 可以检查和转发网络流量。

```shell
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward=1 # better than modify /etc/sysctl.conf
EOF

sudo sysctl --system
```

## 关闭 Linux Swap 分区

> 基于安全性（如在官方文档中承诺的 Secret 只会在内存中读写，不会落盘）、利于保证节点同步一致性等原因，从 1.8 版开始，Kubernetes 就在它的文档中明确声明了它默认不支持 Swap 分区，在未关闭 Swap 分区的机器中，集群将直接无法启动。

<font color="red">注意：下面这个方法在树莓派上不起作用！！：</font>

```bash
sudo swapoff -a
sudo sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab
```

正确的方法是修改 `/etc/dphys-swapfile` 文件，将 `CONF_SWAPSIZE` 修改为 0：

```bash
# set size to absolute value, leaving empty (default) then uses computed value
#   you most likely don't want this, unless you have an special disk situation
CONF_SWAPSIZE=0
```

完成以上操作后，最好重启下系统。

## 安装 Kubeadm

> master 节点和 woker 节点都需要安装

kubeadm 可以直接从 Google 自己的软件仓库下载安装，但国内的网络不稳定，很难下载成功，需要改用其他的软件源：

```bash
sudo apt install -y apt-transport-https ca-certificates curl

curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | sudo apt-key add -

cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF

sudo apt update
```

使用 apt 安装 kubeadm、kubelet 和 kubectl 这三个安装必备工具。apt 默认会下载最新版本，在这里我们选择的版本是 1.23.3：

```bash
sudo apt install -y kubeadm=1.23.3-00 kubelet=1.23.3-00 kubectl=1.23.3-00
```

注意：安装 Kubernetes 版本 >= 1.24 时，需要单独安装容器运行时 containerd，安装步骤参考：[容器运行时：containerd | DemonLee's Time](https://demonlee.tech/archives/2212001)。

以下内容来自 Kubernetes [官方文档](https://kubernetes.io/zh-cn/docs/setup/production-environment/container-runtimes/)：

> 自 1.24 版起，Dockershim 已从 Kubernetes 项目中移除。阅读 [Dockershim 移除的常见问题](https://kubernetes.io/zh-cn/dockershim)了解更多详情。
>
> v1.24 之前的 Kubernetes 版本直接集成了 Docker Engine 的一个组件，名为 **dockershim**。 这种特殊的直接整合不再是 Kubernetes 的一部分 （这次删除被作为 v1.20 发行版本的一部分[宣布](https://kubernetes.io/zh-cn/blog/2020/12/08/kubernetes-1-20-release-announcement/#dockershim-deprecation)）。
>
> 你可以阅读[检查 Dockershim 移除是否会影响你](https://kubernetes.io/zh-cn/docs/tasks/administer-cluster/migrating-from-dockershim/check-if-dockershim-removal-affects-you/)以了解此删除可能会如何影响你。 要了解如何使用 dockershim 进行迁移， 请参阅[从 dockershim 迁移](https://kubernetes.io/zh-cn/docs/tasks/administer-cluster/migrating-from-dockershim/)。

安装完成之后，你可以用 kubeadm version、kubectl version 来验证版本是否正确

```bash
kubeadm version
kubectl version --client
```

> 按照 Kubernetes 官网的要求，我们最好再使用命令 apt-mark hold ，锁定这三个软件的版本，避免意外升级导致版本错误：
>
> ```bash
> sudo apt-mark hold kubeadm kubelet kubectl
> ```

## 安装 Master 节点

```bash
sudo kubeadm init \
  --image-repository registry.aliyuncs.com/google_containers \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=192.168.1.10 \
  --kubernetes-version=v1.23.3 \
  --v=5
```

解释下这里的几个参数：

- `–-image-repository`：从阿里云服务器上拉取上面需要的基础镜像，如果不设置，就得去 Google 服务器拉取像
- `-–pod-network-cidr`：指定 Pod 网络的范围。Flannel 网络插件需要使用
- `--apiserver-advertise-address`：指定 api-server 的 IP 地址，如果有多张网卡，请明确选择哪张网卡。由于 apiserver 在 Kubernetes 集群中有很重要的地位，很多配置（如 ConfigMap 资源等）都直接存储了该地址，后续更改起来十分麻烦，所以要慎重
- `-–kubernetes-version`：指定 Kubernetes 版本
- `--v=5`：显示详细的跟踪日志，可以参考[这里](https://kubernetes.io/zh-cn/docs/reference/kubectl/cheatsheet/#kubectl-output-verbosity-and-debugging)

安装过程会持续一会儿，显示以下内容时，安装成功：

```bash
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.1.10:6443 --token gse06a.mlxg2efk9ite96an \
	--discovery-token-ca-cert-hash sha256:d41a56ec057ab750b54e1edbbf5d11097ba5364d9015ade6259f2632856b7cd9
```

### 安装 Flannel 网络插件

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

## 安装 Worker 节点

Master 节点安装成功后，会显示以下命令，在 Worker 节点执行即可加入 K8s 集群：

```bash
kubeadm join 192.168.1.10:6443 --token gse06a.mlxg2efk9ite96an \
	--discovery-token-ca-cert-hash sha256:d41a56ec057ab750b54e1edbbf5d11097ba5364d9015ade6259f2632856b7cd9
```

默认 token 的有效期为24小时，当 token 过期之后，需要重新生成 token：`kubeadm token create --print-join-command`

## 常见错误

- 执行 `kubeadm init` 时报错：`[ERROR SystemVerification]: missing required cgroups: memory`

  > 参考：[raspberrypi - Raspberry Pi 4 Ubuntu 19.10 cannot enable cgroup memory at boostrap - Ask Ubuntu](https://askubuntu.com/questions/1189480/raspberry-pi-4-ubuntu-19-10-cannot-enable-cgroup-memory-at-boostrap)

  将以下内容添加到 `/boot/cmdline.txt`  末尾，并重启系统：

  ```bash
  cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory
  ```

## 参考文章

- [17｜更真实的云原生：实际搭建多节点的Kubernetes集群](https://time.geekbang.org/column/article/534762)
- [Kubernetes 集群安装（Debian 版） | DemonLee's Time](https://demonlee.tech/archives/2212002#step1%3A-%E5%AE%89%E8%A3%85-containerd)
- [手把手教大家使用树莓派4B搭建K8s集群 - 知乎](https://zhuanlan.zhihu.com/p/390805379)
- [raspberrypi系统在加入k8s作为node节点时遇到的问题 - 潇湘神剑 - 博客园](https://www.cnblogs.com/zhangzhide/p/16414728.html)

