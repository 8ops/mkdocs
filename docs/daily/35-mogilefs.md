# mogilefs

```bash


参考版本号 ~ 2015-05-12

mysql 5.5.24
perl 5.10.1
MogileFS:Server 2.66
MogileFS:Utils 2.26
MogileFS:Client 1.17
Sys:Syscall 0.23
Cache::Memcached 1.30
Time::HiRes 1.9721
……
nginx 1.2.9
nginx-mogilefs-module 1.0.4
nginx-requestkey-module 1.0

pcre 8.33

yum install -q -y gcc.x86_64 gcc-c++.x86_64 gcc.x86_64 make.x86_64 binutils.x86_64 patch.x86_64 mysql-devel.x86_64 perl-CPAN.x86_64 git.x86_64 tree.x86_64 vim.x86_64 perl-YAML.noarch libyaml-devel.x86_64 

perl -MCPAN -e shell

version 2.66            1.17            2.26           1.61          4.32    1.9022       1.80    1.633 4.031     0.70 1.2907        1.30             1.9721

install  MogileFS::Server MogileFS::Client MogileFS::Utils Danga::Socket IO::AIO Net::Netmask Perlbal DBI   DBD:mysql YAML BSD::Resource Cache::Memcached Time::HiRes

m MogileFS::Server
m MogileFS::Utils
m MogileFS::Client
m Sys::Syscall
m Cache::Memcached
m Time::HiRes
force install D/DO/DORMANDO/MogileFS-Server-2.66.tar.gz
force install D/DO/DORMANDO/MogileFS-Utils-2.26.tar.gz
force install B/BR/BRADFITZ/Sys-Syscall-0.23.tar.gz # 版本兼容性异常

---

mogdbsetup --dbhost=10.10.10.167 --dbname=mogilefs_7101 --dbuser=mogilefs --dbpassword=mogilefs --yes

mkdir -p /etc/mogilefs
vim /etc/mogilefs/mogilefsd_7101.conf
db_dsn = DBI:mysql:mogilefs_7101:host=10.10.10.167;port=3306;mysql_connect_timeout=5
db_user = mogilefs
db_pass = mogilefs
conf_port = 7101
listener_jobs = 5
node_timeout = 5
query_jobs = 30
replicate_jobs = 10
rebalance_ignore_missing = 1

useradd mogilefs -s /bin/sh -M --uid=600
/bin/su mogilefs -c "/usr/local/bin/mogilefsd -c /etc/mogilefs/mogilefsd_7101.conf --daemon"

vim /etc/mogilefs/mogstored.conf
httplisten=0.0.0.0:7500
mgmtlisten=0.0.0.0:7501
docroot=/storage
maxconns=10000

/usr/local/bin/mogstored --daemon

mogadm --trackers=10.10.10.130:7101,10.10.10.131:7101 settings set memcache_servers 10.10.10.174:11221

add host & device

mogadm --trackers=10.10.10.130:7101,10.10.10.131:7101 host add host_101 --ip=10.10.10.130 --port=7500 --status=alive
mogadm --trackers=10.10.10.130:7101,10.10.10.131:7101 host add host_102 --ip=10.10.10.131 --port=7500 --status=alive

有三个server端口

mogadm --trackers=10.10.10.130:7101 host add host_101 --ip=10.10.10.130 --port=7500 --status=alive
mogadm --trackers=10.10.10.130:7102 host add host_101 --ip=10.10.10.130 --port=7500 --status=alive
mogadm --trackers=10.10.10.130:7103 host add host_101 --ip=10.10.10.130 --port=7500 --status=alive

mogadm --trackers=10.10.10.130:7101,10.10.10.131:7101 host list
mogadm --trackers=10.10.10.130:7101,10.10.10.131:7102 host list
mogadm --trackers=10.10.10.130:7101,10.10.10.131:7103 host list

mogadm --trackers=10.10.10.130:7101,10.10.10.131:7101 device add host_101 101
mogadm --trackers=10.10.10.130:7101,10.10.10.131:7101 device add host_101 102
mogadm --trackers=10.10.10.130:7101,10.10.10.131:7101 device add host_101 103
mogadm --trackers=10.10.10.130:7101,10.10.10.131:7101 device add host_101 104
mogadm --trackers=10.10.10.130:7101,10.10.10.131:7101 device add host_101 105
mogadm --trackers=10.10.10.130:7101,10.10.10.131:7101 device add host_101 106

mogadm --trackers=10.10.10.130:7101,10.10.10.131:7101 device list
mogadm --trackers=10.10.10.130:7101,10.10.10.131:7102 device list
mogadm --trackers=10.10.10.130:7101,10.10.10.131:7103 device list

---

mogadm --trackers=10.10.10.130:7101 host add host_102 --ip=10.10.10.131 --port=7500 --status=alive
mogadm --trackers=10.10.10.130:7102 host add host_102 --ip=10.10.10.131 --port=7500 --status=alive
mogadm --trackers=10.10.10.130:7103 host add host_102 --ip=10.10.10.131 --port=7500 --status=alive

mogadm --trackers=10.10.10.130:7101,10.10.10.131:7101 device add host_102 201
mogadm --trackers=10.10.10.130:7101,10.10.10.131:7101 device add host_102 202
mogadm --trackers=10.10.10.130:7101,10.10.10.131:7101 device add host_102 203
mogadm --trackers=10.10.10.130:7101,10.10.10.131:7101 device add host_102 204
mogadm --trackers=10.10.10.130:7101,10.10.10.131:7101 device add host_102 205
mogadm --trackers=10.10.10.130:7101,10.10.10.131:7101 device add host_102 206

当追加存储机器时，有三个server端口

mogadm --trackers=10.10.10.130:7101 host add host_104 --ip=10.10.10.133 --port=7500 --status=alive
mogadm --trackers=10.10.10.130:7102 host add host_104 --ip=10.10.10.133 --port=7500 --status=alive
mogadm --trackers=10.10.10.130:7103 host add host_104 --ip=10.10.10.133 --port=7500 --status=alive

mogadm --trackers=10.10.10.130:7101,10.10.10.131:7101 host list
mogadm --trackers=10.10.10.130:7101,10.10.10.131:7102 host list
mogadm --trackers=10.10.10.130:7101,10.10.10.131:7103 host list

mogadm --trackers=10.10.10.130:7101 device add host_104 401
mogadm --trackers=10.10.10.130:7101 device add host_104 402
mogadm --trackers=10.10.10.130:7101 device add host_104 403
mogadm --trackers=10.10.10.130:7101 device add host_104 404
mogadm --trackers=10.10.10.130:7101 device add host_104 405
mogadm --trackers=10.10.10.130:7101 device add host_104 406

mogadm --trackers=10.10.10.130:7102 device add host_104 401
mogadm --trackers=10.10.10.130:7102 device add host_104 402
mogadm --trackers=10.10.10.130:7102 device add host_104 403
mogadm --trackers=10.10.10.130:7102 device add host_104 404
mogadm --trackers=10.10.10.130:7102 device add host_104 405
mogadm --trackers=10.10.10.130:7102 device add host_104 406

mogadm --trackers=10.10.10.130:7103 device add host_104 401
mogadm --trackers=10.10.10.130:7103 device add host_104 402
mogadm --trackers=10.10.10.130:7103 device add host_104 403
mogadm --trackers=10.10.10.130:7103 device add host_104 404
mogadm --trackers=10.10.10.130:7103 device add host_104 405
mogadm --trackers=10.10.10.130:7103 device add host_104 406

mogadm --trackers=10.10.10.130:7101,10.10.10.131:7101 device list
mogadm --trackers=10.10.10.130:7101,10.10.10.131:7102 device list
mogadm --trackers=10.10.10.130:7101,10.10.10.131:7103 device list

让最近的文件写进新追加的磁盘device with 7102（当前在用7002）

mogadm --trackers=10.10.10.130:7102 device mark host_101 101 drain

mogadm --trackers=10.10.10.130:7102 device mark host_101 101 drain
mogadm --trackers=10.10.10.130:7102 device mark host_101 102 drain
mogadm --trackers=10.10.10.130:7102 device mark host_101 103 drain
mogadm --trackers=10.10.10.130:7102 device mark host_101 104 drain
mogadm --trackers=10.10.10.130:7102 device mark host_101 105 drain
mogadm --trackers=10.10.10.130:7102 device mark host_101 106 drain

mogadm --trackers=10.10.10.130:7102 device mark host_102 201 drain
mogadm --trackers=10.10.10.130:7102 device mark host_102 202 drain
mogadm --trackers=10.10.10.130:7102 device mark host_102 203 drain
mogadm --trackers=10.10.10.130:7102 device mark host_102 204 drain
mogadm --trackers=10.10.10.130:7102 device mark host_102 205 drain
mogadm --trackers=10.10.10.130:7102 device mark host_102 206 drain

mogadm --trackers=10.10.10.130:7102 device check

一定时间后得解锁回来 

mogadm --trackers=10.10.10.130:7102 device modify host_101 101 --status=alive --weight=10

mogadm --trackers=10.10.10.130:7102,10.10.10.131:7102 check
mogadm --trackers=10.10.10.130:7102,10.10.10.131:7102 device list

===============================================================================
mogadm --trackers=10.10.10.130:7101,10.10.10.131:7101 domain add image
mogadm --trackers=10.10.10.130:7101,10.10.10.131:7101 domain add audio
mogadm --trackers=10.10.10.130:7101,10.10.10.131:7101 domain list

mogadm --trackers=10.10.10.130:7101 check
mogadm --trackers=10.10.10.130:7102 check
mogadm --trackers=10.10.10.130:7103 check

nginx

yum install -y zlib.x86_64 zlib-devel.x86_64 gzip.x86_64 binutils make cmake vim gcc gcc-devel openssl-devel.x86_64 openssl.x86_64 gd-devel.x86_64 gd.x86_64 GeoIP-devel.x86_64 GeoIP.x86_64 libxml2-devel.x86_64 libxml2.x86_64 libxslt-devel.x86_64 libxslt.x86_64
useradd nginx -s /bin/sh -M --uid=610

cd /usr/local/src
wget -O pcre-8.33.tar.gz "http://uplus.file.youja.cn/nginx/pcre-8.33.tar.gz"
tar xzvf pcre-8.33.tar.gz

wget -O nginx-requestkey-module-1.0.tar.gz "http://uplus.file.youja.cn/nginx/nginx-requestkey-module-1.0.tar.gz"
tar xzvf nginx-requestkey-module-1.0.tar.gz

wget -O nginx-mogilefs-module-1.0.5.tar.gz "http://uplus.file.youja.cn/nginx/nginx-mogilefs-module-1.0.5.tar.gz"
tar xzvf nginx-mogilefs-module-1.0.5.tar.gz
cd nginx-mogilefs-module-1.0.5
patch < mogilefs_count.patch

cd /usr/local/src
wget -O nginx-1.2.9.tar.gz "http://uplus.file.youja.cn/nginx/nginx-1.2.9.tar.gz"
tar xzvf nginx-1.2.9.tar.gz
cd nginx-1.2.9

--
vim src/core/nginx.h
...

define nginx_version      1006002

define NGINX_VERSION      "1.1_1.6.2"

define NGINX_VER          "UPLUS_SERVER/" NGINX_VERSION

define NGINX_VAR          "UPLUSE_SERVER"

define NGX_OLDPID_EXT     ".oldbin"

...

vim src/http/ngx_http_header_filter_module.c
...
static char ngx_http_server_string[] = "Server: UPLUS_SERVER" CRLF;

...

./configure --prefix=/usr/local/nginx --user=nginx --group=nginx \
--with-http_ssl_module \
--with-http_realip_module \
--with-http_addition_module \
--with-http_sub_module \
--with-http_dav_module \
--with-http_flv_module \
--with-http_mp4_module \
--with-http_gzip_static_module \
--with-http_random_index_module \
--with-http_secure_link_module \
--with-http_stub_status_module \
--with-mail \
--with-mail_ssl_module \
--with-file-aio --with-ipv6 \
--with-cc-opt='-O2 -g -pipe -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector --param=ssp-buffer-size=4 -m64 -mtune=generic' \
--with-pcre=/usr/local/src/pcre-8.33 \
--add-module=/usr/local/src/nginx-mogilefs-module-1.0.5 \
--add-module=/usr/local/src/nginx-requestkey-module-1.0

make && make install

cat > /etc/profile.d/nginx-env.sh <<EOF
export NGINX_HOME=/usr/local/nginx
export PATH=$NGINX_HOME/sbin:$PATH
EOF

vim /etc/profile
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

. /etc/profile

mkdir -p /data/logs/nginx










```
