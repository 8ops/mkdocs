# rabbitmq

[tutorials](https://rabbitmq.com/getstarted.html)

| hostname           | IP            |      |
| ------------------ | ------------- | ---- |
| K-Lab-ORCH-NODE-01 | 10.101.11.116 |      |
| K-Lab-ORCH-NODE-02 | 10.101.11.186 |      |
| K-Lab-ORCH-NODE-03 | 10.101.11.94  |      |



## 一、install

[Reference](https://rabbitmq.com/install-rpm.html)

[cluster](https://rabbitmq.com/clustering.html)

### 1.1 bare metal 

[erlang support](https://www.rabbitmq.com/which-erlang.html)



> upgrade openssl

```
Older distributions can also lack a recent enough version of OpenSSL. Erlang 24 cannot be used on distributions that do not provide OpenSSL 1.1 as a system library. CentOS 7 and Fedora releases older than 26 are examples of such distributions
```
#### 1.1.1 perl

```bash
# install perl's IPC/Cmd.pm
# perl --version: v5.16.3
yum install perl-CPAN -y -q

# 替换国内源
## method 1
rm -f ~/.cpan/CPAN/MyConfig.pm
PERL_MM_USE_DEFAULT=1 perl -MCPAN -e 'CPAN::HandleConfig->edit("urllist", "unshift", "https://mirrors.tuna.tsinghua.edu.cn/CPAN/"); mkmyconfig'
# OR
PERL_MM_USE_DEFAULT=1 perl -MCPAN -e 'CPAN::HandleConfig->edit("urllist", "unshift", "http://mirrors.aliyun.com/CPAN/"); mkmyconfig'

## method 2
perl -MCPAN -e shell
o conf 查看配置信息
o conf urllist 查看当前源地址
o conf urllist pop http://www.cpan.org/
o conf urllist push http://mirrors.aliyun.com/CPAN/ 添加阿里云的源地址
o conf commit 确认添加
o conf urllist ftp://mirrors.sohu.com/CPAN/ http://mirrors.163.com/cpan/ http://mirrors.ustc.edu.cn/CPAN/ 一次添加多个源地址
o conf urllist pop http://mirrors.163.com/cpan/ ftp://mirrors.sohu.com/CPAN/ 移除源地址

# 安装依赖库
perl -MCPAN -e shell
install IPC/Cmd.pm

# OR
yum install -y perl-IPC-Cmd

```



#### 1.1.2 openssl

[Referernce](https://www.openssl.org/source)

```bash
# download
OPENSSL_VERSION=3.1.1
wget --no-check-certificate -O openssl-${OPENSSL_VERSION}.tar.gz https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz
tar -zxf openssl-${OPENSSL_VERSION}.tar.gz  -C .

# configure
yum install gcc gcc-c++ make binutils -q -y 
cd openssl-${OPENSSL_VERSION}
./config --prefix=/usr/local/openssl 
make && make install

# link
ln -s /usr/local/openssl/include/openssl /usr/include/openssl
ln -s /usr/local/openssl/lib64/libssl.so.3 /usr/local/lib64/libssl.so.3
ln -s /usr/local/openssl/lib64/libcrypto.so.3 /usr/local/lib64/libcrypto.so.3

cat > /etc/profile.d/openssl-env.sh <<EOF
export OPENSSL_HOME=/usr/local/openssl/
export PATH=\${OPENSSL_HOME}/bin:\${PATH}
EOF
. /etc/profile.d/openssl-env.sh

# load
echo "/usr/local/openssl/lib64/" > /etc/ld.so.conf.d/openssl-x86_64.conf
ldconfig -v

# output
openssl version

# # env
# LD_RUN_PATH="/usr/local/openssl/lib64" \
# LDFLAGS="-L/usr/local/openssl/lib64" \
# CPPFLAGS="-I/usr/local/openssl/include" \
# CFLAGS="-I/usr/local/openssl/include" \
# CONFIGURE_OPTS="--with-openssl=/usr/local/openssl" 
```



#### 1.1.3 erlang

[Reference](https://github.com/rabbitmq/erlang-rpm)

```bash
ERLANG_VERSION=v26.0.2
https://github.com/rabbitmq/erlang-rpm/releases/download/${ERLANG_VERSION}/erlang-${ERLANG_VERSION}-1.el7.x86_64.rpm
# https://github.com/rabbitmq/erlang-rpm/archive/refs/tags/${ERLANG_VERSION}.tar.gz

rpm -i erlang-${ERLANG_VERSION}-1.el7.x86_64.rpm

# cookie
echo -n 'QDNNEBJPNBMNTJEIKOWV' > ~/.erlang.cookie
chmod 400 ~/.erlang.cookie
ls -l ~/.erlang.cookie && md5sum ~/.erlang.cookie
```



#### 1.1.4 rabbitmq

[Reference](https://www.rabbitmq.com/download.html)

```bash
RABBITMQ_VERSION=3.12.1
wget https://github.com/rabbitmq/rabbitmq-server/releases/download/v${RABBITMQ_VERSION}/rabbitmq-server-generic-unix-${RABBITMQ_VERSION}.tar.xz

xz -d rabbitmq-server-generic-unix-${RABBITMQ_VERSION}.tar.xz
tar xf rabbitmq-server-generic-unix-${RABBITMQ_VERSION}.tar -C /usr/local

ln -s /usr/local/rabbitmq_server-${RABBITMQ_VERSION} /usr/local/rabbitmq_server

cat > /etc/profile.d/rabbitmq-env.sh <<EOF
export RABBITMQ_HOME=/usr/local/rabbitmq_server
export PATH=\${RABBITMQ_HOME}/sbin:${PATH}
EOF
. /etc/profile.d/rabbitmq-env.sh

rabbitmqctl version
mkdir -p /data1/lib/rabbitmq && ln -s /data1/lib/rabbitmq /usr/local/rabbitmq_server/var

# service
cat > /usr/lib/systemd/system/rabbitmq-server.service <<EOF
[Unit]
Description=RabbitMQ broker
After=network.target epmd@0.0.0.0.socket
Wants=network.target epmd@0.0.0.0.socket

[Service]
# Note: You *may* wish to uncomment the following lines to apply systemd
# hardening effort to RabbitMQ, to prevent your system from being illegally 
# modified by undiscovered vulnerabilities in RabbitMQ.
# ProtectSystem=full
# ProtectHome=true
# PrivateDevices=true
# ProtectHostname=true
# ProtectClock=true
# ProtectKernelTunables=true
# ProtectKernelModules=true
# ProtectKernelLogs=true
# ProtectControlGroups=true
# RestrictRealtime=true
Type=notify
User=root
Group=root
NotifyAccess=all
TimeoutStartSec=3600

Restart=on-failure
RestartSec=10
WorkingDirectory=/usr/local/rabbitmq_server
ExecStart=/usr/local/rabbitmq_server/sbin/rabbitmq-server
ExecStop=/usr/local/rabbitmq_server/sbin/rabbitmqctl stop
ExecStop=/bin/sh -c "while ps -p \$MAINPID >/dev/null 2>&1; do sleep 1; done"

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start rabbitmq-server

systemctl enable rabbitmq-server
systemctl is-enabled rabbitmq-server

journalctl -u rabbitmq-server -f

# start
rabbitmq-server -detached
rabbitmqctl stop 
rabbitmqctl status

# plugin
rabbitmq-plugins enable rabbitmq_management
rabbitmq-plugins enable rabbitmq_prometheus
rabbitmq-plugins enable rabbitmq_shovel # 迁移数据

# cluster
rabbitmqctl cluster_status

# user
rabbitmqctl list_users
rabbitmqctl add_user ops jesse
rabbitmqctl set_user_tags ops administrator
rabbitmqctl set_permissions -p / ops ".*" ".*" ".*"

rabbitmqctl delete_user guest
rabbitmqctl add_user guest guest
rabbitmqctl set_user_tags guest administrator
rabbitmqctl set_permissions -p / guest ".*" ".*" ".*"

# node
# 需要在 /etc/hosts 埋好hostname互信解析
# default local [--node <node>]
rabbitmqctl stop_app 
# rabbitmqctl reset # 当不是disc节点时将脱离cluster
# rabbitmqctl join_cluster --ram rabbit@K-Lab-ORCH-NODE-01
rabbitmqctl join_cluster rabbit@K-Lab-ORCH-NODE-01
rabbitmqctl start_app

rabbitmqctl --node rabbit@K-Lab-ORCH-NODE-02 stop_app
rabbitmqctl forget_cluster_node rabbit@K-Lab-ORCH-NODE-02

rabbitmqctl stop_app 
rabbitmqctl change_cluster_node_type disc

# queue
rabbitmqctl list-queue

```



### 1.2 docker

```bash
# RabbitMQ 3.12.1
# Erlang 25.3.2.3
# OpenSSL 3.1.1 30 May 2023 (Library: OpenSSL 3.1.1 30 May 2023)

docker run -d -it --rm --name rabbitmq -p 5672:5672 -p 15672:15672 \
  hub.8ops.top/middleware/rabbitmq:3.12-management


```



## 二、use

### 2.1 config

[Reference](https://www.rabbitmq.com/configure.html)



### 2.2 quorum

[Reference](https://www.rabbitmq.com/quorum-queues.html)

```bash
rabbitmqctl update_vhost_metadata / --default-queue-type quorum

# 当节点发生变化时
rabbitmq-queues rebalance quorum

x-quorum-initial-group-size

raft.wal_max_size_bytes 1GB


# queue demo
    {
      "name": "grus-demo-queue",
      "vhost": "/",
      "durable": true,
      "auto_delete": false,
      "arguments": {
        "durable": true,
        "x-app-name": "grus-demo",
        "x-expires": 2419200000,
        "x-max-length": 10000000,
        "x-message-ttl": 604800000,
        "x-overflow": "reject-publish",
        "x-queue-type": "quorum",
        "x-quorum-initial-group-size": 2
      }
    }
```



### 2.3 perf

[Reference](https://rabbitmq.github.io/rabbitmq-perf-test/stable/htmlsingle/)

```bash
docker run -it --rm pivotalrabbitmq/perf-test:2.19.0 --help

docker run -it --rm pivotalrabbitmq/perf-test:2.19.0 -x 1 -y 2 -u "throughput-test-1" -a --id "test 1"

docker network create perf-test
docker run -d -it --rm --network perf-test --name rabbitmq \
  -p 5672:5672 -p 15692:15692 -p 15672:15672 \
  hub.8ops.top/middleware/rabbitmq:3.12-management

# 1, for docker 1 node
docker run -it --rm --network perf-test --name perf-test \
  pivotalrabbitmq/perf-test:latest \
  --uri amqp://rabbitmq \
  -x 1 -y 2 -u "throughput-test-queue" -a --id "test id" -z 10 -mf compact

id: test id, sending rate avg: 43191 msg/s
id: test id, receiving rate avg: 43030 msg/s
id: test id, consumer latency min/median/75th/95th/99th 6040/617771/664521/743283/824080 µs

# 2, for cluster 3 nodes
docker run -it --rm --network perf-test --name perf-test \
  pivotalrabbitmq/perf-test:2.19.0 \
  --uri amqp://ops:jesse@10.101.11.116:5672 \
  -x 2 -y 2 -u "throughput-test-queue" -a --id "test id" -z 10 -mf compact

sending rate avg: 41610 msg/s
receiving rate avg: 41610 msg/s
consumer latency min/median/75th/95th/99th 474/912685/1796650/2000966/2074222 µs

# 3, big client, for docker 1 node
docker run -it --rm --network perf-test --name perf-test \
  hub.8ops.top/middleware/rabbitmq-perf-test:2.19.0 \
  --uri amqp://rabbitmq \
  -x 10 -y 20 -u "throughput-test-queue" -a --id "test id" -z 10 -mf compact 
  
sending rate avg: 124405 msg/s
receiving rate avg: 124386 msg/s
consumer latency min/median/75th/95th/99th 8609/4767950/5220653/5692634/5878773 µs

# 4, big client, for cluster 3 nodes
docker run -it --rm --network perf-test --name perf-test \
  hub.8ops.top/middleware/rabbitmq-perf-test:2.19.0 \
  --uri amqp://ops:jesse@10.101.11.116:5672 \
  -x 10 -y 20 -u "throughput-test-queue" -a --id "test id" -z 10 -mf compact 

sending rate avg: 42197 msg/s
receiving rate avg: 42197 msg/s
consumer latency min/median/75th/95th/99th 8981/1129273/1297606/1403971/1442604 µs

```



### 2.4 ram disc

<u>区别</u>

- ram，仅存储元信息
- disc，至少有一个节点需要设置成disk，durable时会持久化



<u>磁盘存储消息量</u>

映射关系，`12 byte x 968,997 = 11.09 MB 产生持久数据 226 MB` 



### 2.5 restart stop

```bash

systemctl stop rabbitmq-server

systemctl start rabbitmq-server
```





## 三、note

### 3.1 case 1

```bash
erlang　R16B03-1
rabbitmq-server 3.2.4
simplejson 3.4.0

xmlto 0.0.25
amqplib 1.0.2
python-txamqp 0.3

http://www.erlang.org/download/otp_src_R16B03-1.tar.gz
http://www.rabbitmq.com/releases/rabbitmq-server/v3.2.4/rabbitmq-server-3.2.4-1.noarch.rpm
http://www.rabbitmq.com/releases/rabbitmq-server/v3.2.4/rabbitmq-server-generic-unix-3.2.4.tar.gz
https://pypi.python.org/packages/source/s/simplejson/simplejson-3.4.0.tar.gz
https://fedorahosted.org/releases/x/m/xmlto/xmlto-0.0.25.tar.gz
https://py-amqplib.googlecode.com/files/amqplib-1.0.2.tgz
https://launchpad.net/txamqp/trunk/0.3/+download/python-txamqp_0.3.orig.tar.gz

Ubuntu 
apt-get install -y libncurses5-dev

CentOS
yum install -y ncurses-devel.x86_64
yum install -y gcc.x86_64 gcc-c++.x86_64 zlib.x86_64 zlib-devel.x86_64 binutils.x86_64 kernel-devel.x86_64 m4.x86_64 openssl-devel.x86_64 
yum install -y unixODBC.x86_64 
yum install -y xmlto.x86_64

wget -O /etc/yum.repos.d/epel-erlang.repo http://repos.fedorapeople.org/repos/peter/erlang/epel-erlang.repo
yum install erlang.x86_64
```



### 3.2 case 2

```bash
测试机器
192.168.1.50 
CentOS6.4-x64

实际安装情况
python 2.6.6 系统默认未改 （升级至2.7.6估计是使用管理的功能）
Erlang R16B03 编译安装
RabbitMQ 3.2.4 解压使用 （依赖 Erlang/Simplejson/Xmlto）

Erlang 安装
yum install -y ncurses-devel.x86_64
./configure 
make 
make install 
--without-javac  //不用java编译，故去掉java避免错误  

Simplejson 安装
python setup.py install

RabbitMQ 安装
tar xvzf rabbitmq-server-generic-unix-3.2.4.tar.gz -C /usr/local/
环境配置
vim /etc/profile

env RabbitMQ

export RABBITMQ=/usr/local/rabbitmq_server-3.2.4
export PATH=RABBITMQ/sbin:PATH

vim jdk.sh 

env jdk1.6

export JAVA_HOME=/usr/local/jdk1.6.0_27
export JRE_HOME=JAVA_HOME/jre
export CLASSPATH=.:JAVA_HOME/lib:%JAVA_HOME/lib/dt.jar:JAVA_HOME/lib/tools.jar:JRE_HOME/lib
export PATH=JAVA_HOME/bin:JRE_HOME/bin:$PATH

ll /root/.erlang.cookie 
-r-------- 1 root root 20 7月   8 16:24 /root/.erlang.cookie

启用管理插件
rabbitmq-plugins enable rabbitmq_management

启动服务
rabbitmq-server start &
or 
rabbitmq-server -detached

netstat -nutlp | grep 15672

浏览器进入管理界面 
http://192.168.1.50:15672
guest/guest

---

关闭服务
rabbitmqctl stop 

开启某个插件：rabbitmq-plugins enable rabbitmq_management
关闭某个插件：rabbitmq-plugins disable rabbitmq_management
（重启服务器后生效）

新建virtual_host: rabbitmqctl add_vhost s50
撤销virtual_host: rabbitmqctl delete_vhost s50

验证
curl http://192.168.1.50:15672/api/vhosts

新建user: rabbitmqctl add_user jesse pass
撤销user: rabbitmqctl delete_user jesse
设置tags: rabbitmqctl set_user_tags jesse administrator
授权user: rabbitmqctl set_permissions -p / jesse "." "." ".*"

rabbitmqctl -n node1 add_user uplus pass
rabbitmqctl -n node1 set_user_tags uplus management
rabbitmqctl -n node1 set_permissions -p / uplus "." ." ".*"

---

简单指定配置文件
cat etc/rabbitmq/rabbitmq-env.conf
RABBITMQ_NODENAME=Jesse-888888
RABBITMQ_NODE_IP_ADDRESS=127.0.0.1
RABBITMQ_NODE_PORT=7777
RABBITMQ_LOG_BASE=/data/logs/rabbitmq
RABBITMQ_PLUGINS_DIR=/usr/local/rabbitmq_server-3.2.4/plugins
RABBITMQ_MNESIA_BASE=/data/logs/rabbitmq/mnesia

shell 脚本 可以查看具体逻辑
sbin/
rabbitmqctl             系统管理工具
rabbitmq-defaults       默认配置
rabbitmq-env            环境
rabbitmq-plugins        插件
rabbitmq-server         服务

管理工具帮助手册

rabbitmqctl -h

Error: could not recognise command
Usage:
rabbitmqctl [-n <node>] [-q] <command> [<command options>] 

Options:
    -n node
    -q

Default node is "rabbit@server", where server is the local host. On a host 
named "server.example.com", the node name of the RabbitMQ Erlang node will 
usually be rabbit@server (unless RABBITMQ_NODENAME has been set to some 
non-default value at broker startup time). The output of hostname -s is usually 
the correct suffix to use after the "@" sign. See rabbitmq-server(1) for 
details of configuring the RabbitMQ broker.

Quiet output mode is selected with the "-q" flag. Informational messages are 
suppressed when quiet mode is in effect.

Commands:
    stop [<pid_file>]
    stop_app
    start_app
    wait <pid_file>
    reset
    force_reset
    rotate_logs <suffix>

    join_cluster <clusternode> [--ram]
    cluster_status
    change_cluster_node_type disc | ram
    forget_cluster_node [--offline]
    update_cluster_nodes clusternode
    sync_queue queue
    cancel_sync_queue queue
    
    add_user <username> <password>
    delete_user <username>
    change_password <username> <newpassword>
    clear_password <username>
    set_user_tags <username> <tag> ...
    list_users
    
    add_vhost <vhostpath>
    delete_vhost <vhostpath>
    list_vhosts [<vhostinfoitem> ...]
    set_permissions [-p <vhostpath>] <user> <conf> <write> <read>
    clear_permissions [-p <vhostpath>] <username>
    list_permissions [-p <vhostpath>]
    list_user_permissions <username>
    
    set_parameter [-p <vhostpath>] <component_name> <name> <value>
    clear_parameter [-p <vhostpath>] <component_name> <key>
    list_parameters [-p <vhostpath>]
    
    set_policy [-p <vhostpath>] [--priority <priority>] [--apply-to <apply-to>] 

<name> <pattern>  <definition>
    clear_policy [-p <vhostpath>] <name>
    list_policies [-p <vhostpath>]

    list_queues [-p <vhostpath>] [<queueinfoitem> ...]
    list_exchanges [-p <vhostpath>] [<exchangeinfoitem> ...]
    list_bindings [-p <vhostpath>] [<bindinginfoitem> ...]
    list_connections [<connectioninfoitem> ...]
    list_channels [<channelinfoitem> ...]
    list_consumers [-p <vhostpath>]
    status
    environment
    report
    eval <expr>
    
    close_connection <connectionpid> <explanation>
    trace_on [-p <vhost>]
    trace_off [-p <vhost>]
    set_vm_memory_high_watermark <fraction>

<vhostinfoitem> must be a member of the list [name, tracing].

The list_queues, list_exchanges and list_bindings commands accept an optional 
virtual host parameter for which to display results. The default value is "/".

<queueinfoitem> must be a member of the list [name, durable, auto_delete, 
arguments, policy, pid, owner_pid, exclusive_consumer_pid, 
exclusive_consumer_tag, messages_ready, messages_unacknowledged, messages, 
consumers, memory, slave_pids, synchronised_slave_pids, status].

<exchangeinfoitem> must be a member of the list [name, type, durable, 
auto_delete, internal, arguments, policy].

<bindinginfoitem> must be a member of the list [source_name, source_kind, 
destination_name, destination_kind, routing_key, arguments].

<connectioninfoitem> must be a member of the list [pid, name, port, host, 
peer_port, peer_host, ssl, ssl_protocol, ssl_key_exchange, ssl_cipher, 
ssl_hash, peer_cert_subject, peer_cert_issuer, peer_cert_validity, 
last_blocked_by, last_blocked_age, state, channels, protocol, auth_mechanism, 
user, vhost, timeout, frame_max, client_properties, recv_oct, recv_cnt, 
send_oct, send_cnt, send_pend].

<channelinfoitem> must be a member of the list [pid, connection, name, number, 
user, vhost, transactional, confirm, consumer_count, messages_unacknowledged, 
messages_uncommitted, acks_uncommitted, messages_unconfirmed, prefetch_count, 
client_flow_blocked].

---

python依赖库
amqplib-1.0.2           
pika-0.9.13            
python-txamqp-0.3


```



### 3.3 case 3

```bash
# Cluster 搭建与使用

# 参考官方文档 https://www.rabbitmq.com/clustering.html

# 前题：
# 1，Erlang 与 RabbitMQ_Server 版本一致
# 2，RabbitMQ_Server 使用的 cookies 一致

# 演示操作
node0: 192.168.1.50/24
node1: 192.168.1.51/24
node2: 192.168.1.52/24

# 配置 hosts 信息 or 内部 dns 信息
10.0.10.50  s50
10.0.10.51  s51
10.0.10.52  s52

# 第一步：启动各节点 rabbitmq_server,启动 rabbitmq_server
rabbitmq_server -detached

# 查看集群状态
rabbitmqctl cluster_status

[{nodes,[{disc,[rabbit@s50]}]},{running_nodes,[rabbit@s50]},{partitions,[]}]
or
[
    {nodes,
        [
            {disc,
                [rabbit@s50]
            }
        ]
    },
    {
        running_nodes,
        [rabbit@s50]
    },
    {partitions,[]}
]

# 第二步：同步 cookie 

# 停止 node2 rabbitmq-server
rabbitmqctl stop_app
/root/.erlang.cookie

# 第三步：将 node2 加入集群

# 启动 node2 --> rabbitmq-server 
rabbitmqctl stop_app
rabbitmqctl join_cluster --ram rabbit@s50
rabbitmqctl start_app

# ---- 这样 cluster 就搭建起来了

# 验证效果  rabbitmqctl list_queues

# 启动节点监控代理
rabbitmqctl stop
rabbitmq-plugins enable rabbitmq_management_agent
rabbitmq-plugins list
rabbitmq-server -detached

# 第四步：节点管理,改变节点类型（非必须）
rabbitmqctl stop_app
rabbitmqctl change_cluster_node_type disc
rabbitmqctl start_app

rabbitmqctl cluster_status

# 主动脱离集群,进入node1
rabbitmqctl stop_app
rabbitmqctl reset
rabbitmqct1 start_app

# 再查看集群状态，和脱离节点状态 cluster_status

# 集群丢弃节点,进入node2
rabbitmqctl stop_app

# 进入node1
rabbitmqctl forget_cluster_node rabbit@s52

# 第五步：使用 rabbitmq.conf & rabbitmq-env.conf 配置启动服务

# 参考
https://www.rabbitmq.com/configure.html#configuration-file
http://www.erlang.org/doc/man/config.html

/usr/local/rabbitmq_server-3.2.4/etc/rabbitmq/rabbitmq-env.conf
/usr/local/rabbitmq_server-3.2.4/etc/rabbitmq/rabbitmq.conf
or
/etc/rabbitmq/rabbitmq.conf

# ================================================================================

# 注意使用区别

rabbitmq-server -detached ==> rabbitmqctl stop
rabbitmqctl start_app     ==> rabbitmqctl stop_app


# Web API 插件
rabbitmq_web_stomp                      web 接口
rabbitmq_web_stomp_examples             实例
RabbitMQ Management HTTP API            所有功能接口

# ================================================================================

# 指定配置搭建集群 Cluster

RABBITMQ_CONFIG_FILE=/usr/local/rabbitmq_server-3.2.4/etc/rabbitmq/rabbitmq_r1 RABBITMQ_NODE_PORT=5671 RABBITMQ_SERVER_START_ARGS="-rabbitmq_management listener [{port,15671}]" RABBITMQ_NODENAME=r1 /usr/local/rabbitmq_server-3.2.4/sbin/rabbitmq-server -detached
sleep 5
RABBITMQ_CONFIG_FILE=/usr/local/rabbitmq_server-3.2.4/etc/rabbitmq/rabbitmq_r2 RABBITMQ_NODE_PORT=5672 RABBITMQ_SERVER_START_ARGS="-rabbitmq_management listener [{port,15672}]" RABBITMQ_NODENAME=r2 /usr/local/rabbitmq_server-3.2.4/sbin/rabbitmq-server -detached
sleep 5
RABBITMQ_CONFIG_FILE=/usr/local/rabbitmq_server-3.2.4/etc/rabbitmq/rabbitmq_r3 RABBITMQ_NODE_PORT=5673 RABBITMQ_SERVER_START_ARGS="-rabbitmq_management listener [{port,15673}]" RABBITMQ_NODENAME=r3 /usr/local/rabbitmq_server-3.2.4/sbin/rabbitmq-server -detached

rabbitmqctl -n r2@s151 stop_app
rabbitmqctl -n r2@s151 change_cluster_node_type ram
rabbitmqctl -n r2@s151 start_app
rabbitmqctl -n r2@s151 cluster_status

rabbitmqctl -n r3@s151 stop_app
rabbitmqctl -n r3@s151 change_cluster_node_type ram
rabbitmqctl -n r3@s151 start_app
rabbitmqctl -n r3@s151 cluster_status

rabbitmqctl -n r1 stop
rabbitmqctl -n r2 stop
rabbitmqctl -n r3 stop

# 镜像队列,全部镜像 
rabbitmqctl -n r1@s151 set_policy ha-all "^ha." '{"ha-mode":"all"}'
rabbitmqctl -n r1@s151 set_policy ha-queue "^queue" '{"ha-mode":"all"}'
rabbitmqctl -n r1@s151 set_policy ha-uplus "^uplus" '{"ha-mode":"all"}'

# 指定个数的镜像，任意两个节点机器 

rabbitmqctl -n r1@s151 set_policy ha-test-exactly "^test.exactly" '{"ha-mode":"exactly","ha-params":2}'

# 指定固定几个节点内镜像

rabbitmqctl -n r1@s151 set_policy ha-test-nodes "^test.nodes" '{"ha-mode":"nodes","ha-params":["r1@s151","r2@s151"]}'

```

### 3.4 重启失败

```bash
# 释放所有进程
kill $pid

# 反复启动
systemctl start rabbitmq-server
```

