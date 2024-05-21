# sentry

[Reference](https://github.com/getsentry/self-hosted)

## 一、准备

### 1.1 GeoIP

```bash
# 参考版本 23.5.1

# 先确认是否支持 SSE4.2
grep -i sse4 /proc/cpuinfo 

# config geoip
# https://develop.sentry.dev/self-hosted/geolocation/
cat > geoip/GeoIP.conf <<EOF
AccountID 871425
LicenseKey xxxxxx
EditionIDs GeoLite2-ASN GeoLite2-City GeoLite2-Country
EOF

```



### 1.2 Email

```bash
# config mail
vim sentry/config.yml
...
mail.host: 'smtp.exmail.qq.com'
mail.port: 465
mail.username: 'sentry@8ops.top'
mail.password: 'xxxxxx'
mail.use-tls: true
mail.use-ssl: false
mail.from: 'Sentry <sentry-noreplay@8ops.top>'
...

# 注意
#1. 端口是587不是465
#2. 密码是 设置-微信绑定-安全登录-客户端专用密码，不是企业微信登录密码

```



## 二、搭建

```bash
cd /usr/local
SENTRY_VERSION=24.4.2
wget https://github.com/getsentry/self-hosted/archive/refs/tags/${SENTRY_VERSION}.tar.gz
tar xzf ${SENTRY_VERSION}.tar.gz -C .
ln -s self-hosted-${SENTRY_VERSION} sentry
cd sentry
./install.sh

# 先安装，再更新配置，避免替换 system.secret-key

# 优化源
vim jq/sources.list

deb http://mirrors.aliyun.com/debian/ bookworm main contrib non-free
deb-src https://mirrors.aliyun.com/debian/ bookworm main contrib non-free

deb https://mirrors.aliyun.com/debian-security/ bookworm-security main contrib non-free
deb-src https://mirrors.aliyun.com/debian-security/ bookworm-security main contrib non-free

deb https://mirrors.aliyun.com/debian/ bookworm-updates main contrib non-free
deb-src https://mirrors.aliyun.com/debian/ bookworm-updates main contrib non-free


cp jq/sources.list cron/ 
cp jq/sources.list workstation/

COPY sources.list /etc/apt/sources.list
```



## 三、扩展

```bash
# .env 文件
COMPOSE_PROJECT_NAME=sentry-self-hosted
SENTRY_EVENT_RETENTION_DAYS=90
# You can either use a port number or an IP:PORT combo for SENTRY_BIND
# See https://docs.docker.com/compose/compose-file/#ports for more
SENTRY_BIND=9000
# Set SENTRY_MAIL_HOST to a valid FQDN (host/domain name) to be able to send emails!
# SENTRY_MAIL_HOST=example.com
SENTRY_IMAGE=getsentry/sentry:nightly
SNUBA_IMAGE=getsentry/snuba:nightly
RELAY_IMAGE=getsentry/relay:nightly
SYMBOLICATOR_IMAGE=getsentry/symbolicator:nightly
VROOM_IMAGE=getsentry/vroom:nightly
WAL2JSON_VERSION=latest
HEALTHCHECK_INTERVAL=30s
HEALTHCHECK_TIMEOUT=1m30s
HEALTHCHECK_RETRIES=10
```



## 四、问题

```bash
# 配置
https://sentry.8ops.top/manage/settings/

# 1. root
# 2. security
# 3. limit

# config.yml，若修改配置文件，则页面无法修改
system.url-prefix: 'https://sentry.8ops.top'
system.event-retention-days: '7'

docker exec -it sentry-self-hosted_worker_1 bash
sentry cleanup --days 7

docker exec -it sentry-self-hosted_postgres_1 bash
vacuumdb -U postgres -d postgres -v -f --analyze

```

### 4.1 官方设置方案

修改 .env文件的以下配置

```javascript
SENTRY_EVENT_RETENTION_DAYS=7
```



### 4.2 SENTRY数据软清理

```javascript
#登录worker容器
docker exec -it sentry_onpremise_worker_1 /bin/bash 

#保留多少天的数据，cleanup使用delete命令删除postgresql数据，但对于delete,update等操作，只是将对应行标志为DEAD，并没有真正释放磁盘空间
sentry cleanup --days 7
```



### 4.3 POSTGRES数据清理

```javascript
#登录postgres容器
docker exec -it sentry_onpremise_postgres_1 /bin/bash
#运行清理
vacuumdb -U postgres -d postgres -v -f --analyze
```



### 4. 定时清理脚本参考

```javascript
0 1 * * * cd /root/onpremise && { time docker-compose run --rm worker cleanup --days 7; } &> /var/log/sentry-cleanup.log

0 8 * * * { time docker exec -i $(docker ps --format "table {{.Names}}"|grep postgres) vacuumdb -U postgres -d postgres -v -f --analyze; } &> /var/logs/sentry-vacuumdb.log
```



### 4.5 清理kafka磁盘占用

清理kafka占用磁盘过大的问题搜到可以配置 .env，如下:

```javascript
KAFKA_LOG_RETENTION_HOURS=24
KAFKA_LOG_RETENTION_BYTES=53687091200   #50G
KAFKA_LOG_SEGMENT_BYTES=1073741824      #1G
KAFKA_LOG_RETENTION_CHECK_INTERVAL_MS=300000
KAFKA_LOG_SEGMENT_DELETE_DELAY_MS=60000
```



### 4.6 占满100%处理

如果已经占满100%，可以先去查找筛选出磁盘上其他占用很大的无用文件或者日志等，释放出一部分空间。
