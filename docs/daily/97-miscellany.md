# 随记

## HTML

> 页面跳转

```html
<meta http-equiv="refresh" content="0; url=https://www.8ops.top/" />
```



## SHELL

> 发送邮件

```bash
# 说明
# -f 表示from，发件人地址
# -t 表示to，收件人地址
# -s mail服务器域名
# -u 主题
# -xu 用户名（@之前的）
# -xp 用户密码
# -m 纯文本信息
# -o message-file=/root/.. 发送文件中的内容
# -a 发送附件 （-m,-o,-a可以同时使用）

# 普通发送
 /usr/local/bin/sendEmail \
  -f xx@126.com \
  -t "to" \
  -cc "cc" \
  -u "subject" \
  -m "message" \
  -s smtp.126.com \
  -q \
  -xu xx@126.com \
  -xp pass 

# 发送html
cat datafile | \
  /usr/local/bin/sendEmail \
  -f xx@126.com \
  -t "to" \
  -cc "cc" \
  -u "subject" \
  -s smtp.126.com \
  -q \
  -xu youja_autosend@126.com \
  -xp uplus510 \
  -a $datafile \
  -o message-charset=utf8 \
  -o message-content-type=html 
```



## HADOOP

常用开源产品

1. `cdh`
2. `anbari`

