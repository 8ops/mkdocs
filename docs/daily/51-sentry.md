# sentry

[Reference](https://github.com/getsentry/self-hosted)



```bash
# 参考版本 23.5.1

# 先确认是否支持 SSE4.2
grep -i sse4 /proc/cpuinfo 

wget https://github.com/getsentry/self-hosted/archive/refs/tags/23.5.1.tar.gz
tar xzf 23.5.1.tar.gz
cd self-hosted-23.5.1
./install.sh

# config geoip
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
mail.username: 'sentry@8ops.tpo'
mail.password: 'xxxxxx'
mail.use-tls: true
mail.use-ssl: false
mail.from: 'Sentry <sentry-noreplay@8ops.top>'
...

```

