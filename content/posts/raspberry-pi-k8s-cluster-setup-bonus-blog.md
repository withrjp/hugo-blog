---
title: "树莓派搭建 K8s 集群 - 番外篇 - 通过 Github Action 与 K8s 持续部署 Hugo 博客"
date: 2023-10-16T16:49:56+08:00
draft: false
---

> 博客地址：[Ackerman](https://blog.rjp.pub/)
>
> 代码仓库地址：[withrjp/hugo-blog](https://github.com/withrjp/hugo-blog)

## 前置依赖

- K8s 集群（K3s 也可以）
- 公网 ip 地址，用于访问 K8s 集群
- 镜像仓库

## Dockerfile

在代码仓库中添加 Dockerfile 文件：

```dockerfile
FROM klakegg/hugo:ext-alpine AS builder

WORKDIR /src
COPY . .

RUN hugo --minify

FROM nginx:1.25.2-alpine

COPY --from=builder /src/public /usr/share/nginx/html

EXPOSE 80
```

## K8s Deployment

先建好博客对应的 K8s Deployemnt，让 Github Action 每次触发时，更新镜像版本就行了。

参考 K8s Deployment：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: blog
  namespace: blog
spec:
  replicas: 1
  selector:
    matchLabels:
      app: blog
  template:
    metadata:
      labels:
        app: blog
    spec:
      containers:
      - image: registry.rjp.pub/blog:1bc6a06ca27 # 使用 Dockerfile 手动打镜像并推送到镜像仓库
        imagePullPolicy: IfNotPresent
        name: blog
        ports:
        - containerPort: 80
          name: blog
          protocol: TCP
      imagePullSecrets:
      - name: registry # 镜像仓库 secret
```

> K8s Service 使用 NodePort 或者 Ingress 都可以，这里省略。

## Kubeconfig	

Github Action 支持通过 [kubectl](https://github.com/steebchen/kubectl) 操作 k8s 集群，首先要拿到集群的 kubeconfig 配置文件。有两点要注意：

1. kubeconfig 文件路径不一定相同，我的在 `/etc/kubernetes/admin.conf` 目录下。

2. kubeconfig 文件中的访问地址一般为内网 ip 地址，需要修改成公网 ip 地址，这样 Github 才能访问到：

   ![image-20231017200714429](https://s2.loli.net/2023/10/17/ZOBxoFuPfzvCRWI.png)

   如果使用公网 ip 时报错：`tls: failed to verify certificate: x509: certificate is valid for xx.xx.x.x, not xx.xx.x.x`，需要为这个 ip 生成证书，操作如下：

   - 删除旧证书：`rm /etc/kubernetes/pki/apiserver.*`
   - 使用 kubeadm 生成新证书：`kubeadm init phase certs apiserver --apiserver-cert-extra-sans ${公网ip}`

## 创建 Repository secrets

创建以下三个 secret：

- DOCKER_REGISTRY_USERNAME 镜像仓库用户名
- DOCKER_REGISTRY_PASSWORD 镜像仓库密码
- KUBECONFIG kubeconfig 配置文件的 base64，参考命令： `cat /etc/kubernetes/admin.conf|base64`

![image-20231017194803963](https://s2.loli.net/2023/10/17/6LIGcdnfaos3Dhx.png)

## Github Action

在代码仓库添加 `.github/workflows/deploy.yml` 文件：

```yaml
name: deploy
on:
  push:
    branches:
      - main # 推送到 main 分支时触发

jobs:
  build_and_push:
    runs-on: ubuntu-22.04
    steps:
      -
        name: Checkout
        uses: actions/checkout@v4
        with:
          submodules: true # 博客主题是通过 submodule 的方式引入的，签出代码时需要带上
          fetch-depth: 0
      -
        name: Set up QEMU
        uses: docker/setup-qemu-action@v3
      -
        name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      -
        name: Login to Docker Registry
        uses: docker/login-action@v3
        with:
            registry: registry.rjp.pub
            username: ${{ secrets.DOCKER_REGISTRY_USERNAME }}
            password: ${{ secrets.DOCKER_REGISTRY_PASSWORD }}
      -
        name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/arm64
          push: true
          tags: registry.rjp.pub/blog:${{ github.sha }} # 使用 github.sha 作为镜像版本号

  deploy:
    runs-on: ubuntu-22.04
    needs: build_and_push
    steps:
      -
        name: Deploy to Kubernetes
        uses: steebchen/kubectl@v2.0.0
        with:
          config: ${{ secrets.KUBECONFIG }}
          version: v1.23.3 # kubectl 版本，建议跟 K8s 集群的 kubectl 版本保持一致
          command: set image deployment/blog blog=registry.rjp.pub/blog:${{ github.sha }} -n blog
```

## 推送代码

每次将代码推送到 main 分支时就会触发对应的 workflow，打包推送镜像，并更新 K8s 镜像版本：

![image-20231018091629374](https://s2.loli.net/2023/10/18/gMa9U8fikV3BjvE.png)
