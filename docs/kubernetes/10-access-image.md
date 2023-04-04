# 实战 | 加速访问镜像

访问镜像的目标地址是按镜像地址中主机部分来寻址，缺省时是`hub.docker.com`，考虑到很多私有化部署时下载镜像速度过慢。

访问过慢的原因无外乎，资源在国外或者私有化出口网络资源过窄。



> 现整理常用加速方式

- 切换到镜像站
- 下载到私有库
- 使用代理通道



## 一、切换到镜像站

镜像站会将目标源站的资源缓存起来，并优化分发速度。

我们常使用的镜像站

- 阿里`registry.aliyun.com`
- 腾讯
- 网易
- 教育



## 二、下载到私有库

在私有网络环境自建存储库，常用存储库[Harbor](https://github.com/goharbor/harbor)。

从外部将镜像站下载并上传至私有存储库。



### 2.1 手动

将外部镜像产物拉到私有环境缓存起来[下载脚本](https://books.8ops.top/attachment/kubernetes/bin/02-pull-image-to-local.sh)

```bash
#!/bin/bash

#
# usage
#  pull_image_to_local.sh kubernetesui/metrics-scraper:v1.0.7
#  pull_image_to_local.sh registry.cn-hangzhou.aliyuncs.com/google_containers/nginx-ingress-controller:v1.1.0
#  pull_image_to_local.sh nginx:1.21.4 third
#
# explain
#  docker pull kubernetesui/metrics-scraper:v1.0.7
#  docker tag kubernetesui/metrics-scraper:v1.0.7 hub.8ops.top/google_containers/metrics-scraper:v1.0.7
#  docker push hub.8ops.top/google_containers/metrics-scraper:v1.0.7
#  docker rmi kubernetesui/metrics-scraper:v1.0.7
#  docker rmi hub.8ops.top/google_containers/metrics-scraper:v1.0.7
#

set -e

src=$1
dst=$2
harbor=hub.8ops.top
[ -z ${dst} ] && dst=google_containers
docker pull ${src}
docker tag ${src} `echo ${src} |awk -v harbor=${harbor} -v dst=${dst} -F'/' '{printf("%s/%s/%s",harbor,dst,$NF)}'`
docker push `echo ${src} |awk -v harbor=${harbor} -v dst=${dst} -F'/' '{printf("%s/%s/%s",harbor,dst,$NF)}'`
docker rmi ${src}
docker rmi `echo ${src} |awk -v harbor=${harbor} -v dst=${dst} -F'/' '{printf("%s/%s/%s",harbor,dst,$NF)}'`

```



### 2.2 image-syncer

[image-syncer](https://github.com/AliyunContainerService/image-syncer)是个不错的工具

> auth.json

```json
{
  "hub.8ops.top": {
    "username": "",
    "password": ""
  }
}
```



> images.json

```json
{
  "registry.cn-hangzhou.aliyuncs.com/google_containers/kube-apiserver:v1.23.0": "hub.8ops.top/google_containers/kube-apiserver",
  "registry.cn-hangzhou.aliyuncs.com/google_containers/kube-controller-manager:v1.23.0": "hub.8ops.top/google_containers/kube-controller-manager",
  "registry.cn-hangzhou.aliyuncs.com/google_containers/kube-scheduler:v1.23.0": "hub.8ops.top/google_containers/kube-scheduler",
  "registry.cn-hangzhou.aliyuncs.com/google_containers/kube-proxy:v1.23.0": "hub.8ops.top/google_containers/kube-proxy",
  "registry.cn-hangzhou.aliyuncs.com/google_containers/coredns:1.8.6": "hub.8ops.top/google_containers/coredns",
  "registry.cn-hangzhou.aliyuncs.com/google_containers/etcd:3.5.1-0": "hub.8ops.top/google_containers/etcd",
  "registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.6": "hub.8ops.top/google_containers/pause"
}
```

需要存在项目 `hub.8ops.top/google_containers` ，否则会出现同步不成功情况



```bash
image-syncer --auth=auth.json --images=images.json --arch=amd64 --os=linux
```

一定要指定**arch**，否则会同步非预期的arch镜像产物过来



## 三、使用代理通道

原理是网络层面的代理访问。



### 3.1 系统代理

从系统层面使用网络代理

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
```



### 3.2 工具代理

在下载镜像的位置使用网络代理加速访问速度。

> 常用的位置

- dockerd
- containerd

```bash
# ~/.docker/config.json
{
 "proxies":
 {
   "default":
   {
     "httpProxy": "http://192.168.1.12:3128",
     "httpsProxy": "http://192.168.1.12:3128",
     "noProxy": "*.test.example.com,.example2.com,127.0.0.0/8"
   }
 }
}
```



