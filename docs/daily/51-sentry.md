# sentry

[Reference](https://github.com/getsentry/self-hosted)



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

cd /usr/local
SENTRY_VERSION=23.5.1
wget https://github.com/getsentry/self-hosted/archive/refs/tags/${SENTRY_VERSION}.tar.gz
tar xzf ${SENTRY_VERSION}.tar.gz -C .
ln -s self-hosted-${SENTRY_VERSION} sentry
cd sentry
./install.sh

```

