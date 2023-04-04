# 实战 | Harbor使用





下载最新的 harbor-offline-installer-vx.x.x.tgz 版本

编辑配置

```bash
# cp harbor.yml.tmpl harbor.yml
# vim harbor.yml

……
hostname: reg.mydomain.com
……
https:
  port: 443
  certificate: /your/certificate/path
  private_key: /your/private/key/path  
……

data_volume: /data

……
metric:
  enabled: true
  port: 9090
  path: /metrics

```

预处理

```bash
# ./prepare --with-notary --with-trivy --with-chartmuseum
./install.sh --with-notary --with-trivy --with-chartmuseum
```

