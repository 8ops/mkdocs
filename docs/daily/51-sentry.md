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
SENTRY_VERSION=23.5.1
wget https://github.com/getsentry/self-hosted/archive/refs/tags/${SENTRY_VERSION}.tar.gz
tar xzf ${SENTRY_VERSION}.tar.gz -C .
ln -s self-hosted-${SENTRY_VERSION} sentry
cd sentry
./install.sh

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

