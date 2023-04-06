# Harbor



## 一、下载

下载最新的 harbor-offline-installer-vx.x.x.tgz 版本

## 二、编辑配置

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

## 三、预处理

```bash
# ./prepare --with-notary --with-trivy --with-chartmuseum
./install.sh --with-notary --with-trivy --with-chartmuseum
```

## 四、安装

```bash
docker-compose up -d
```

