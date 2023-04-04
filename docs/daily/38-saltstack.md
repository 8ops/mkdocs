
# saltstack
```bash
# 1，源安装 
# For RHEL 5:

rpm -Uvh http://mirror.pnl.gov/epel/5/i386/epel-release-5-4.noarch.rpm

# For RHEL 6:
rpm -Uvh http://ftp.linux.ncsu.edu/pub/epel/6/i386/epel-release-6-8.noarch.rpm
rpm -Uvh http://ftp.linux.ncsu.edu/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm

sed -i 's/https:/http/g' /etc/yum.repos.d/epel.repo

# 2，脚本安装

Many popular distributions will be able to install the salt minion by executing the bootstrap script:

wget -O - http://bootstrap.saltstack.org | sudo sh

curl -L http://bootstrap.saltstack.org | sudo sh -s -M -N


--------------------------------------------------------------------------------
# 添加 salt yum 安装源

cat > /etc/yum.repos.d/epel.repo << EOF
[epel]
name=Extra Packages for Enterprise Linux 6 - \$basearch
#baseurl=http://download.fedoraproject.org/pub/epel/6/$basearch
mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=epel-6&arch=$basearch
failovermethod=priority
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6

[epel-debuginfo]
name=Extra Packages for Enterprise Linux 6 - \$basearch - Debug
#baseurl=http://download.fedoraproject.org/pub/epel/6/$basearch/debug
mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=epel-debug-6&arch=$basearch
failovermethod=priority
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6
gpgcheck=1

[epel-source]
name=Extra Packages for Enterprise Linux 6 - \$basearch - Source
#baseurl=http://download.fedoraproject.org/pub/epel/6/SRPMS
mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=epel-source-6&arch=$basearch
failovermethod=priority
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6
gpgcheck=1

EOF

yum install -y salt-master.noarch
yum install -y salt-minion.noarch

chkconfig --add salt-master
chkconfig salt-master on

chkconfig --add salt-minion
chkconfig salt-minion on

# 1, master 配置

cat /etc/salt/master
interface: 0.0.0.0
auto_accept: True #(or False)

2, minion配置

cat /etc/salt/minion
master: master.salt.youja.cn
id: rabbitmq_10_81




--------------------------------------------------------------------------------
# salt-dashboard 使用（Web方式之一，来源网友）

https://github.com/halfss/salt-dashboard

python 2.6
django 1.6
hashlib
MySQLdb


--------------------------------------------------------------------------------
# cherrypy/paste/gevent 使用（Web方式之二，来源官方）

python 2.6

salt-api
python-cherrypy

yum install -y make binutils gcc gcc-c++.x86_64 libgcc.x86_64 gcc.x86_64
yum install -y openssl.x86_64 openssl-perl.x86_64 openssl-devel.x86_64 openssl-static.x86_64
yum install -y libffi-devel.x86_64

# Halite只支持2014.1.0及更高版本的Salt，默认python-halite只会安装CherryPy
yum install python-devel
yum install -y python-halite
yum install -y python-pip
/usr/bin/pip install -U halite
yum install gcc
/usr/bin/pip install pyopenssl

/usr/bin/pip install CherryPy
/usr/bin/pip install paste
/usr/bin/pip install gevent

vim /etc/salt/master

external_auth:
  pam:
    testuser:
      - .*
      - '@runner'

# 如果想配置cherrypy, 请在/etc/salt/master文件底部增加如下内容:
halite:
  level: 'debug'
  server: 'cherrypy'
  host: '0.0.0.0'
  port: '8080'
  cors: False
  tls: True
  certpath: '/etc/pki/tls/certs/localhost.crt'
  keypath: '/etc/pki/tls/certs/localhost.key'
  pempath: '/etc/pki/tls/certs/localhost.pem'

# 如果你想使用paste：
halite:
  level: 'debug'
  server: 'paste'
  host: '0.0.0.0'
  port: '8080'
  cors: False
  tls: True
  certpath: '/etc/pki/tls/certs/localhost.crt'
  keypath: '/etc/pki/tls/certs/localhost.key'
  pempath: '/etc/pki/tls/certs/localhost.pem'

# 使用gevent:
halite:
  level: 'debug'
  server: 'gevent'
  host: '0.0.0.0'
  port: '8080'
  cors: False
  tls: True
  certpath: '/etc/pki/tls/certs/localhost.crt'
  keypath: '/etc/pki/tls/certs/localhost.key'
  pempath: '/etc/pki/tls/certs/localhost.pem'


cd /etc/pki/tls/certs
salt-call tls.create_self_signed_cert tls # 会生成 crt,key 文件

openssl req -new -x509 -key localhost.key -out localhost.pem -days 36500

# 浏览器访问
https://localhost:8080/app

# 添加 pem 到浏览器证书

/etc/init.d/salt-master start
/etc/init.d/salt-api start # 运行就OK，不会常驻

```