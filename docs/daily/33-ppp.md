# PPP



## 一、Server

```bash
rpm -Uvh http://poptop.sourceforge.net/yum/stable/rhel6/pptp-release-current.noarch.rpm
加入yum源
2.yum install pptpd

3. yum install ppp
4.vi /etc/ppp/options.pptpd

1、配置文件编写
①、配置文件/etc/ppp/options.pptpd
mv /etc/ppp/options.pptpd /etc/ppp/options.pptpd.bak
vi /etc/ppp/options.pptpd
输入以下内容：
name pptpd
refuse-pap
refuse-chap
refuse-mschap
require-mschap-v2
require-mppe-128
proxyarp
lock
nobsdcomp
novj
novjccomp
nologfd
idle 2592000
ms-dns 8.8.8.8  //DNS可以不设置
ms-dns 8.8.4.4

---

②、配置文件/etc/ppp/chap-secrets
mv /etc/ppp/chap-secrets /etc/ppp/chap-secrets.bak
vi /etc/ppp/chap-secrets
输入以下内容

Secrets for authentication using CHAP

client         server   secret                   IP addresses

zhangjie pptpd ssxcEDfgd 10.0.0.250
vmcenter pptpd asdfdDSDF 10.0.0.251
wangyi   pptpd vpnOttpod 10.0.0.252
wangjian pptpd Dg3e20exq 10.0.0.253

  注：这里的myusername和mypassword即为PPTP VPN的登录用户名和密码

---

③、配置文件/etc/pptpd.conf
mv /etc/pptpd.conf /etc/pptpd.conf.bak
vi /etc/pptpd.conf
输入以下内容：
option /etc/ppp/options.pptpd
logwtmp
localip 117.135.151.114
remoteip 10.0.0.250-254
  注：为拨入VPN的用户动态分配192.168.1.250～192.168.1.252之间的IP

---

④、配置文件/etc/sysctl.conf
vi /etc/sysctl.conf
修改以下内容：
net.ipv4.ip_forward = 1

保存、退出后执行：
/sbin/sysctl -p

---

3、启动PPTP VPN 服务器端：
/sbin/service pptpd start

---

  4、启动iptables：//可设置也可不设置,如防火墙开启则一定要设置
/sbin/service iptables start
/sbin/iptables -t nat -A POSTROUTING -o eth0 -s 192.168.1.0/24 -j MASQUERADE



```

## 二、Client

```bash

1，安装pptp客户端
cd /usr/local/src

wget http://nchc.dl.sourceforge.net/sourceforge/pptpclient/pptp-1.7.1.tar.gz

wget http://superb-dca3.dl.sourceforge.net/project/pptpclient/pptp/pptp-1.8.0/pptp-1.8.0.tar.gz
tar xvzf pptp-1.7.1.tar.gz
cd pptp-1.7.1
make && make install

2，配置
vim /etc/ppp/peers/qtestin-21

remotename Tmonitor
linkname Tmonitor
ipparam Tmonitor
pty "pptp vpn.yw.qtestin.com --nolaunchpppd "
name Tmonitor
usepeerdns
require-mppe
refuse-eap
noauth

3，拨号
pppd call qtestin-21
route add -net 10.10.10.0 netmask 255.255.255.0 dev ppp0

route add -net 172.16.0.0/16 dev ppp0

pptp.sh
1.9 KB



4，测试
通过

vpn 服务器

iptables -t nat -A  POSTROUTING -s 10.10.10.0/24 -o eth1 -j MASQUERADE
iptables -t nat -A  POSTROUTING -s 10.10.10.0/24 -o ppp0 -j MASQUERADE

windows client
route delete 10.0.0.0
route add 10.0.0.0/8 10.10.10.10

QTestin-david ==> qtestin-15（能出不能进，跟公司的防火墙有关）
A43S-david ==>qtestin-16
beijing_tele_118.244.134.34     ==> qtestin-17
chongqing_tele_219.153.64.211 ==> qtestin-18



如果你需要在Linux中拨入虚拟网络中，那就需要安装Linux下相应VPN的客户端，本文将介绍以pptp方式拨入虚拟网络的VPN的方法。
　　以下操作均在root用户下操作完成，并假设你的Linux系统已经安装了编译环境。
　　１、下载pptp客户端
　　wget http://nchc.dl.sourceforge.net/sourceforge/pptpclient/pptp-1.7.1.tar.gz
　　2、解压
　　tar zxvf pptp-1.7.1.tar.gz
　　3、编译和安装
　　make; make install
　　4、编辑配置文件，设定拨号名为mypptp
　　vim /etc/ppp/peers/mypptp
　　内容如下：

 

remotename Tmonitor
linkname Tmonitor
ipparam Tmonitor
pty "pptp 61.147.88.113 --nolaunchpppd "
name Tmonitor
usepeerdns
require-mppe
refuse-eap
noauth

      其中，myaccount为用户名

　　5、编辑/etc/ppp/chap-secrets，加入用户名和帐号，这里假设myaccount的密码为mypassword
     myaccount * mypassword *
　　6、拨号，运行以下命令
     /usr/sbin/pppd call mypptp logfd 1 updetach
　　如果以上配置文件正确无误，则可正常拨入虚拟网管的pptp VPN网络中了，此时如果用ifconfig查看连接情况，可以看到多了一条ppp连接，并能正确分到IP地址了。
　　７、添加路由
　　虽然已经拨号上来了，但此时，如果你要访问你的虚拟局域网资源，你必需添加一条路由才行，这里假设你拨号上来的连接名为ppp0，并此你的虚拟局域网的IP段为192.168.163.0，那么，你需要加入以下命令： 
     route add -net 192.168.163.0 netmask 255.255.255.0 dev ppp0
　 至此，在Linux系统下以pptp方式拨入虚拟网络的VPN网络中了。
     PS：如果在拨号时报以下错误：
     /usr/sbin/pppd:pty option precludes specifying device name
     请检查pppd的版本，不可低于2.3.7。
     检查/etc/ppp/optoins文件，该文件不能为空。

```



## 三、脚本

`pptpd.sh`

```bash
yum remove -y pptpd ppp
iptables --flush POSTROUTING --table nat
iptables --flush FORWARD
rm -rf /etc/pptpd.conf
rm -rf /etc/ppp

arch=`uname -m`
wget http://www.vr.org/files/pptpd-1.4.0-1.el6.$arch.rpm

yum -y install make libpcap iptables gcc-c++ logrotate tar cpio perl pam tcp_wrappers dkms kernel_ppp_mppe ppp
rpm -Uvh pptpd-1.4.0-1.el6.$arch.rpm


mknod /dev/ppp c 108 0 
echo 1 > /proc/sys/net/ipv4/ip_forward 
cat /etc/rc.local > /etc/rc.local2
echo "mknod /dev/ppp c 108 0" > /etc/rc.local
echo "echo 1 > /proc/sys/net/ipv4/ip_forward" >> /etc/rc.local
echo "localip 172.16.36.1" >> /etc/pptpd.conf
echo "remoteip 172.16.36.2-254" >> /etc/pptpd.conf
echo "ms-dns 8.8.8.8" >> /etc/ppp/options.pptpd
echo "ms-dns 8.8.4.4" >> /etc/ppp/options.pptpd
cat /etc/rc.local2 >> /etc/rc.local

pass=`openssl rand 6 -base64`
if [ "$1" != "" ]
then pass=$1
fi

echo "vpn pptpd ${pass} *" >> /etc/ppp/chap-secrets

iptables -F
iptables -t nat -A POSTROUTING -s 172.16.36.0/24 -j SNAT --to-source `ifconfig  | grep 'inet addr:'| grep -v '127.0.0.1' | cut -d: -f2 | awk 'NR==1 { print $1}'`
iptables -A FORWARD -p tcp --syn -s 172.16.36.0/24 -j TCPMSS --set-mss 1356
service iptables save

chkconfig iptables on
chkconfig pptpd on

service iptables start
service pptpd start

echo "VPN service is installed, your VPN username is vpn, VPN password is ${pass}"

```

