# 网络信息



## 一、IP库

| 名称     | 地址                     |
| -------- | ------------------------ |
| ip       | <https://ip.cn/>         |
| taobao   | <http://ip.taobao.com/>  |
| 123cha   | <http://www.123cha.com/> |
| ipip     | <https://www.ipip.net/>  |
| 纯真cz88 | <http://www.cz88.net/>   |
| ip138    | <http://www.ip138.com/>  |



## 二、Proxy

### 2.1 goproxy

[Reference](https://github.com/snail007/goproxy)



### 2.2 frp

代理方式丰富，支持http、sockes等等。

```bash
# 使用效果一览
curl --proxy "http://abc:abc@u.8ops.top:56001"   "https://ip.8ops.top"
curl --proxy "socks5://abc:abc@u.8ops.top:56005" "https://ip.8ops.top"
```



[Reference](https://github.com/fatedier/frp)

<u>Download</u>

```bash
cd /usr/local
FRP_VERSION=0.51.1
wget  https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz
tar xzf frp_${FRP_VERSION}_linux_amd64.tar.gz 
ln -s frp_${FRP_VERSION}_linux_amd64 frp
```



<u>Server</u>

```bash
# config frps.ini
dashboard_user = admin
dashboard_pwd = 
token = 
allow_ports = 50000-51000,56000-57000
subdomain_host = 8ops.top

# vhost_http_port = 80
# vhost_https_port = 443

#[plugin.user-manager]
#addr = 127.0.0.1:9000
#path = /handler
#ops = Login
#
#[plugin.port-manager]
#addr = 127.0.0.1:9001
#path = /handler
#ops = NewProxy

# service
cat > /usr/lib/systemd/system/frps.service <<EOF
[Unit]
Description=Frp Server Service
After=network.target

[Service]
Type=simple
WorkingDirectory=/usr/local/frp
User=nobody
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/frp/frps -c /usr/local/frp/frps.ini

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start frps
systemctl enable frps
systemctl is-enabled frps
systemctl status frps
```



<u>Client</u>

```bash
# service
cat > /usr/lib/systemd/system/frpc.service <<EOF
[Unit]
Description=Frp Client Service
After=network.target

[Service]
Type=simple
WorkingDirectory=/usr/local/frp
User=nobody
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/frp/frpc tcp -n demo -t token -p tcp -s frps.8ops.top:7000 -r 56666 -i 127.0.0.1 -l 12622

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start frpc
systemctl enable frpc
systemctl is-enabled frpc
systemctl status frpc

```



## 三、hosts

修改hosts后释放dns污染：

### 3.1 Windows

```
开始 -> 运行 -> 输入cmd -> 在CMD窗口输入
ipconfig /flushdns
```

### 3.2 Linux

终端输入

```
sudo rcnscd restart
```

对于systemd发行版，请使用命令

```
sudo systemctl restart NetworkManager
```

如果不懂请都尝试下

### 3.3 MAC

Mac OSX 终端输入

```
sudo killall -HUP mDNSResponder
```

### 3.4 Android

```
开启飞行模式 -> 关闭飞行模式
```

通用方法

```
拔网线(断网) -> 插网线(重新连接网络)
```



## 四、常用DNS

### 4.1 公共

| 名称                  | 地址一          | 地址二          |
| --------------------- | --------------- | --------------- |
| 114 DNS               | 114.114.114.114 | 114.114.115.115 |
| 阿里 AliDNS           | 223.5.5.5       | 223.6.6.6       |
| 百度 BaiduDNS         | 180.76.76.76    |                 |
| DNSPod DNS+           | 119.29.29.29    | 182.254.116.116 |
| CNNIC SDNS            | 1.2.4.8         | 210.2.4.8       |
| oneDNS                | 117.50.11.11    | 52.80.66.66     |
| DNS 派 电信/移动/铁通 | 101.226.4.6     | 218.30.118.6    |
| DNS 派 联通           | 123.125.81.6    | 140.207.198.6   |
| Google DNS            | 8.8.8.8         | 8.8.4.4         |
| IBM Quad9             | 9.9.9.9         |                 |
| OpenDNS               | 208.67.222.222  | 208.67.220.220  |
| V2EX DNS              | 199.91.73.222   | 178.79.131.110  |

### 4.2 各地电信

| 名称          | 地址一          | 地址二          |
| ------------- | --------------- | --------------- |
| 安徽电信 DNS  | 61.132.163.68   | 202.102.213.68  |
| 北京电信 DNS  | 219.141.136.10  | 219.141.140.10  |
| 重庆电信 DNS  | 61.128.192.68   | 61.128.128.68   |
| 福建电信 DNS  | 218.85.152.99   | 218.85.157.99   |
| 甘肃电信 DNS  | 202.100.64.68   | 61.178.0.93     |
| 广东电信 DNS  | 202.96.128.86   | 202.96.128.166  |
| 202.96.134.33 | 202.96.128.68   |                 |
| 广西电信 DNS  | 202.103.225.68  | 202.103.224.68  |
| 贵州电信 DNS  | 202.98.192.67   | 202.98.198.167  |
| 河南电信 DNS  | 222.88.88.88    | 222.85.85.85    |
| 黑龙江电信    | 219.147.198.230 | 219.147.198.242 |
| 湖北电信 DNS  | 202.103.24.68   | 202.103.0.68    |
| 湖南电信 DNS  | 222.246.129.80  | 59.51.78.211    |
| 江苏电信 DNS  | 218.2.2.2       | 218.4.4.4       |
| 61.147.37.1   | 218.2.135.1     |                 |
| 江西电信 DNS  | 202.101.224.69  | 202.101.226.68  |
| 内蒙古电信    | 219.148.162.31  | 222.74.39.50    |
| 山东电信 DNS  | 219.146.1.66    | 219.147.1.66    |
| 陕西电信 DNS  | 218.30.19.40    | 61.134.1.4      |
| 上海电信 DNS  | 202.96.209.133  | 116.228.111.118 |
| 202.96.209.5  | 108.168.255.118 |                 |
| 四川电信 DNS  | 61.139.2.69     | 218.6.200.139   |
| 天津电信 DNS  | 219.150.32.132  | 219.146.0.132   |
| 云南电信 DNS  | 222.172.200.68  | 61.166.150.123  |
| 浙江电信 DNS  | 202.101.172.35  | 61.153.177.196  |
| 61.153.81.75  | 60.191.244.5    |                 |

### 4.3 各地联通

| 名称           | 地址一          | 地址二          |
| -------------- | --------------- | --------------- |
| 北京联通 DNS   | 123.123.123.123 | 123.123.123.124 |
| 202.106.0.20   | 202.106.195.68  |                 |
| 重庆联通 DNS   | 221.5.203.98    | 221.7.92.98     |
| 广东联通 DNS   | 210.21.196.6    | 221.5.88.88     |
| 河北联通 DNS   | 202.99.160.68   | 202.99.166.4    |
| 河南联通 DNS   | 202.102.224.68  | 202.102.227.68  |
| 黑龙江联通     | 202.97.224.69   | 202.97.224.68   |
| 吉林联通 DNS   | 202.98.0.68     | 202.98.5.68     |
| 江苏联通 DNS   | 221.6.4.66      | 221.6.4.67      |
| 内蒙古联通     | 202.99.224.68   | 202.99.224.8    |
| 山东联通 DNS   | 202.102.128.68  | 202.102.152.3   |
| 202.102.134.68 | 202.102.154.3   |                 |
| 山西联通 DNS   | 202.99.192.66   | 202.99.192.68   |
| 陕西联通 DNS   | 221.11.1.67     | 221.11.1.68     |
| 上海联通 DNS   | 210.22.70.3     | 210.22.84.3     |
| 四川联通 DNS   | 119.6.6.6       | 124.161.87.155  |
| 天津联通 DNS   | 202.99.104.68   | 202.99.96.68    |
| 浙江联通 DNS   | 221.12.1.227    | 221.12.33.227   |
| 辽宁联通 DNS   | 202.96.69.38    | 202.96.64.68    |

### 4.4 各地移动

| 名称         | 地址一         | 地址二         |
| ------------ | -------------- | -------------- |
| 江苏移动 DNS | 221.131.143.69 | 112.4.0.55     |
| 安徽移动 DNS | 211.138.180.2  | 211.138.180.3  |
| 山东移动 DNS | 218.201.96.130 | 211.137.191.26 |

## 五 网卡配置

网络配置工具

**ip命令** 用来显示或操纵Linux主机的路由、网络设备、策略路由和隧道，是Linux下较新的功能强大的网络配置工具。

> 语法

```shell
ip(选项)(对象)
Usage: ip [ OPTIONS ] OBJECT { COMMAND | help }
       ip [ -force ] -batch filename
```

### 5.1 对象

```shell
OBJECT := { link | address | addrlabel | route | rule | neigh | ntable |
       tunnel | tuntap | maddress | mroute | mrule | monitor | xfrm |
       netns | l2tp | macsec | tcp_metrics | token }
       
-V：显示指令版本信息；
-s：输出更详细的信息；
-f：强制使用指定的协议族；
-4：指定使用的网络层协议是IPv4协议；
-6：指定使用的网络层协议是IPv6协议；
-0：输出信息每条记录输出一行，即使内容较多也不换行显示；
-r：显示主机时，不使用IP地址，而使用主机的域名。
```

### 5.2 选项

```shell
OPTIONS := { -V[ersion] | -s[tatistics] | -d[etails] | -r[esolve] |
        -h[uman-readable] | -iec |
        -f[amily] { inet | inet6 | ipx | dnet | bridge | link } |
        -4 | -6 | -I | -D | -B | -0 |
        -l[oops] { maximum-addr-flush-attempts } |
        -o[neline] | -t[imestamp] | -ts[hort] | -b[atch] [filename] |
        -rc[vbuf] [size] | -n[etns] name | -a[ll] }
        
网络对象：指定要管理的网络对象；
具体操作：对指定的网络对象完成具体操作；
help：显示网络对象支持的操作命令的帮助信息。
```

### 5.3 实例

```shell
ip link show                    # 显示网络接口信息
ip link set eth0 up             # 开启网卡
ip link set eth0 down            # 关闭网卡
ip link set eth0 promisc on      # 开启网卡的混合模式
ip link set eth0 promisc offi    # 关闭网卡的混合模式
ip link set eth0 txqueuelen 1200 # 设置网卡队列长度
ip link set eth0 mtu 1400        # 设置网卡最大传输单元
ip addr show     # 显示网卡IP信息
ip addr add 192.168.0.1/24 dev eth0 # 为eth0网卡添加一个新的IP地址192.168.0.1
ip addr del 192.168.0.1/24 dev eth0 # 为eth0网卡删除一个IP地址192.168.0.1

ip route show # 显示系统路由
ip route add default via 192.168.1.254   # 设置系统默认路由
ip route list                 # 查看路由信息
ip route add 192.168.4.0/24  via  192.168.0.254 dev eth0 # 设置192.168.4.0网段的网关为192.168.0.254,数据走eth0接口
ip route add default via  192.168.0.254  dev eth0        # 设置默认网关为192.168.0.254
ip route del 192.168.4.0/24   # 删除192.168.4.0网段的网关
ip route del default          # 删除默认路由
ip route delete 192.168.1.0/24 dev eth0 # 删除路由
```

**用ip命令显示网络设备的运行状态**

```shell
[root@localhost ~]# ip link list
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 16436 qdisc noqueue
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast qlen 1000
    link/ether 00:16:3e:00:1e:51 brd ff:ff:ff:ff:ff:ff
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast qlen 1000
    link/ether 00:16:3e:00:1e:52 brd ff:ff:ff:ff:ff:ff
```

**显示更加详细的设备信息**

```shell
[root@localhost ~]# ip -s link list
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 16436 qdisc noqueue
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    RX: bytes  packets  errors  dropped overrun mcast   
    5082831    56145    0       0       0       0      
    TX: bytes  packets  errors  dropped carrier collsns
    5082831    56145    0       0       0       0      
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast qlen 1000
    link/ether 00:16:3e:00:1e:51 brd ff:ff:ff:ff:ff:ff
    RX: bytes  packets  errors  dropped overrun mcast   
    3641655380 62027099 0       0       0       0      
    TX: bytes  packets  errors  dropped carrier collsns
    6155236    89160    0       0       0       0      
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast qlen 1000
    link/ether 00:16:3e:00:1e:52 brd ff:ff:ff:ff:ff:ff
    RX: bytes  packets  errors  dropped overrun mcast   
    2562136822 488237847 0       0       0       0      
    TX: bytes  packets  errors  dropped carrier collsns
    3486617396 9691081  0       0       0       0     
```

**显示核心路由表**

```shell
[root@localhost ~]# ip route list 
112.124.12.0/22 dev eth1  proto kernel  scope link  src 112.124.15.130
10.160.0.0/20 dev eth0  proto kernel  scope link  src 10.160.7.81
192.168.0.0/16 via 10.160.15.247 dev eth0
172.16.0.0/12 via 10.160.15.247 dev eth0
10.0.0.0/8 via 10.160.15.247 dev eth0
default via 112.124.15.247 dev eth1
```

**显示邻居表**

```shell
[root@localhost ~]# ip neigh list
112.124.15.247 dev eth1 lladdr 00:00:0c:9f:f3:88 REACHABLE
10.160.15.247 dev eth0 lladdr 00:00:0c:9f:f2:c0 STALE
```

**获取主机所有网络接口**

```shell
ip link | grep -E '^[0-9]' | awk -F: '{print $2}'
```
