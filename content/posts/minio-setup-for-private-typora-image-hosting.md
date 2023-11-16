---
title: "Minio 部署和配置：打造私有 Typora 图床"
date: 2023-10-25T19:21:24+08:00
draft: false
---

> 本文主要适用于 Typora 的 Mac 版本。请注意，截至当前，Typora 的 Windows 版本并不支持 uPic 图床工具。对于 Windows 用户，建议使用 PicGo、PicList 等其他工具替代。

## 部署 Minio

Minio 单节点部署到 k8s 集群：`kubectl apply -f minio.yaml`

minio.yaml：

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: minio
  labels:
    name: minio

---
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: minio
spec:
  selector:
    app: minio
  ports:
    - protocol: TCP
      name: console
      port: 9090
      targetPort: 9090
    - protocol: TCP
      name: api
      port: 9091
      targetPort: 9091
  type: ClusterIP

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: minio
spec:
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
      - name: minio
        image: quay.io/minio/minio:latest
        command:
        - /bin/bash
        - -c
        args:
        - minio server /data --console-address :9090 --address :9091
        ports:
        - containerPort: 9090
          name: console
          protocol: TCP
        - containerPort: 9091
          name: api
          protocol: TCP
        env:
        - name: MINIO_ROOT_USER
          value: minio
        - name: MINIO_ROOT_PASSWORD
          value: minio
        - name: MINIO_SERVER_URL # 指定 MinIO 服务器的代理可访问主机名，以允许控制台通过 TLS 证书使用 MinIO 服务器 API
          value: https://oss.rjp.pub
        volumeMounts:
        - mountPath: /data
          name: localvolume # Corresponds to the `spec.volumes` Persistent Volume
      volumes:
      - name: localvolume
        hostPath: # MinIO generally recommends using locally-attached volumes
          path: /data/nfs/minio # Specify a path to a local drive or volume on the Kubernetes worker node
          type: DirectoryOrCreate # The path to the last directory must exist
```

## 配置 Ingress

创建 ingress 配置，用于访问 minio 服务：

- minio.rjp.pub 对应 minio 的 9090 端口，用于访问控制台
- oss.rjp.pub 对应 minio 的 9091 端口，用于调用兼容 S3 协议的 API 接口

通过 APISIX Dashboard 查看 Ingress 配置：

![image-20231115223442965](https://oss.rjp.pub/upic/2023/11/15/image-20231115223442965.png)

## 配置 uPic

1. 下载并安装 uPic

   参考[官方文档](https://github.com/gee1k/uPic)

2. uPic 配置：

   由于 Minio 兼容 S3 协议，因此在 uPic 中，可以选择 Amazon S3 作为图床。具体配置方法如下：

   - 服务端 URL：对应 minio.yaml 中的 MINIO_SERVER_URL

   - 空间名称：对应 minio 中创建的 Bucket
   - AccessKey：对应 minio.yaml 中的 MINIO_ROOT_USER
   - SecretKey：对应 minio.yaml 中的 MINIO_ROOT_PASSWORD
   - 保存路径：minio 中图片保存的路径

3. 点击「验证」按钮，提示上传成功

![image-20231115224337236](https://oss.rjp.pub/upic/2023/11/15/image-20231115224337236.png)

## 配置 Typora

在 **偏好设置 > 图像 > 上传服务** 中选择 uPic，任何粘贴到 Typora 中的图片都会通过 uPic 自动上传到 Minio。这些图片将被转换为访问链接并展示。

![image-20231115182905896](https://oss.rjp.pub/upic/2023/11/15/image-20231115182905896.png)
