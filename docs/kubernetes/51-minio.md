# 实战 | MinIO

[Reference](http://docs.minio.org.cn/docs/)

## 一、Server

> linux 

```bash
wget https://dl.min.io/server/minio/release/linux-amd64/minio
chmod +x minio
./minio server /opt/lib/minio

# http://10.101.11.236:9193/buckets
```



> kubernetes

```bash
kubectl krew install minio
kubectl minio init
kubectl minio tenant create tenant1 --servers 4 --volumes 16 --capacity 16Ti
```



### 1.1 Helm

```
helm repo add minio https://charts.min.io/
helm repo update minio
helm search repo minio
helm show values minio/minio --version 5.0.4 > minio-5.0.4.yaml-default

helm show values bitnami/minio --version 11.10.21 > minio-11.10.21.yaml-default

```



## 二、Client

>  linux

```bash
curl https://dl.min.io/client/mc/release/linux-amd64/mc -k -o ~/bin/mc
chmod +x ~/bin/mc

mc --help

mc alias set myminio http://10.101.11.236:9193 minioadmin minioadmin
```

> kubernetes

```bash
kubectl run my-mc -i --tty --image minio/mc:latest --command -- bash
[root@my-mc /]# mc alias set myminio/ https://minio.default.svc.cluster.local MY-USER MY-PASSWORD
[root@my-mc /]# mc ls myminio/mybucket
```

