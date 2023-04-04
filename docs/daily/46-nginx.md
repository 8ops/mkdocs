# Nginx

## 一、ROOT美化

### 1.1 样式一

```bash
# server.conf
server {
    listen 48080;
    root /opt/autoindex;
    charset utf-8;
    autoindex on;
    autoindex_localtime on;
    autoindex_exact_size off;
    add_after_body /autoindex.html;
}
```





### 1.2 样式二

```bash
# server.conf
server {
    listen 48080;
    root /opt/autoindex;
    charset utf-8;
    autoindex on;
    autoindex_localtime on;
    autoindex_exact_size off;
    add_before_body /.autoindex/header.html;
    add_after_body /.autoindex/footer.html;
}    
```





## 二、主配置

`nginx.conf`

```bash
user  nginx;
worker_processes  auto;

error_log  /data/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    use epoll;
    worker_connections  65535;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format logex '{"timestamp":"$time_iso8601","msec":"$msec","remote_port":"$remote_port","method":"$request_method","server_name":"$host","uri":"$uri","args":"$args","server_protocol":"$server_protocol","http_user_agent":"$http_user_agent","http_referer":"$http_referer","http_cookie":"$http_cookie","request_time":"$request_time","response_time":"$upstream_response_time","remote_addr":"$remote_addr","upstream_http_location":"$upstream_http_location","x_real_ip":"$http_x_real_ip","x_forwarded_for":"$http_x_forwarded_for","upstream_addr":"$upstream_addr","response_code":"$status","upstream_response_code":"$upstream_status","request_length":"$request_length","content_length":"$content_length","bytes_sent":"$bytes_sent","body_bytes_sent":"$body_bytes_sent","scheme":"$scheme"}';

    access_log  /data/log/nginx/access.log  logex;

    # gzip
    gzip on;
    gzip_min_length 1k;
    gzip_buffers 4 16k;
    gzip_http_version 1.0;
    gzip_comp_level 6;
    gzip_types text/plain application/javascript application/x-javascript text/javascript text/xml text/css;
    gzip_disable "MSIE [1-6]\.";
    gzip_vary on;
    underscores_in_headers on;

    sendfile        on;
    tcp_nopush      on;
    keepalive_timeout  60;
    tcp_nodelay     on;
    charset UTF-8;

    # base
    server_tokens off;
    server_names_hash_max_size 1024;
    server_names_hash_bucket_size 128;
    client_header_buffer_size 32k;
    large_client_header_buffers 4 32k;
    client_max_body_size  50m;
    client_header_timeout 30;
    client_body_timeout   30;
    send_timeout          60;
    fastcgi_connect_timeout 300;
    fastcgi_send_timeout 300;
    fastcgi_read_timeout 1800;
    fastcgi_buffer_size 64k;
    fastcgi_buffers 8 128k;
    fastcgi_busy_buffers_size 128k;
    fastcgi_temp_file_write_size 128k;

    # temp
    client_body_temp_path /dev/shm/client_body_temp;
    fastcgi_temp_path /dev/shm/fastcgi_temp;
    proxy_temp_path /dev/shm/proxy_temp;
    scgi_temp_path /dev/shm/scgi_temp;
    uwsgi_temp_path /dev/shm/uwsgi_temp;

    # proxy
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header CLIENT_IP $remote_addr;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_connect_timeout 60;
    proxy_send_timeout 300;
    proxy_read_timeout 300;
    proxy_headers_hash_max_size 51200;
    proxy_headers_hash_bucket_size 6400;
    proxy_buffer_size 16k;
    proxy_buffers 8 32k;
    proxy_busy_buffers_size 128k;
    proxy_temp_file_write_size 128k;
    proxy_http_version 1.1;
    proxy_next_upstream off;
    server_name_in_redirect off;

    # default 80
    server {
        listen 80 default;
        rewrite ^.*$ https://$host$uri permanent;
    }

    include conf.d/ops/*.conf;
    include conf.d/site/*.conf;
    include conf.d/wiki/*.conf;
}
```



### 2.1 证书配置

`ssl/8ops.top`

```bash
listen 443 ssl;
ssl_certificate     ssl.d/8ops.top.crt;
ssl_certificate_key ssl.d/8ops.top.key;
ssl_session_timeout 5m;
ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
ssl_prefer_server_ciphers on;
```



### 2.2 流量管理

`deny.d/8ops.top`

```bash
allow 8.8.8.8/32;

deny all;
```



### 2.3 熔断管理

`return`

```bash
location / {
       default_type text/plain;
       return 403 "Deny";
}
```





### 2.4 应用配置

`www.8ops.top.conf`

```bash
server {
    include ssl/8ops.top;
    server_name www.8ops.top;
    access_log /data/log/nginx/www.8ops.top_access.log logex;
    error_log /data/log/nginx/www.8ops.top_error.log;
    location / {
        proxy_pass https://10.0.0.1:8080;
    }
}
```



### 2.5 文件下载

`attachment`

```bash
location / {
        if ($request_filename ~* ^.*?\.(html|doc|pdf|zip|docx)$) {
            add_header  Content-Disposition attachment;
            add_header  Content-Type application/octet-stream;
        }
}
```



### 2.6 日志切割

`/etc/logrotate.d/nginx`

```bash
/data/log/nginx/*.log
/var/log/nginx/*.log {
        daily
        missingok
        rotate 30
        compress
        delaycompress
        notifempty
        create 644 nginx adm
        sharedscripts
        postrotate
                if [ -f /var/run/nginx.pid ]; then
                        kill -USR1 `cat /var/run/nginx.pid`
                fi
        endscript
}
```

## 三、RTMP

 自建直播

```bash

./configure \
--user=nginx \
--group=nginx \
--prefix=/usr/local/nginx-rtmp \
--with-pcre=/usr/local/src/pcre2-10.10 \
--add-module=/usr/local/src/nginx-rtmp-module-1.1.7 \
--add-module=/usr/local/src/nginx-rtmp-module-1.1.7/hls \
--add-module=/usr/local/src/nginx-rtmp-module-1.1.7/dash 

./configure \
--prefix=/usr/local/nginx-rtmp \
--add-module=../nginx-rtmp-module-1.1.7 \
--with-http_ssl_module \
--with-pcre=/usr/local/src/pcre-8.33

./configure \
--user=nginx \
--group=nginx \
--prefix=/usr/local/nginx-rtmp \
--add-module=/usr/local/src/nginx-rtmp-module-1.1.7 \
--with-http_ssl_module \
--with-http_ssl_module \
--with-http_realip_module \
--with-http_addition_module \
--with-http_sub_module \
--with-http_dav_module \
--with-http_flv_module \
--with-http_mp4_module \
--with-http_gunzip_module \
--with-http_gzip_static_module \
--with-http_random_index_module \
--with-http_secure_link_module \
--with-http_stub_status_module \
--with-http_auth_request_module \
--with-file-aio \
--with-ipv6 \
--with-http_spdy_module \
--with-pcre=/usr/local/src/pcre-8.33 \
--with-debug 

http://192.168.1.6:8080/record.html
http://192.168.1.6:8080/index.html

http://192.168.1.6:8080/rtmp-publisher/publisher.html
http://192.168.1.6:8080/rtmp-publisher/player.html

http://server.com/control/record/start|stop?srv=SRV&app=APP&name=NAME&rec=REC
curl -i "http://192.168.1.6:8080/control/record/start?app=myapp&name=mystream&rec=rec1"
curl -i "http://192.168.1.6:8080/control/record/stop?app=myapp&name=mystream&rec=rec1"

http://server.com/control/drop/publisher|subscriber|client?srv=SRV&app=APP&name=NAME&addr=ADDR&clientid=CLIENTID
curl -i "http://192.168.1.6:8080/control/drop/publisher?app=myapp&name=mystream"
curl -i "http://192.168.1.6:8080/control/drop/client?app=myapp&name=mystream"
curl -i "http://192.168.1.6:8080/control/drop/client?app=myapp&name=mystream&addr=192.168.0.1"
curl -i "http://192.168.1.6:8080/control/drop/client?app=myapp&name=mystream&clientid=1"

```

## 四、Module

```bash
cd /usr/local/src

wget http://192.168.1.22/nginx/nginx-1.4.7.tar.gz 
wget http://192.168.1.22/nginx/nginx-mogilefs-module-1.0.5.tar.gz
wget http://192.168.1.22/nginx/nginx-requestkey-module-1.0.tar.gz
wget http://192.168.1.22/nginx/pcre-8.33.tar.gz

yum install -y zlib.x86_64 zlib-devel.x86_64 gzip.x86_64 pcre.x86_64 pcre-devel.x86_64

useradd -M nginx 
mkdir -p /data/logs/nginx

vim src/core/nginx.h
#define NGINX_VERSION "1.0_1.4.7"
#define NGINX_VER "UPLUS_SERVER/" NGINX_VERSION
#define NGINX_VAR "UPLUS_SERVER"
#define NGX_OLDPID_EXT ".oldbin"

vim src/http/ngx_http_header_filter_module.c
static char ngx_http_server_string[] = "Server: UPLUS_SERVER" CRLF;

./configure \
--prefix=/usr/local/nginx \
--user=nginx \
--group=nginx \
--with-http_gunzip_module \
--with-http_gzip_static_module \
--with-http_stub_status_module 

make && make install


=======

yum install -y  binutils make cmake vim gcc gcc-devel
yum install -y pcre-devel.x86_64 pcre.x86_64
yum install -y openssl-devel.x86_64 openssl.x86_64
yum install -y gd-devel.x86_64 gd.x86_64
yum install -y GeoIP-devel.x86_64 GeoIP.x86_64
yum install -y libxml2-devel.x86_64 libxml2.x86_64 libxslt-devel.x86_64 libxslt.x86_64

vim src/core/nginx.h
...
#define nginx_version      1006002
#define NGINX_VERSION      "1.1_1.6.2"
#define NGINX_VER          "UPLUS_SERVER/" NGINX_VERSION

#define NGINX_VAR          "UPLUSE_SERVER"
#define NGX_OLDPID_EXT     ".oldbin"
...

vim src/http/ngx_http_header_filter_module.c
...
static char ngx_http_server_string[] = "Server: UPLUS_SERVER" CRLF;
...

cat > /etc/profile.d/nginx-env.sh <<EOF
export NGINX_HOME=/usr/local/nginx
export PATH=\${NGINX_HOME}/sbin:\$PATH
EOF
. /etc/profile
echo $PATH
which nginx

UPLUS_SERVER/1.1_1.6.2

./configure --prefix=/usr/local/nginx  --user=nginx --group=nginx --conf-path=/usr/local/nginx/conf/nginx.conf --error-log-path=/usr/local/nginx/logs/error.log --http-client-body-temp-path=/usr/local/nginx/body --http-fastcgi-temp-path=/usr/local/nginx/fastcgi --http-log-path=/usr/local/nginx/logs/access.log --http-proxy-temp-path=/usr/local/nginx/proxy --http-scgi-temp-path=/usr/local/nginx/scgi --http-uwsgi-temp-path=/usr/local/nginx/uwsgi --lock-path=/var/run/nginx.lock --pid-path=/var/run/nginx.pid --with-debug --with-http_addition_module --with-http_dav_module --with-http_geoip_module --with-http_gzip_static_module --with-http_image_filter_module --with-http_realip_module --with-http_stub_status_module --with-http_ssl_module --with-http_sub_module --with-http_xslt_module --with-ipv6 --with-sha1=/usr/include/openssl --with-md5=/usr/include/openssl --with-mail --with-mail_ssl_module --with-http_gunzip_module 

make && make install


./configure \
--prefix=/usr/local/nginx \
--user=nginx \
--group=nginx \
--with-http_ssl_module \
--with-http_realip_module \
--with-http_addition_module \
--with-http_sub_module \
--with-http_dav_module \
--with-http_flv_module \
--with-http_mp4_module \
--with-http_gunzip_module \
--with-http_gzip_static_module \
--with-http_random_index_module \
--with-http_secure_link_module \
--with-http_stub_status_module \
--with-http_auth_request_module \
--with-mail \
--with-mail_ssl_module \
--with-file-aio \
--with-ipv6 \
--with-http_spdy_module \
--with-cc-opt='-O2 -g -pipe -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector \
--param=ssp-buffer-size=4 -m64 -mtune=generic'

# add-module nginx-rtmp-module
./configure \
--prefix=/usr/local/nginx \
--user=nginx \
--group=nginx \
--with-http_ssl_module \
--with-http_realip_module \
--with-http_addition_module \
--with-http_sub_module \
--with-http_dav_module \
--with-http_flv_module \
--with-http_mp4_module \
--with-http_gunzip_module \
--with-http_gzip_static_module \
--with-http_random_index_module \
--with-http_secure_link_module \
--with-http_stub_status_module \
--with-http_auth_request_module \
--with-mail \
--with-mail_ssl_module \
--with-file-aio \
--with-ipv6 \
--with-http_spdy_module \
--with-cc-opt='-O2 -g -pipe -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector \
--param=ssp-buffer-size=4 -m64 -mtune=generic' \
--add-module=../nginx-rtmp-module-1.1.7 \
--with-pcre=../pcre-8.33

================================================================================

./configure  \
--prefix=/usr/local/nginx  \
--user=nginx  \
--group=nginx  \
--with-http_ssl_module  \
--with-http_realip_module  \
--with-http_addition_module  \
--with-http_sub_module  \
--with-http_dav_module  \
--with-http_flv_module  \
--with-http_mp4_module  \
--with-http_gunzip_module  \
--with-http_gzip_static_module  \
--with-http_random_index_module  \
--with-http_secure_link_module  \
--with-http_stub_status_module  \
--with-http_auth_request_module  \
--with-mail  \
--with-mail_ssl_module  \
--with-file-aio  \
--with-ipv6  \
--with-http_spdy_module  \
--with-cc-opt='-O2 -g -pipe -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector --param=ssp-buffer-size=4 -m64 -mtune=generic'  \
--with-http_image_filter_module \
--with-pcre=../pcre-8.36  \
--add-module=../echo-nginx-module-0.58 \
--add-module=../nginx-rtmp-module-1.1.7  \
--add-module=../ngx_cache_purge-2.3 \
--add-module=../ngx_devel_kit-0.2.19 \
--add-module=../lua-nginx-module-0.10.0 \
--add-module=../ngx_pagespeed-release-1.9.32.11-beta  \
--add-module=../redis2-nginx-module-0.12 \
--add-module=../sqlite-http-basic-auth-nginx-module-master 


make && make install

#(未成功)--add-module=../ngx_image_thumb \
#(未成功)--add-module=../nginx-requestkey-module \

wget http://uplus.file.youja.cn/nginx/pcre-8.36.tar.gz

--------------------------

--with-http_image_filter_module # images_filter
yum install gd-devel # gcc automake autoconf m4
apt-get install libgd2-xpm libgd2-xpm-dev # build-essential m4 autoconf automake make libcurl-dev libgd2-dev libpcre-dev 

conf: 
image_filter test; #测试图片合法性
image_filter rotate 90|180|270; #角度旋转
image_filter size; #获取图片的ID3信息宽和高
resize [width] [height]; #指定宽和高
image_filter crop [width] [height]; #最大边缩放图片后裁剪
image_filter_buffer; #限制图片最大读取大小，默认为1M
image_filter_jpeg_quality; #设置jpeg图片的压缩质量比例
image_filter_transparency; #用来禁用gif和palette-based的png图片的透明度，以此来提高图片质量。

--------------------------

--add-module=../ngx_pagespeed-release-1.10.33.1-beta  \ 
# google optimze image
cd /usr/local/src
NPS_VERSION=1.10.33.1
wget https://github.com/pagespeed/ngx_pagespeed/archive/release-${NPS_VERSION}-beta.zip -O release-${NPS_VERSION}-beta.zip
unzip release-${NPS_VERSION}-beta.zip
cd ngx_pagespeed-release-${NPS_VERSION}-beta/
wget https://dl.google.com/dl/page-speed/psol/${NPS_VERSION}.tar.gz
tar -xzvf ${NPS_VERSION}.tar.gz

--------------------------

--add-module=../ngx_image_thumb # ngx_image_thumb，未编译通过
image on/off 是否开启缩略图功能,默认关闭
image_backend on/off 是否开启镜像服务，当开启该功能时，请求目录不存在的图片（判断原图），将自动从镜像服务器地址下载原图
image_backend_server 镜像服务器地址
image_output on/off 是否不生成图片而直接处理后输出 默认off
image_jpeg_quality 75 生成JPEG图片的质量 默认值75
image_water on/off 是否开启水印功能
image_water_type 0/1 水印类型 0:图片水印 1:文字水印
image_water_min 300 300 图片宽度 300 高度 300 的情况才添加水印
image_water_pos 0-9 水印位置 默认值9 0为随机位置,1为顶端居左,2为顶端居中,3为顶端居右,4为中部居左,5为中部居中,6为中部居右,7为底端居左,8为底端居中,9为底端居右
image_water_file 水印文件(jpg/png/gif),绝对路径或者相对路径的水印图片
image_water_transparent 水印透明度,默认20
image_water_text 水印文字 "Power By Vampire"
image_water_font_size 水印大小 默认 5
image_water_font 文字水印字体文件路径
image_water_color 水印文字颜色,默认 #000000

--------------------------

--add-module=../nginx-rtmp-module-1.1.7  \ # rtmp
#RTMP
wget http://uplus.file.youja.cn/nginx/nginx-rtmp-module-1.1.7.tar.gz


--------------------------

--add-module=../ngx_cache_purge
#清除缓存文件
git clone https://github.com/FRiCKLE/ngx_cache_purge.git

proxy_cache_path /dev/shm levels=1:2 keys_zone=jcache:128m inactive=1d max_size=256m;  
server {
    listen      80;

    location ~* ^/purge(/\S+)$ {
        proxy_cache_purge jcache $1;
    }
    
    location ~* .*\.(jpg|png|gif|css|js)$ {
        proxy_cache jcache;
        proxy_cache_valid 200 302 30m;
        proxy_cache_key $uri;
        proxy_set_header Host "www.baidu.com";
        proxy_pass http://www.baidu.com;
    }
    
    location / {
        proxy_set_header Host "www.youja.cn";
        proxy_pass http://www.baidu.com;
    }
}

http://domain
http://domain/purge/test.png

--------------------------

--add-module=../nginx-requestkey-module
#key加密验证 （未通过）估计高版本不支持此功能，或module待更新
https://github.com/miyanaga/nginx-requestkey-module.git

（官方貌似没了）下载文件：Nginx-accesskey-2.03.tar.gz 
解压后 修改conf文件，把”$HTTP_ACCESSKEY_MODULE“替换为"ngx_http_accesskey_module",然后编译nginx;
accesskey
语句: accesskey [on|off]
默认: accesskey off
可以用在: main, server, location
开启 access-key 功能。
accesskey_arg
语句: accesskey_arg "字符"
默认: accesskey "key"
可以用在: main, server, location
URL中包含 access key 的GET参数。
accesskey_hashmethod
语句: accesskey_hashmethod [md5|sha1]
默认: accesskey_hashmethod md5（默认用 md5 加密）
可以用在: main, server, location
用 MD5 还是 SHA1 加密 access key。
accesskey_signature
语句: accesskey_signature "字符"
默认: accesskey_signature "$remote_addr"
可用在: main, server, location

location / {
   default_type text/plain; 
   accesskey             on;
   accesskey_hashmethod  md5;
   accesskey_arg         "key";
   accesskey_signature   "jesse$uri";
   return 200 "OK";
}

--------------------------

--add-module=../redis2-nginx-module-0.12
#操作redis
https://github.com/openresty/redis2-nginx-module.git

upstream redis_pool{
    server 127.0.0.1:6379;
}

server {
    listen      80;

    location ~* "^/(\w+)$" {
        redis2_query $1;
        redis2_pass redis_pool;
    }
    
    location ~* "^/(\w+)/(\w+)$" {
        redis2_query $1 $2;
        redis2_pass redis_pool;
    }
    
    location ~* "^/(\w+)/(\w+)/(\w+)$" {
        redis2_query $1 $2 $3;
        redis2_pass redis_pool;
    }
    
    location ~* "^/(\w+)/(\w+)/(\w+)/(\w+)$" {
        redis2_query $1 $2 $3 $4;
        redis2_pass redis_pool;
    }
    location ~* "^/(\w+)/(\w+)/(\w+)/(\w+)/(\w+)$" {
        redis2_query $1 $2 $3 $4 $5;
        redis2_pass redis_pool;
    }
    
    location / {
        default_type text/plain;
        return 200 "Not found $uri";
    }
}

curl http://domain/set/one/first
curl http://domain/get/one

--------------------------

--add-module=../sqlite-http-basic-auth-nginx-module-master
https://github.com/kunal/sqlite-http-basic-auth-nginx-module.git
#sqlite使用
location / {
        auth_sqlite_basic "Restricted Sqlite";
        auth_sqlite_basic_database_file  /dev/shm/sqlite3.db; # Sqlite DB file
        auth_sqlite_basic_database_table  auth_table; # Sqlite DB table
        auth_sqlite_basic_table_user_column  user; # User column
        auth_sqlite_basic_table_passwd_column  password; # Password column
   }

--------------------------


Nginx + Lua

wget http://luajit.org/download/LuaJIT-2.0.4.tar.gz
tar xvzf LuaJIT-2.0.4.tar.gz
cd LuaJIT-2.0.4
make && make install

cat > /etc/profile.d/lua-env.sh << EOF
export LUAJIT_LIB=/usr/local/lib
export LUAJIT_INC=/usr/local/include/luajit-2.0

EOF

wget -O lua-nginx-module-0.10.0.tar.gz https://codeload.github.com/openresty/lua-nginx-module/tar.gz/v0.10.0
wget -O ngx_devel_kit-0.2.19.tar.gz https://codeload.github.com/simpl/ngx_devel_kit/tar.gz/v0.2.19

tar xvzf lua-nginx-module-0.10.0.tar.gz
tar xvzf ngx_devel_kit-0.2.19.tar.gz 

--add-module=../ngx_devel_kit-0.2.19 \
--add-module=../lua-nginx-module-0.10.0

cannot open shared object file: No such file or directory  解决方法

ldd /usr/local/nginx/sbin/nginx

echo "/usr/local/lib" > /etc/ld.so.conf.d/usr_local_lib.conf

location /lua {
    set $test "hello, world.";
    content_by_lua '
        ngx.header.content_type = "text/plain";
        ngx.say(ngx.var.test);
    ';
}

--------------------------

echo-nginx-module

--add-module=../echo-nginx-module-0.58

wget -O echo-nginx-module-0.58.tar.gz https://codeload.github.com/openresty/echo-nginx-module/tar.gz/v0.58

location /echo {
    default_type text/plain;
    echo "Hello, jesse";

}

--------------------------

-- 2016-04-26 1.10.0 support stream

./configure --prefix=/usr/local/nginx --user=nginx --group=nginx --with-http_ssl_module --with-http_realip_module --with-http_addition_module --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_random_index_module --with-http_secure_link_module --with-http_stub_status_module --with-http_auth_request_module --with-mail --with-mail_ssl_module --with-file-aio --with-ipv6 --with-cc-opt='-O2 -g -pipe -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector --param=ssp-buffer-size=4 -m64 -mtune=generic' --with-pcre=../pcre-8.38 --with-http_image_filter_module --add-module=../nginx-rtmp-module-1.1.7 --add-module=../ngx_cache_purge --with-stream


stream {
    upstream test_tcp {
        server 127.0.0.1:11111 weight=5;
        server 127.0.0.1:11112 max_fails=3 fail_timeout=30s;
    }

    upstream test_udp {
        server 127.0.0.1:11111 weight=5;
        server 127.0.0.1:11112 max_fails=3 fail_timeout=30s;
    }
    
    server {
       listen 12345;
       proxy_connect_timeout 1s;
       proxy_timeout 3s;
       proxy_responses 1;
       proxy_pass test_tcp;
   }

    server {
       listen 12345 udp;
       proxy_connect_timeout 1s;
       proxy_timeout 3s;
       proxy_responses 1;
       proxy_pass test_tcp;
    }
}

cat > /etc/profile.d/openresty-env.sh <<EOF
export OPENRESTY_HOME=/usr/local/openresty
export PATH=\${OPENRESTY_HOME}/bin:\${OPENRESTY_HOME}/luajit/bin:\$PATH
EOF


https://openresty.org/download/ngx_openresty-1.9.7.2.tar.gz

https://openresty.org/download/openresty-1.11.2.1.tar.gz

```

