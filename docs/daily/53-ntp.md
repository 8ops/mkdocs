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
server ntp.aliyun.com iburst
stratumweight 0
driftfile /var/lib/chrony/drift
rtcsync
makestep 10 3
bindcmdaddress 127.0.0.1
bindcmdaddress ::1
keyfile /etc/chrony.keys
commandkey 1
generatecommandkey
logchange 0.5
logdir /var/log/chrony
```



```bash
# op
systemctl start chronyd
systemctl status chronyd
```

