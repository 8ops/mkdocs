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



### 1.4 docker-compose

```bash
# down binary
# from https://docs.docker.com/compose/install/standalone/
curl -SL https://github.com/docker/compose/releases/download/v2.23.3/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose

# from epel
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



## 三、银河麒麟

通过二进制安装 docker

通过在线软件源和 `rpm` 包不能直接安装，那么只能选择通过编译安装了，去官网找了下发现提供有编译好的 docker 二进制包，直接下载二进制包安装吧，感谢 golang 的跨平台性。

### 3.1 安装条件

- **64位**的操作系统

  ```
  shell
  
  # uname -p
  aarch64
  ```

- Linux 内核版本 `≥ 3.10`

  ```
  shell
  
  # uname -r
  4.19.90-17.ky10.aarch64
  ```

- `iptables` 版本 `≥ 1.4`

  ```
  shell
  
  # iptables --version
  iptables v1.8.1 (legacy)
  ```

- 一个 `ps` 可执行文件，通常由 `procps` 或类似的包提供。

### 3.2 安装 Docker-ce

1. 选择并下载 `docker-ce` 二进制包文件

   官网下载地址：https://download.docker.com/linux/static/stable/aarch64/

   ```
   shell
   
   wget https://download.docker.com/linux/static/stable/aarch64/docker-20.10.7.tgz
   ```

2. 解压下载好的压缩包

   ```
   shell
   
   tar -zxvf docker-20.10.7.tgz
   ```

3. 移动解压出来的二进制文件到 `/usr/bin` 目录中

   ```
   shell
   
   mv docker/* /usr/bin/
   ```

4. 测试启动

   ```
   shell
   
   dockerd
   ```

### 3.3 添加 systemd

1. 添加 docker 的 `systemd` 服务脚本至 `/usr/lib/systemd/system/`

   脚本参考自 [https://github.com/docker/docker-ce](https://github.com/docker/docker-ce/blob/master/components/engine/contrib/init/systemd/docker.service)

   ```
   /usr/lib/systemd/system/docker.service
   
   [Unit]
   Description=Docker Application Container Engine
   Documentation=https://docs.docker.com
   After=network-online.target docker.socket firewalld.service containerd.service
   Wants=network-online.target
   Requires=docker.socket containerd.service
   
   [Service]
   Type=notify
   # the default is not to use systemd for cgroups because the delegate issues still
   # exists and systemd currently does not support the cgroup feature set required
   # for containers run by docker
   ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
   ExecReload=/bin/kill -s HUP $MAINPID
   TimeoutStartSec=0
   RestartSec=2
   Restart=always
   
   # Note that StartLimit* options were moved from "Service" to "Unit" in systemd 229.
   # Both the old, and new location are accepted by systemd 229 and up, so using the old location
   # to make them work for either version of systemd.
   StartLimitBurst=3
   
   # Note that StartLimitInterval was renamed to StartLimitIntervalSec in systemd 230.
   # Both the old, and new name are accepted by systemd 230 and up, so using the old name to make
   # this option work for either version of systemd.
   StartLimitInterval=60s
   
   # Having non-zero Limit*s causes performance problems due to accounting overhead
   # in the kernel. We recommend using cgroups to do container-local accounting.
   LimitNOFILE=infinity
   LimitNPROC=infinity
   LimitCORE=infinity
   
   # Comment TasksMax if your systemd version does not support it.
   # Only systemd 226 and above support this option.
   TasksMax=infinity
   
   # set delegate yes so that systemd does not reset the cgroups of docker containers
   Delegate=yes
   
   # kill only the docker process, not all processes in the cgroup
   KillMode=process
   OOMScoreAdjust=-500
   
   [Install]
   WantedBy=multi-user.target
   ```

2. 根据 `docker.service` 中 `Unit.After` 需求添加 `docker.socket` 脚本至 `/usr/lib/systemd/system/`

   脚本参考自 [https://github.com/docker/docker-ce](https://github.com/docker/docker-ce/blob/master/components/engine/contrib/init/systemd/docker.socket)

   ```
   /usr/lib/systemd/system/docker.socket
   
   [Unit]
   Description=Docker Socket for the API
   
   [Socket]
   # If /var/run is not implemented as a symlink to /run, you may need to
   # specify ListenStream=/var/run/docker.sock instead.
   ListenStream=/run/docker.sock
   SocketMode=0660
   SocketUser=root
   SocketGroup=docker
   
   [Install]
   WantedBy=sockets.target
   ```

   注意：如果缺少该文件，启动 docker 时会报如下错误：

   ```
   shell
   
   # systemctl start docker
   Failed to start docker.service: Unit docker.socket not found.
   ```

3. 根据 `docker.service` 中 `Unit.After` 需求添加 `containerd.service` 脚本至 `/usr/lib/systemd/system/`

   脚本参考自 [https://github.com/containerd/containerd](https://github.com/containerd/containerd/blob/master/containerd.service)

   ```
   /usr/lib/systemd/system/containerd.service
   
   # Copyright The containerd Authors.
   #
   # Licensed under the Apache License, Version 2.0 (the "License");
   # you may not use this file except in compliance with the License.
   # You may obtain a copy of the License at
   #
   #     http://www.apache.org/licenses/LICENSE-2.0
   #
   # Unless required by applicable law or agreed to in writing, software
   # distributed under the License is distributed on an "AS IS" BASIS,
   # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   # See the License for the specific language governing permissions and
   # limitations under the License.
   
   [Unit]
   Description=containerd container runtime
   Documentation=https://containerd.io
   After=network.target local-fs.target
   
   [Service]
   ExecStartPre=-/sbin/modprobe overlay
   ExecStart=/usr/local/bin/containerd
   
   Type=notify
   Delegate=yes
   KillMode=process
   Restart=always
   RestartSec=5
   # Having non-zero Limit*s causes performance problems due to accounting overhead
   # in the kernel. We recommend using cgroups to do container-local accounting.
   LimitNPROC=infinity
   LimitCORE=infinity
   LimitNOFILE=infinity
   # Comment TasksMax if your systemd version does not supports it.
   # Only systemd 226 and above support this version.
   TasksMax=infinity
   OOMScoreAdjust=-999
   
   [Install]
   WantedBy=multi-user.target
   ```

   注意：如果缺少该文件，启动 docker 时会报如下错误：

   ```
   shell
   
   # systemctl restart docker
   Failed to restart docker.service: Unit containerd.service not found.
   ```

4. 重载 `systemd` 配置文件

   ```
   shell
   
   systemctl daemon-reload
   ```

5. 创建 docker 组

   ```
   shell
   
   groupadd docker
   ```

   如不创建 docker 组在通过 `systemctl` 启动时会报错如下

   ```
   systemctl status docker
   
   Dependency failed for Docker Application Container Engine.
   Job docker.service/start failed with result 'dependency'.
   ```

6. 启动 `docker` 服务

   ```
   shell
   
   systemctl start docker
   systemctl enable docker
   ```

7. 修改 docker 配置文件并查看安装好的 docker 基本信息

   - 在 `/etc/docker/daemon.json` 中添加如下内容：

     ```
     /etc/docker/daemon.json
     
     {
         "graph": "/data/docker",
         "storage-driver": "overlay2",
         "exec-opts": [
             "native.cgroupdriver=systemd"
         ],
         "registry-mirrors": [
             "https://t5t8q6wn.mirror.aliyuncs.com"
         ],
         "bip": "172.8.94.1/24"
     }
     ```

   - 重启 docker 服务

     ```
     shell
     
     systemctl restart docker
     ```

   - 查看 docker info
