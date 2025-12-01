# Kylin

## 一、基本操作

### 1.1 查看

```bash

# 查看OS
[root@localhost ~]# cat /etc/os
os-release  ostree/
[root@localhost ~]# cat /etc/os-release
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
[root@localhost ~]# systemctl list-unit-files --type=service | grep enabled
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
systemctl disable bluetooth.service
systemctl disable cups.service

# 设置文件打开数
cat >> /etc/security/limits.conf <<EOF
* soft nofile 655350
* hard nofile 655350
* soft nproc  655350
* hard nproc  655350
EOF

Kylin 默认开启 THP，会影响数据库场景性能。

echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
```

