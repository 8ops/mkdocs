# 硬件管理

## 一、sensors

物理机传感器

### 1.1 安装

```bash
# support x86_64
getconf LONG_BIT

# ubuntu 
apt install lm-sensors

# centos
yum install lm_sensors
```



### 1.2 分析

```bash
sensors -v

sensors

# sample
tg3-pci-0201
Adapter: PCI adapter
temp1:        +52.0°C  (high = +100.0°C, crit = +110.0°C)

coretemp-isa-0001
Adapter: ISA adapter
Package id 1:  +55.0°C  (high = +80.0°C, crit = +90.0°C)
Core 0:        +47.0°C  (high = +80.0°C, crit = +90.0°C)
Core 1:        +47.0°C  (high = +80.0°C, crit = +90.0°C)
Core 2:        +47.0°C  (high = +80.0°C, crit = +90.0°C)
Core 3:        +47.0°C  (high = +80.0°C, crit = +90.0°C)
Core 4:        +47.0°C  (high = +80.0°C, crit = +90.0°C)
Core 5:        +46.0°C  (high = +80.0°C, crit = +90.0°C)
Core 6:        +48.0°C  (high = +80.0°C, crit = +90.0°C)
Core 7:        +47.0°C  (high = +80.0°C, crit = +90.0°C)

power_meter-acpi-0
Adapter: ACPI interface
power1:        0.00 W  (interval = 300.00 s)

tg3-pci-0203
Adapter: PCI adapter
temp1:        +52.0°C  (high = +100.0°C, crit = +110.0°C)

tg3-pci-0200
Adapter: PCI adapter
temp1:        +52.0°C  (high = +100.0°C, crit = +110.0°C)

coretemp-isa-0000
Adapter: ISA adapter
Package id 0:  +47.0°C  (high = +80.0°C, crit = +90.0°C)
Core 0:        +40.0°C  (high = +80.0°C, crit = +90.0°C)
Core 1:        +40.0°C  (high = +80.0°C, crit = +90.0°C)
Core 2:        +41.0°C  (high = +80.0°C, crit = +90.0°C)
Core 3:        +39.0°C  (high = +80.0°C, crit = +90.0°C)
Core 4:        +40.0°C  (high = +80.0°C, crit = +90.0°C)
Core 5:        +41.0°C  (high = +80.0°C, crit = +90.0°C)
Core 6:        +40.0°C  (high = +80.0°C, crit = +90.0°C)
Core 7:        +41.0°C  (high = +80.0°C, crit = +90.0°C)

# 原始温度存储位置
cat /sys/class/hwmon/hwmon1/temp1_input
56000

# vm 会因为没有sensors而报错

```



## 二、IPMI

```bash
一、开关机，重启

1. 查看开关机状态：
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) power status

2. 开机：
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) power on

3. 关机：
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) power off

4. 重启：
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) power reset

二、用户管理
说明：[ChannelNo] 字段是可选的，ChannoNo为1或者8；BMC默认有2个用户：user id为1的匿名用户，user id为2的ADMIN用户；<>字段为必选内容；<privilege level>：2为user权限，3为Operator权限，4为Administrator权限；

1. 查看用户信息：
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) user list [ChannelNo]

2. 增加用户：
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) user set name <user id> <username>

3. 设置密码：
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) user set password <user id> <password>

4. 设置用户权限：
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) user priv <user id> <privilege level> [ChannelNo]

5. 启用/禁用用户：
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) user enable/disable <user id>

三、IP网络设置
说明：[ChannelNo] 字段是可选的，ChannoNo为1(Share Nic网络)或者8（BMC独立管理网络）；设置网络参数，必须首先设置IP为静态，然后再进行其他设置；

1. 查看网络信息：
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) lan print [ChannelNo]

2. 修改IP为静态还是DHCP模式：
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) lan set <ChannelNo> ipsrc <static/dhcp>

3. 修改IP地址：
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) lan set <ChannelNo> ipaddr <IPAddress>

4. 修改子网掩码：
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) lan set <ChannelNo> netmask <NetMask>

5. 修改默认网关：
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) lan set <ChannelNo> defgw ipaddr <默认网关>

四、SOL功能
说明：<9.6/19.2/38.4/57.6/115.2>其中115.2代表115200，即*1000是表示的波特率。

1. 设置SOL串口波特率：
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) sol set volatile-bit-rate <9.6/19.2/38.4/57.6/115.2>

2. 打开SOL功能：
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) sol activate

3. 关闭SOL功能：
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) sol deactivate

五、SEL日志查看

1. 查看SEL日志：
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) sel list

六、FRU信息查看

1. 查看FRU信息：
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) fru list

七、SDR，Sensor信息查看

1. 查看SDR Sensor信息：
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) sdr

2. 查看Sensor信息：
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) sensor list

八、mc(管理单元BMC)状态和控制

1. 重启动BMC：
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) mc reset <warm/cold>

九、设置BMC的iptables防火墙

1. 设置某一段IP可以访问BMC
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) raw 0x32 0x76 0x01 0x01 ip1(0xa 0xa 0xa 0xa) ip2(0xb 0xb 0xb 0xb)
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) raw 0x32 0x76 0x09

2. 设置某个IP可以访问BMC
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) raw 0x32 0x76 0x00 0x01 ip1(0xa 0xa 0xa 0xa)
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) raw 0x32 0x76 0x09

3. 取消设置
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) raw 0x32 0x76 0x08

4．获取防火墙设置
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) raw 0x32 0x77 0x01 0x00

5. 阻止/开启某个端口
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) raw 0x32 0x76 0x02 0x00/0x01 0x00 (portno)0x22 0x00

6. 取消某个端口的设置（6是5的对应取消操作）
ipmitool -H (BMC的管理IP地址) -I lanplus -U (BMC登录用户名) -P (BMC 登录用户名的密码) raw 0x32 0x76 0x06 0x00/0x01 0x00 (portno)0x22 0x00
```

