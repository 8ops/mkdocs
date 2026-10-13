# Harbor

## 一、安装

### 1.1 下载

下载最新的 harbor-offline-installer-vx.x.x.tgz 版本

### 1.2 编辑配置

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

### 1.3 预处理

```bash
./prepare --with-notary --with-trivy --with-chartmuseum
./install.sh --with-notary --with-trivy --with-chartmuseum
```

### 1.4 安装

```bash
docker-compose up -d
```



## 二、常见问题

### 2.1  低版本兼容

当docker升级后，会遇到低版本harbor-offline的兼容性。

```bash
# 依赖 docker-compose 工具
curl -L https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m) \
  -o /usr/local/bin/docker-compose

chmod +x /usr/local/bin/docker-compose

# 实测：
# 1. ubuntu 可以源安装
# 2. centos 无法源安装，可通过curl二进制
# 3. aliyun cloud linux 无法源安装，可通过curl二进制
```

### 2.2 更新域名证书

```bash
# harbor仅重启nginx
docker-compose restart proxy # nginx
```

