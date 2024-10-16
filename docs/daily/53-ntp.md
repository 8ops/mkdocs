# ntp

NTP 是网络时间协议 (Network Time Protocol)，它是用来同步网络中各个计算机的时间的协议。

## ntpd

Linux 服务器上快速配置阿里巴巴 OPSX NTP服务

编辑文件 `/etc/ntp.conf`，根据情况修改文件内容为：

- 互联网上的服务器:

```bash
driftfile  /var/lib/ntp/drift
pidfile   /var/run/ntpd.pid
logfile /var/log/ntp.log
restrict    default kod nomodify notrap nopeer noquery
restrict -6 default kod nomodify notrap nopeer noquery
restrict 127.0.0.1
server 127.127.1.0
fudge  127.127.1.0 stratum 10
server ntp.aliyun.com iburst minpoll 4 maxpoll 10
restrict ntp.aliyun.com nomodify notrap nopeer noquery
```

- 阿里云 ECS 服务器:

```bash
driftfile  /var/lib/ntp/drift
pidfile   /var/run/ntpd.pid
logfile /var/log/ntp.log
restrict    default kod nomodify notrap nopeer noquery
restrict -6 default kod nomodify notrap nopeer noquery
restrict 127.0.0.1
server 127.127.1.0
fudge  127.127.1.0 stratum 10
server ntp.aliyun.com iburst minpoll 4 maxpoll 10
restrict ntp.aliyun.com nomodify notrap nopeer noquery

server ntp1.cloud.aliyuncs.com iburst minpoll 4 maxpoll 10
restrict ntp1.cloud.aliyuncs.com nomodify notrap nopeer noquery
server ntp2.cloud.aliyuncs.com iburst minpoll 4 maxpoll 10
restrict ntp2.cloud.aliyuncs.com nomodify notrap nopeer noquery
server ntp3.cloud.aliyuncs.com iburst minpoll 4 maxpoll 10
restrict ntp3.cloud.aliyuncs.com nomodify notrap nopeer noquery
server ntp4.cloud.aliyuncs.com iburst minpoll 4 maxpoll 10
restrict ntp4.cloud.aliyuncs.com nomodify notrap nopeer noquery
server ntp5.cloud.aliyuncs.com iburst minpoll 4 maxpoll 10
restrict ntp5.cloud.aliyuncs.com nomodify notrap nopeer noquery
server ntp6.cloud.aliyuncs.com iburst minpoll 4 maxpoll 10
restrict ntp6.cloud.aliyuncs.com nomodify notrap nopeer noquery
```



```bash
# op
systemctl start ntpd
systemctl status ntpd
```





## chronyd

对于使用 chrony 客户端的 linux 主机

配置 `/etc/chrony.conf` 文件的内容为：

```bash
# Use public servers from the pool.ntp.org project.
# Please consider joining the pool (http://www.pool.ntp.org/join.html).
server ntp.aliyun.com iburst minpoll 10 maxpoll 17
server ntp.tencent.com iburst
server ntp.ntsc.ac.cn iburst

## OR
# iburst：如果无法与NTP服务器建立连接，启用加速尝试，缩短初始同步时间。(1分钟一次)
# maxpoll：指定时间同步请求之间的最大间隔，默认值为10（表示2^10秒，约1024秒）（可选4-17）。
# minpoll：最小时间间隔，默认值是 6，表示 2^6 秒（64秒）。
# maxpoll：最大时间间隔，默认值是 10，表示 2^10 秒（1024秒）。

# Record the rate at which the system clock gains/losses time.
driftfile /var/lib/chrony/drift

# Allow the system clock to be stepped in the first three updates
# if its offset is larger than 1 second.
makestep 1.0 3

# Enable kernel synchronization of the real-time clock (RTC).
rtcsync

# Enable hardware timestamping on all interfaces that support it.
#hwtimestamp *

# Increase the minimum number of selectable sources required to adjust
# the system clock.
#minsources 2

# Allow NTP client access from local network.
allow all

# Serve time even if not synchronized to a time source.
#local stratum 10

# Specify file containing keys for NTP authentication.
#keyfile /etc/chrony.keys

# Specify directory for log files.
logdir /var/log/chrony

# Select which information is logged.
#log measurements statistics tracking
```



```bash
# restart
systemctl restart chronyd
systemctl status chronyd

# detect server
chronyc sources -v
chronyc sourcestats -v
chronyc tracking
chronyc -a makestep # 手动触发同步
chronyc activity

chronyc serverstats
chronyc accheck 10.101.9.179
chronyc -n clients

# detect client
chronyc sources -v
chronyc sourcestats -v
chronyc tracking
chronyc -a makestep # 手动触发同步
chronyc activity

```

## systemd-timesyncd

```bash
# /etc/systemd/timesyncd.conf

[Time]
NTP=ntp.8ops.top
#FallbackNTP=ntp.ubuntu.com
#RootDistanceMaxSec=5
#PollIntervalMinSec=32
#PollIntervalMaxSec=2048
```



```bash
# 操作集锦
systemctl status systemd-timesyncd

timedatectl status
timedatectl timesync-status
```

