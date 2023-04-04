# rabbitmq

```bash


# 安装过程集锦

================================================================================
资源下载（以下都是最新release版本 ~ 2014-05-13）
参考版本号
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

================================================================================
RabbitMQ 的安装与使用
单机搭建

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

python 简单使用 Demo

安装以下依赖库
amqplib-1.0.2           
pika-0.9.13            
python-txamqp-0.3

同时依赖这三个库
使用见 git@github.com:xtso520ok/rabbitmq-demo.git

================================================================================

Cluster 搭建与使用

参考官方文档 https://www.rabbitmq.com/clustering.html

前题：
1，Erlang 与 RabbitMQ_Server 版本一致
2，RabbitMQ_Server 使用的 cookies 一致

演示操作
node0: 192.168.1.50/24
node1: 192.168.1.51/24
node2: 192.168.1.52/24

配置 hosts 信息 or 内部 dns 信息
10.0.10.50  s50
10.0.10.51  s51
10.0.10.52  s52

第一步：启动各节点 rabbitmq_server
启动 rabbitmq_server
rabbitmq_server -detached

查看集群状态
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

第二步：同步 cookie 

停止 node2 rabbitmq-server
rabbitmqctl stop_app
/root/.erlang.cookie

第三步：将 node2 加入集群

启动 node2 --> rabbitmq-server 
rabbitmqctl stop_app
rabbitmqctl join_cluster --ram rabbit@s50
rabbitmqctl start_app

---- 这样 cluster 就搭建起来了

验证效果  rabbitmqctl list_queues

启动节点监控代理
rabbitmqctl stop
rabbitmq-plugins enable rabbitmq_management_agent
rabbitmq-plugins list
rabbitmq-server -detached

第四步：节点管理

改变节点类型（非必须）
rabbitmqctl stop_app
rabbitmqctl change_cluster_node_type disc
rabbitmqctl start_app

rabbitmqctl cluster_status

主动脱离集群
进入node1
rabbitmqctl stop_app
rabbitmqctl reset
rabbitmqct1 start_app

再查看集群状态，和脱离节点状态 cluster_status

集群丢弃节点
进入node2
rabbitmqctl stop_app

进入node1
rabbitmqctl forget_cluster_node rabbit@s52

第五步：使用 rabbitmq.conf & rabbitmq-env.conf 配置启动服务

参考
https://www.rabbitmq.com/configure.html#configuration-file
http://www.erlang.org/doc/man/config.html

/usr/local/rabbitmq_server-3.2.4/etc/rabbitmq/rabbitmq-env.conf
/usr/local/rabbitmq_server-3.2.4/etc/rabbitmq/rabbitmq.conf
or
/etc/rabbitmq/rabbitmq.conf



================================================================================

注意使用区别

rabbitmq-server -detached ==> rabbitmqctl stop
rabbitmqctl start_app     ==> rabbitmqctl stop_app



Web API 插件
rabbitmq_web_stomp                      web 接口
rabbitmq_web_stomp_examples             实例
RabbitMQ Management HTTP API            所有功能接口

================================================================================

指定配置搭建集群 Cluster

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

镜像队列

全部镜像 

rabbitmqctl -n r1@s151 set_policy ha-all "^ha." '{"ha-mode":"all"}'
rabbitmqctl -n r1@s151 set_policy ha-queue "^queue" '{"ha-mode":"all"}'
rabbitmqctl -n r1@s151 set_policy ha-uplus "^uplus" '{"ha-mode":"all"}'

指定个数的镜像，任意两个节点机器 

rabbitmqctl -n r1@s151 set_policy ha-test-exactly "^test.exactly" '{"ha-mode":"exactly","ha-params":2}'

指定固定几个节点内镜像

rabbitmqctl -n r1@s151 set_policy ha-test-nodes "^test.nodes" '{"ha-mode":"nodes","ha-params":["r1@s151","r2@s151"]}'



```

