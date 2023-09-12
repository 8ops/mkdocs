# Docker

## 一、常用技巧

### 1.1 docker基础镜像

- Alpine
- Slim
- Stretch
- Buster
- Jessie
- Bullseye
- windowsservercore



### 1.2  容器随机启动

```bash
# 1，容器启动时
docker run --restart=
  no           默认策略，在容器退出时不重启容器
  on-failure   在窗口非正常退出时（退出状态非0），才会重启容器
  on-failure:3 在容器非正常退出时重启容器，最多重启3次
  always       在容器退出时总是重启容器

# 2，容器运行中
docker update --restart=always <container id>

```



### 1.3 Centos

```bash
# 国内
yum install -y yum-utils
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

yum search docker-ce
yum info docker-ce
yum install docker-ce

mkdir -p /srv/lib/docker
ln -s /srv/lib/docker /var/lib/docker
systemctl enable docker
systemctl is-enabled docker
systemctl start docker
systemctl status docker

yum search docker-compose
yum install -y docker-compose
```



## 二、CRI

|                     | docker            | ctr（containerd）            | crictl（kubernetes） |
| :------------------ | :---------------- | :--------------------------- | :------------------- |
| 查看运行的容器      | docker ps         | ctr task ls/ctr container ls | crictl ps            |
| 查看镜像            | docker images     | ctr image ls                 | crictl images        |
| 查看容器日志        | docker logs       | 无                           | crictl logs          |
| 查看容器数据信息    | docker inspect    | ctr container info           | crictl inspect       |
| 查看容器资源        | docker stats      | 无                           | crictl stats         |
| 启动/关闭已有的容器 | docker start/stop | ctr task start/kill          | crictl start/stop    |
| 运行一个新的容器    | docker run        | ctr run                      | 无（最小单元为 pod） |
| 修改镜像标签        | docker tag        | ctr image tag                | 无                   |
| 创建一个新的容器    | docker create     | ctr container create         | crictl create        |
| 导入镜像            | docker load       | ctr image import             | 无                   |
| 导出镜像            | docker save       | ctr image export             | 无                   |
| 删除容器            | docker rm         | ctr container rm             | crictl rm            |
| 删除镜像            | docker rmi        | ctr image rm                 | crictl rmi           |
| 拉取镜像            | docker pull       | ctr image pull               | ctictl pull          |
| 推送镜像            | docker push       | ctr image push               | 无                   |
| 在容器内部执行命令  | docker exec       | 无                           | crictl exec          |
