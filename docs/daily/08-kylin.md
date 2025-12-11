# Kylin

## 一、基本操作

### 1.1 查看

```bash

# 查看OS
cat /etc/os
os-release  ostree/

cat /etc/os-release
NAME="Kylin Linux Advanced Server"
VERSION="V10 (Halberd)"
ID="kylin"
VERSION_ID="V10"
PRETTY_NAME="Kylin Linux Advanced Server V10 (Halberd)"
ANSI_COLOR="0;31"

# 重置hostname
hostnamectl set-hostname K-LAB-XC-01 --transient
hostnamectl set-hostname K-LAB-XC-01 --static
hostnamectl set-hostname K-LAB-XC-01 --pretty

# 查看随开机启动服务
systemctl list-unit-files --type=service | grep enabled 
accounts-daemon.service                    enabled
atd.service                                enabled
auditd.service                             enabled
autovt@.service                            enabled
bluetooth.service                          enabled
chronyd.service                            enabled
cron.service                               enabled
crond.service                              enabled
cups.service                               enabled
dbus-org.bluez.service                     enabled
dbus-org.fedoraproject.FirewallD1.service  enabled
dbus-org.freedesktop.ModemManager1.service enabled
dbus-org.freedesktop.nm-dispatcher.service enabled
display-manager.service                    enabled
firewalld.service                          enabled
getty@.service                             enabled
kdump.service                              enabled
kylin-activation-check.service             enabled
kylin-activation-onboot.service            enabled
kylin-kms-activation.service               enabled
kylin-sock-server.service                  enabled
libstoragemgmt.service                     enabled
lightdm.service                            enabled
lm_sensors.service                         enabled
lvm2-monitor.service                       enabled
mcelog.service                             enabled
mdmonitor.service                          enabled
ModemManager.service                       enabled
NetworkManager-dispatcher.service          enabled
NetworkManager-wait-online.service         enabled
NetworkManager.service                     enabled
rasdaemon.service                          enabled
rc-local.service                           enabled-runtime
restorecond.service                        enabled
rngd.service                               enabled
rsyslog.service                            enabled
rtkit-daemon.service                       enabled
SangforVMSTool.service                     enabled
sfexit.service                             enabled
smartd.service                             enabled
sssd.service                               enabled
sysstat.service                            enabled
systemd-remount-fs.service                 enabled-runtime
systemtap.service                          enabled
tuned.service                              enabled
udisks2.service                            enabled
xinetd.service                             enabled
```



### 1.2 操作

```bash
# 停止不必要的服务
systemctl disable bluetooth.service       # 蓝牙
systemctl disable dbus-org.bluez.service  # 蓝牙
systemctl disable cups.service            # 打印服务
systemctl disable display-manager.service # 图形界面登录管理器
systemctl disable lightdm.service         # 图形界面登录管理器
systemctl disable ModemManager.service    # 3G/4G Modem
systemctl disable dbus-org.freedesktop.ModemManager1.service # 3G/4G Modem
systemctl disable xinetd.service          # 老旧的超级守护进程
systemctl disable rtkit-daemon.service    # 实时调度（桌面多媒体）

# OR
systemctl disable bluetooth || true
systemctl disable restorecond || true
systemctl disable ModemManager || true
systemctl disable rtkit-daemon || true
systemctl disable accounts-daemon || true
systemctl disable lightdm || true
systemctl disable ukui-input-gather || true
systemctl disable upower || true
systemctl disable firewalld || true
systemctl disable kylin-kms-activation || true
rm -f /usr/lib/systemd/system/ctrl-alt-del.target || true
rm -f /etc/systemd/system/ctrl-alt-del.service || true
systemctl daemon-reload

# 停掉后会导致机器重启不挂载网卡
systemctl enable NetworkManager || true
systemctl enable NetworkManager-dispatcher || true
systemctl enable NetworkManager-wait-online || true

# 设置文件打开数
cat >> /etc/security/limits.conf <<EOF
* soft nofile 655350
* hard nofile 655350
* soft nproc  655350
* hard nproc  655350
EOF

# 禁用透明大页（THP）（Kylin 默认开启 THP，会影响数据库场景性能）x
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag

# 切换 CPU 调度模式为 performance x
cpupower frequency-set -g performance
cpupower frequency-info

# NUMA 优化（数据库、虚拟化必要）x
numactl --cpunodebind=0 --membind=0 your_process
numactl --hardware

# 调整 swappiness（避免频繁 swap）x
sysctl -w vm.swappiness=10
sysctl vm.swappiness

# 文件系统缓存优化（适用于高 IO 负载）x
sysctl -w vm.vfs_cache_pressure=50
sysctl vm.vfs_cache_pressure

# I/O 调度器优化（推荐 SSD 设置为 none 或 mq-deadline）x
echo mq-deadline > /sys/block/sda/queue/scheduler
cat /sys/block/sda/queue/scheduler

# 增大 I/O 合并参数 x
sysctl -w vm.dirty_ratio=10
sysctl -w vm.dirty_background_ratio=5
sysctl vm.dirty_ratio
sysctl vm.dirty_background_ratio

# 调整内核网络参数（高并发必备）
vim /etc/sysctl.conf

# high concurrency
net.core.somaxconn = 10240
net.core.netdev_max_backlog = 16384
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 600
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_max_syn_backlog = 8192

# 开启 MTU 检测（适用于万兆网卡）x
ip link set dev eth0 mtu 9000

# 安全加固（兼顾性能）使用 firewalld 或硬件防火墙，不两者并用。重要系统启用 SELinux，但可根据软件兼容度调为 permissive
setenforce 0
sestatus

# 配置 SSH 连接优化：
vim /etc/ssh/sshd_config

GSSAPIAuthentication no
UseDNS no

```



## 二、软件包管理（APT / DNF）

银河麒麟分两个体系：

| 版本                | 包管理器                   |
| ------------------- | -------------------------- |
| 麒麟 V10（普遍）    | `apt`（基于 Ubuntu/Kylin） |
| 安全增强版 / 高级版 | `dnf`（基于 RPM）          |

### 2.1 查询软件来源

```
apt-cache policy nginx
dnf repoquery nginx
```

### 2.2 一键更新系统

```
apt update && apt upgrade -y
```

或：

```
dnf update -y
```



## 三、 Kylin 特有工具

### 3.1 Kylin 性能监控 KPIMon

图形界面 & CLI 版本，CLI 示例：

```
kpimon-cli --cpu
kpimon-cli --disk
```

### 3.2 Kylin System Guard（系统卫士）

实时监控：

```
ksguard
```



## 四、日志管理技巧（journalctl）

查看服务最新日志：

```
journalctl -u nginx -f
```

按时间：

```
journalctl --since "1 hour ago"
```

按优先级：

```
journalctl -p err
```





## 五、 常用虚拟化 / 容器技巧

KVM 查看虚拟机 CPU 透传

```
virsh capabilities | grep feature
```

Docker（麒麟官方支持）

```
systemctl enable docker
docker system prune -af
```



## 六、 防火墙技巧（firewalld）

开放端口：

```
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --reload
```

查看规则：

```
firewall-cmd --list-all
```



## 六、文件系统管理技巧（ext4/xfs）

ext4 开启目录索引

```
tune2fs -O dir_index /dev/sda1
```

xfs 扩容（LVM）

```
xfs_growfs /data
```