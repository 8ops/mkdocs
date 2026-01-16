# kickstart

## iPXE

### netboot

适用ubuntu22.04。以下测试24.04.3的示例。

```bash
.
├── boot.ipxe
├── netboot
│   ├── bootx64.efi
│   ├── grub
│   │   └── grub.cfg
│   ├── grubx64.efi
│   ├── initrd
│   ├── ldlinux.c32
│   ├── linux
│   ├── pxelinux.0
│   └── pxelinux.cfg
│       └── default
└── preseed
    └── preseed.cfg

4 directories, 10 files
```



```bash
# 1，down netboot
https://releases.ubuntu.com/noble/ubuntu-24.04.3-netboot-amd64.tar.gz
tar xzf ubuntu-24.04.3-netboot-amd64.tar.gz
mv amd netboot

# 2，配置引导启动
cat > boot.ipxe <<EOF
#!ipxe
dhcp

kernel http://10.101.11.236/netboot/linux \
  auto=true \
  priority=critical \
  preseed/url=http://10.101.11.236/preseed/preseed.cfg \
  locale=en_US.UTF-8 \
  keyboard-configuration/layoutcode=us \
  netcfg/choose_interface=auto ---

initrd http://10.101.11.236/netboot/initrd.gz
boot
EOF

# 缺少 initrd.gz，无法继续（TODO）

# 3，d-i 配置
cat > preseed/preseed.cfg <<EOF
### 基本模式：完全无人值守
d-i auto-install/enable boolean true
d-i debconf/priority string critical
d-i pkgsel/run_tasksel boolean false

### 语言 / 区域
d-i debian-installer/locale string en_US.UTF-8
d-i console-setup/ask_detect boolean false
d-i keyboard-configuration/layoutcode string us

### 网络（DHCP）
d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string ubuntu
d-i netcfg/get_domain string localdomain
d-i netcfg/disable_autoconfig boolean false

### 时区
d-i time/zone string Asia/Shanghai
d-i clock-setup/utc boolean true
d-i clock-setup/ntp boolean true

### 磁盘（整盘自动分区，LVM）
d-i partman-auto/method string lvm
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-md/device_remove_md boolean true
d-i partman-auto/choose_recipe select atomic
d-i partman-auto/confirm boolean true
d-i partman-auto/confirm_nooverwrite boolean true

### 用户账户
d-i passwd/root-login boolean false
d-i passwd/user-fullname string ubuntu
d-i passwd/username string ubuntu
d-i passwd/user-password password ubuntu
d-i passwd/user-password-again password ubuntu
d-i user-setup/allow-password-weak boolean true

### 最小化安装 + openssh
d-i pkgsel/include string openssh-server
d-i pkgsel/install-language-support boolean false
d-i pkgsel/update-policy select none

### GRUB
d-i grub-installer/only_debian boolean true
d-i grub-installer/with_other_os boolean true
d-i grub-installer/bootdev string default

### 完成安装后自动重启
d-i finish-install/reboot_in_progress note
EOF
```



### autoinstall

适用24.04。

```bash
.
├── autoinstall
│   ├── meta-data
│   ├── user-data
│   └── vendor-data
├── boot.ipxe
└── ubuntu
    └── 24.04
        ├── filesystem.squashfs
        ├── initrd
        ├── ubuntu-24.04.3-live-server-amd64.iso
        └── vmlinuz

3 directories, 8 files
```



```bash
# Ubuntu 24.04.x 不再支持传统 debian-installer，正确方式是（基于iPXE）
DHCP
 ├─ 提供 next-server / filename
TFTP
 ├─ GRUB EFI / PXELINUX
HTTP
 ├─ vmlinuz
 ├─ initrd
 ├─ autoinstall.yaml

# 1，down
wget https://releases.ubuntu.com/24.04/ubuntu-24.04.3-live-server-amd64.iso

# 2，挂载并提取内核
mkdir /mnt/iso
mount ubuntu-24.04.3-live-server-amd64.iso /mnt/iso

mkdir -p /var/www/html/ubuntu/24.04/casper
cp /mnt/iso/casper/vmlinuz /var/www/html/ubuntu/24.04/casper/
cp /mnt/iso/casper/initrd /var/www/html/ubuntu/24.04/casper/
cp /mnt/iso/casper/ubuntu-server-minimal.ubuntu-server.installer.squashfs /var/www/html/ubuntu/24.04/casper/

# 3，TFTP + GRUB（UEFI 推荐）
apt install -q -y dnsmasq grub-efi-amd64-bin
mkdir -p /srv/tftp/grub
cp /usr/lib/grub/x86_64-efi/monolithic/grubnetx64.efi /srv/tftp/

cat > /srv/tftp/grub/grub.cfg<<EOF
set timeout=5
set default=0

menuentry "Install Ubuntu 24.04.3 (Auto PXE)" {
    set gfxpayload=keep
    linuxefi http://10.101.11.236/ubuntu/24.04/vmlinuz \
      ip=dhcp \
      url=http://10.101.11.236/ubuntu/24.04/ubuntu-24.04.3-live-server-amd64.iso \
      autoinstall \
      ds=nocloud-net;s=http://10.101.11.236/autoinstall/ ---
    initrdefi http://10.101.11.236/ubuntu/24.04/initrd
}
EOF

cat > /etc/dnsmasq.d/pxe.conf<<EOF
port=0
interface=eth0
bind-interfaces

dhcp-range=10.101.11.62,10.101.11.66,12h
dhcp-option=3,10.101.11.254
dhcp-option=6,10.101.11.254

enable-tftp
tftp-root=/srv/tftp

# # UEFI PXE
# dhcp-match=set:efi64,option:client-arch,7
# dhcp-boot=tag:efi64,grubnetx64.efi

# iPXE
dhcp-match=set:ipxe,175
dhcp-boot=tag:ipxe,http://10.101.11.236/boot.ipxe
dhcp-boot=pxelinux.0
EOF

systemctl restart dnsmasq

# 4，autoinstall
mkdir -p /var/www/html/autoinstall
touch autoinstall/vendor-data

cat > autoinstall/meta-data<EOF
instance-id: ubuntu24043
local-hostname: ubuntu24043
EOF

cat > autoinstall/user-data<<EOF
# cloud-config
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard:
    layout: us

  identity:
    hostname: ubuntu24043
    username: ubuntu
    password: "$6$P3.moH7U5xwiNCwx$1ABidxOu5dz9agI/zoZ.Y4Kt.t.r/nr501ZwN4zfAKevGs7GHLCqXOhu.hU0hALEXJxJhgyplSAL0doQx03Ul0"

  ssh:
    install-server: true
    allow-pw: true

  storage:
    layout:
      name: direct

  packages:
    - openssh-server
    - vim
    - curl
    - net-tools

  late-commands:
    - curtin in-target -- systemctl enable ssh
EOF

openssl passwd -6 
ubuntu # sha256 加密

cat > boot.ipxe<<EOF
#!ipxe
dhcp

set base http://10.101.11.236/ubuntu/24.04

kernel ${base}/vmlinuz \
  ip=dhcp \
  boot=casper \
  live-media-path=casper \
  fetch=${base}/filesystem.squashfs \
  autoinstall \
  ds=nocloud-net;s=http://10.101.11.236/autoinstall/ \
  rootfs-size=8192M \
  fsck.mode=skip ---

initrd ${base}/initrd
boot
EOF

# 5，HTTP服务
apt install -y nginx
systemctl enable --now nginx

cat > /etc/nginx/conf.d/pxe.conf <<EOF
server {
    listen 80;
    location / {
        root /var/www/html;
        autoindex on;
    }
}
EOF
nginx -t
systemctl restart nginx

```







## PXE

基于CentOS操作系统部署DHCP服务器（比较过时的操作参考）。

用于安装CentOS6.4 x86_64的操作系统。

使用kickstart的方式安装。

### kickstart

```bash
# 1，依赖库安装 
yum install -q -y dhcp dhcp-devel dhcp-common nginx tftp-server xinetd syslinux rsync vim 

# 2，FTP配置
vim /etc/xinetd.d/tftp
service tftp
{
        socket_type             = dgram
        protocol                = udp
        wait                    = yes
        user                    = root
        server                  = /usr/sbin/in.tftpd
        server_args             = -s /data/tftp
        disable                 = no
        per_source              = 11
        cps                     = 100 2
        flags                   = IPv4
}

# 3，Nginx配置
vim /etc/nginx/nginx.conf
    server{
        listen 80;
        root /data/iso/pxe;
        autoindex on;
    }

# 4，DHCP配置
vim /etc/dhcp/dhcpd.conf
ddns-update-style interim;
ignore client-updates;

subnet 192.168.100.0 netmask 255.255.255.0 {
    option routers 192.168.100.1;
    option subnet-mask 255.255.255.0;
    option domain-name-servers 192.168.100.1;

    range dynamic-bootp 192.168.100.200 192.168.100.250;
    default-lease-time 21600;
    max-lease-time 43200;
    next-server 192.168.100.31;
    filename "pxelinux.0";

}

# 5，光盘挂载，镜像拷贝
# 挂载 CentOS-6.4-x86_64-minimal.iso 
mkdir -p /data/cdrom /data/iso/pxe /data/tftp/pxelinux.cfg/
mount -o loop /dev/cdrom /data/cdrom
rsync -av /data/cdrom/ /data/iso/pxe/
cp /usr/share/syslinux/pxelinux.0 /data/tftp/
cp /data/iso/pxe/isolinux/isolinux.cfg /data/tftp/pxelinux.cfg/default
cp /data/iso/pxe/isolinux/* /data/tftp/

# 6，配置 pxe

TT=(date +%Y%m%d.%H%M%S)
for i in {1..100};do
    echo "-------- Author: jesse. for CentOS 6.4 x86_64 V{TT} by PXE  --------"
done > /data/iso/pxe/isolinux/boot.msg
cp /data/iso/pxe/isolinux/boot.msg /data/tftp/boot.msg

chmod +w /data/tftp/pxelinux.cfg/default
vim /data/tftp/pxelinux.cfg/default

default linux initrd=initrd.img ks=http://192.168.100.35/ks.cfg

default vesamenu.c32

prompt 1

timeout 30

display boot.msg

menu background splash.jpg
menu title Welcome to CentOS 6.4 by jesse!
menu color border 0 #ffffffff #00000000
menu color sel 7 #ffffffff #ff000000
menu color title 0 #ffffffff #00000000
menu color tabmsg 0 #ffffffff #00000000
menu color unsel 0 #ffffffff #00000000
menu color hotsel 0 #ff000000 #ffffffff
menu color hotkey 7 #ffffffff #ff000000
menu color scrollbar 0 #ffffffff #00000000

label linux
  menu label ^Install or upgrade an existing system
  menu default
  kernel vmlinuz
  append initrd=initrd.img
label vesa
  menu label Install system with ^basic video driver
  kernel vmlinuz
  append initrd=initrd.img xdriver=vesa nomodeset
label rescue
  menu label ^Rescue installed system
  kernel vmlinuz
  append initrd=initrd.img rescue
label local
  menu label Boot from ^local drive
  localboot 0xffff
label memtest86
  menu label ^Memory test
  kernel memtest
  append -

# 拷贝package
cp binutils-* cmake-2.6.4-5.el6.x86_64.rpm curl-7.19.7-35.el6.x86_64.rpm lrzsz-0.12.20-27.1.el6.x86_64.rpm make-3.81-20.el6.x86_64.rpm nc-1.84-22.el6.x86_64.rpm net-snmp-* openssh-clients-5.3p1-84.1.el6.x86_64.rpm rsync-3.0.6-9.el6.x86_64.rpm sysstat-9.0.4-20.el6.x86_64.rpm tree-1.5.3-2.el6.x86_64.rpm vim-common-7.2.411-1.8.el6.x86_64.rpm vim-minimal-7.2.411-1.8.el6.x86_64.rpm wget-1.12-1.8.el6.x86_64.rpm /data/iso/Packages

vim /data/iso/pxe/ks.cfg
install
url --url=http://192.168.100.31/
cdrom
lang en_US.UTF-8
keyboard us

network --onboot yes --device eth0 --bootproto dhcp

rootpw qwert54321

firewall --enabled --port=50022:tcp

firewall --disabled
authconfig --enableshadow --passalgo="author jesse"
selinux --disabled
timezone --utc Asia/Shanghai 
bootloader --location=mbr --driveorder=sda --append="crashkernel=auto rhgb quiet" 
zerombr
clearpart --all --initlabel
part swap --size=4096
part /boot --fstype=ext4 --size=512

part / --fstype=ext4 --size=15240

part /data --fstype=ext4 --grow --size=1

part / --fstype=ext4 --grow --size=1
reboot
%packages --nobase 
@core

%end

%post --log=/root/ks.post.log

user manage

groupadd sshuser
useradd -G sshuser jesse
echo "xxx"|passwd jesse --stdin
sed -i '/--dport 22/a-A INPUT -m state --state NEW -m tcp -p tcp --dport 50022 -j ACCEPT' /etc/sysconfig/iptables
echo 'jesse ALL=NOPASSWD: ALL' > /etc/sudoers.d/jesse

other 

echo "30 5 * * * /usr/sbin/ntpdate cn.pool.ntp.org" | crontab -
sed -i '1 a\nameserver 192.168.100.1' /etc/resolv.conf

init env & tool

cat > /root/init.install.sh << EOF
#!/bin/bash

# install package
yum install -y wget curl
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
curl -s -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.163.com/.help/CentOS6-Base-163.repo
yum makecache
yum install -q -y  binutils cmake curl lrzsz make nc net-snmp net-snmp-utils nmap ntpdate openssh-clients rsync sysstat tree vim wget
mkdir -p /backup
mv /root/* /backup/
EOF
chmod +x /root/init.install.sh

# ulimit setting
cat > /etc/security/limits.d/99-ops.conf << EOF
- soft nofile 655360
- hard nofile 655360
- hard nproc 4096
- soft nproc 4096
EOF
cat > /etc/security/limits.d/90-nproc.conf << EOF
- soft    nproc     4096
EOF

# close system service
chkconfig iptables off
chkconfig ip6tables off
chkconfig postfix off
chkconfig rpcbind off

# close tty
sed '23s/6/2/g' -i /etc/sysconfig/init

# kernel tcp
cat > /etc/sysctl.conf << EOF
net.ipv4.ip_forward = 0
net.ipv4.tcp_syncookies = 1
kernel.shmmni = 10240
kernel.sem = 250 32000 100 128
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.default.accept_source_route = 0
kernel.sysrq = 0
fs.file-max = 1213051
kernel.core_uses_pid = 1
net.ipv4.tcp_syncookies = 1
kernel.msgmnb = 65536
kernel.msgmax = 65536
kernel.shmmax = 68719476736
kernel.shmall = 4294967296
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 262144
net.ipv4.tcp_synack_retries = 3
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_keepalive_time = 10
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_max_tw_buckets = 1024
net.netfilter.nf_conntrack_tcp_timeout_established = 60
net.netfilter.nf_conntrack_max = 655350
net.nf_conntrack_max = 655350
EOF

# hostname setting
sed '2s/^.*/HOSTNAME=youja.cn/g' -i /etc/sysconfig/network

set group timetout

sed '11s/5/2/g' -i /etc/grub.conf

set history for profile

sed '48s/1000/100/g' -i /etc/profile

# login info
cat >> /etc/pam.d/login << EOF
session required /lib64/security/pam_limits.so
session required pam_limits.so
EOF
cat > /etc/issue << EOF
Welcome to 8ops.top
CentOS 6.4 x86_64 (Final)
EOF
/bin/cp /etc/issue /etc/issue.net

# ssh setting
echo "AllowGroups sshuser" >> /etc/ssh/sshd_config
sed -i '/#PermitRootLogin yes/a\PermitRootLogin no' /etc/ssh/sshd_config
sed -i '/#Port 22/a\Port 50022' /etc/ssh/sshd_config
cat >> /etc/ssh/sshd_config << EOF
PermitEmptyPasswords no
UseDNS no
Banner /etc/issue
EOF

# repo setting
cat > /etc/yum.repos.d/nginx.repo << EOF
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/6/$basearch/
baseurl=http://nginx.org/packages/centos/6/x86_64/
gpgcheck=0
enabled=1
EOF

cat > /etc/yum.repos.d/varnish.repo << EOF
[varnish-3.0]
name=Varnish 3.0 for Enterprise Linux 5 - $basearch
baseurl=http://repo.varnish-cache.org/redhat/varnish-3.0/el5/$basearch
baseurl=http://repo.varnish-cache.org/redhat/varnish-4.0/el6/x86_64/
gpgcheck=0
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-VARNISH
EOF

# ssh-key setting
mkdir -p /home/jesse/.ssh
cat > /home/jesse/.ssh/authorized_keys << EOF
ssh-dss AAAAB3NzaC1kc3MAAACBALN+zutgLhYyLEgmNnW9DbaVnPCLlq3dMv1gCk80lm7ufcUzNp9zvR3OrCECAq3s1w9vVPqWMfg21LkAAF/e/eTgBYI+aF4s+4z+Cn4eiXTyM0mRyuQ0YxWqs3GJLBjqcLVdOpWGy5F3X/9sAe9lG+SbbErSy68YxmYv7U40ha/9AAAAFQDtw6YYdKinAPj6hu6S3Islyb3ZdQAAAIAIIFtUk2V4ASA2QgE2OGLVM/QMeRYaRVdP/OHF4Ri2kvR0B3s5P1C652PKnc97bwb0BTHqDhTJoqfSKiHLHLBdfQXdLY1LLh/hiBdPasMrUMiSEhiy+pvjNqwW1BqL6b4hBpvooVkdHTk/6pKTYQwVhJ2oN8+0FzUk6GC+VseM8AAAAIEAg8LYT2iAv0hicgHFo3qmqv/MFvJQISlRWm0TxRBa3FFp6EH4MuaRzzVekur79h+oDOf/41QZ+j9M2oh5RdePUDGOQ6S3WBcppQOYc5vzF37wPv2Z1p1lD8vRSu2yNMxPjkMvlRu1+plYjjLyQvicyJbX7jN+DDl/iDp1pKYY5vg=
ssh-dss AAAAB3NzaC1kc3MAAACBANyhLAY0OZcXuP/zoSzb2wHp8yEd7C5bjLw794bPNHKJeYX8Whz0plqUirP9rKxiXGm1B2Nwnpf9wNmso/EFquMA2kVjAT56i7tvPNj5V/PmkUT5FIhApoFqw9pZ90vHPDyB8u/u4oNNO0N9sschVEJa592boH4u28rSvd78sAlfAAAAFQCH+kjWbyk1bm2RhroMkPx/zsQaWwAAAIAzFvXSzBWrm92V322txFVRwLU2ahz7V9H6Ff6OQEpdL0bylMQj6MD6d+v5P1H1fuPgCDtBB87XRGnvV4IonMocr2/Qm/YwUOnRZOLbg05/5wVZiJQkLsErnDgeFGat+Ib97P5ytLvZXPf1m/tW6FoxplZq5GjvQAQ2A7Cw/voQjwAAAIASoJ05CkDWzgfg4eBonFPEtJbF8eGIEqH6y1e09NmBlw6S4khGfU3thg5OPQYfRLdOCg/4rnrc31T2TUnZaoL+W+nJe6+4uAiMFBTszpVlvQ1JD8yNPgIVZJD8/BMXE0eGLu+OVvMHlqTGIev8dUO+Iv3a3wBPuA8ReiI9ZTK+cw==
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDV5RZ2Cmd3rk01XgbMzubxQYFVcFznSnzadcB1dhDaw7MiC3DRLGU5YLgsZmZdZQxrGSVEXmXwEKrD9oxcwL31DnWJdjzsnJrHXv/6LXKh03OlQ7Di4UoNLxpFHZecX2o23fYuTdFBojL8sSeI9jucVAAskMFW0rJHcKiv1/f/CJnUIH604Z6xeHK7tfqJUJ+bxuLuhFgbMymHkbqNI2UU0L4LHBg8IvPIROA86xbSmgINZ/ccbhy7ZEhGOODLCY4K3AlVaWQqMrhjjOA003TBtYbrKGFWpG+KFdTVAbZjVawGbnWtSN03qYQPYmbSY5e1sH/oTyfzwWVeFI1d8tbv
EOF
chmod 700 -R /home/jesse/.ssh
chown jesse.jesse -R /home/jesse/.ssh

%end

# 启动服务
/etc/init.d/dhcpd restart
/etc/init.d/nginx restart
/etc/init.d/xinetd restart

chkconfig dhcpd on
chkconfig nginx on
chkconfig xinetd on

```



### mkiso

```bash
# 1，准备环境
yum install -y anaconda.x86_64 createrepo.noarch mkisofs.x86_64
mkdir /data/iso/mk
rsync -av /data/iso/pxe/ /data/iso/mk/

# 2，修改配置
vim /data/iso/mk/isolinux/ks.cfg

copy vim /data/iso/pxe/ks.cfg
modify #url --url=http://192.168.100.31/

vim /data/iso/mk/isolinux/isolinux.cfg

copy /data/tftp/pxelinux.cfg/default
modify default linux ks=cdrom:/isolinux/ks.cfg initrd=initrd.img

# 3，生成镜像
/bin/rm -f /data/iso/mk/repodata/*
/bin/cp /data/iso/pxe/repodata/*-minimal-x86_64.xml  /data/iso/mk/repodata/minimal-x86_64.xml
createrepo -g /data/iso/mk/repodata/minimal-x86_64.xml /data/iso/mk/
cd /data/iso/mk
mkisofs -o /tmp/Auto-CentOS-6.4-x86_64-$(date +%s).iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -R -J -v -T /data/iso/mk/

/usr/bin/implantisomd5 /tmp/*.iso 

vim /etc/nginx/nginx.conf
    server{
        listen 80;
        root /data/iso/pxe;
        autoindex on;
        
        location /download {
            alias /tmp;
            autoindex on;
        }
    }

nginx -t
nginx -s reload

```

