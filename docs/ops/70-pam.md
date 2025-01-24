# PAM

[Reference](https://clearsky.me/vaultwarden/)



## 一、安装

```bash

Bitwarden


Vaultwarden

# Reference
https://github.com/dani-garcia/vaultwarden
https://hub.docker.com/r/vaultwarden/server
https://github.com/dani-garcia/vaultwarden/wiki
https://bitwarden.com/download/

# Sample
docker pull vaultwarden/server:latest
docker run -d --name vaultwarden -v ./vw-data/:/data/ --restart unless-stopped -p 8087:80 vaultwarden/server:latest

# Explain
docker pull vaultwarden/server:1.32.7
docker run -d --name vaultwarden --restart unless-stopped \
  -v ./vaultwarden/:/data/ \
  -p 18080:80 \
  -e SIGNUPS_ALLOWED=false \#禁用新用户注册
  -e INVITATIONS_ALLOWED=false \#禁用邀请
  -e ADMIN_TOKEN=xx \#openssl rand -base64 48
  vaultwarden/server:1.32.7

# ENVS
https://github.com/dani-garcia/vaultwarden/blob/main/.env.template

# Example
cat > .vaultwarden.env <<EOF
# signups disable 
SIGNUPS_ALLOWED=false

# invitations disable 
INVITATIONS_ALLOWED=false

# admin enable（TOKEN不能加引号，否则界面输入后识别不出来）
ADMIN_TOKEN=Dxn0bNfpSbTF2BVR7rwsn92rfV5lxtocnfiesVAQICHRWLR1tXE0rzU0Q28Xe626

# enable events logging
ORG_EVENTS_ENABLED=true
EOF

touch .vaultwarden.env
docker run -d --name vaultwarden --restart unless-stopped \
  -v /data1/lib/vw-data/:/data/ \
  -p 18080:80 \
  --env-file=.vaultwarden.env \
  vaultwarden/server:1.32.7

# Detect
docker top vaultwarden
docker logs -f vaultwarden

# Reset
docker stop vaultwarden
docker rm vaultwarden

```

## 二、使用

### 2.1 插件

`chrome://extensions/`

插件名称：Bitwarden



### 2.2 SMTP

```bash
# Reverse Proxy, enable ssl <required>
https://valutwanden.8ops.top/admin

# settings
SMTP_HOST=smtp.exmail.qq.com
SMTP_FROM=vaultwarden@8ops.top
SMTP_FROM_NAME=Vaultwarden
SMTP_USERNAME=vaultwarden@8ops.top
SMTP_PASSWORD=xx
SMTP_TIMEOUT=15
SMTP_SECURITY=force_tls
SMTP_PORT=465

```





## !! TODO

```bash
1，普通使用
2，插件使用：Vaultwarden Chrome extents: Bitwarden
3，SSO登录
4，配置邮箱
5，注册账号

```



