# Denyhosts

[Reference](https://pypi.org/project/DenyHosts/)

## 一、目录说明

该目录中主要存放计划任务，日志压缩 以及 chkconfig 和 service 启动的文档 

```bash
/etc/cron.d/denyhosts 
/etc/denyhosts.conf 
/etc/logrotate.d/denyhosts 
/etc/rc.d/init.d/denyhosts 
/etc/sysconfig/denyhosts 
```



该目录中主要存放 denyhosts 所拒绝及允许的一些主机信息 

```bash
/var/lib/denyhosts/allowed-hosts 
/var/lib/denyhosts/allowed-warned-hosts 
/var/lib/denyhosts/hosts 
/var/lib/denyhosts/hosts-restricted 
/var/lib/denyhosts/hosts-root 
/var/lib/denyhosts/hosts-valid 
/var/lib/denyhosts/offset 
/var/lib/denyhosts/suspicious-logins 
/var/lib/denyhosts/sync-hosts 
/var/lib/denyhosts/users-hosts 
/var/lib/denyhosts/users-invalid 
/var/lib/denyhosts/users-valid 
/var/log/denyhosts 
```



## 二、配置参数 

`/etc/denyhosts.conf`

```bash
 ~ # egrep -v "(^$|^#)" /etc/denyhosts.conf 
############ THESE SETTINGS ARE REQUIRED ############ 
# 系统安全日志文件，主要获取ssh信息 
SECURE_LOG = /var/log/secure 
# 拒绝写入IP文件 hosts.deny 
HOSTS_DENY = /etc/hosts.deny 
# #过多久后清除已经禁止的，其中w代表周，d代表天，h代表小时，s代表秒，m代表分钟 
PURGE_DENY = 4w 
# denyhosts所要阻止的服务名称 
BLOCK_SERVICE  = sshd 
# 允许无效用户登录失败的次数 
DENY_THRESHOLD_INVALID = 3 
# 允许普通用户登录失败的次数 
DENY_THRESHOLD_VALID = 10 
# 允许ROOT用户登录失败的次数 
DENY_THRESHOLD_ROOT = 6 
# 设定 deny host 写入到该资料夹 
DENY_THRESHOLD_RESTRICTED = 1 
# 将deny的host或ip纪录到Work_dir中 
WORK_DIR = /var/lib/denyhosts 
SUSPICIOUS_LOGIN_REPORT_ALLOWED_HOSTS=YES 
# 是否做域名反解 
HOSTNAME_LOOKUP=YES 
# 将DenyHOts启动的pid纪录到LOCK_FILE中，已确保服务正确启动，防止同时启动多个服务 
LOCK_FILE = /var/lock/subsys/denyhosts 

       ############ THESE SETTINGS ARE OPTIONAL ############ 
# 管理员Mail地址 
ADMIN_EMAIL = root 
SMTP_HOST = localhost 
SMTP_PORT = 25 
SMTP_FROM = DenyHosts nobody@localhost 
SMTP_SUBJECT = DenyHosts Report from $[HOSTNAME] 

# 有效用户登录失败计数归零的时间 
AGE_RESET_VALID=5d 
# ROOT用户登录失败计数归零的时间 
AGE_RESET_ROOT=25d 

# 用户的失败登录计数重置为0的时间(/usr/share/denyhosts/restricted-usernames) 
AGE_RESET_RESTRICTED=25d 

# 无效用户登录失败计数归零的时间 
AGE_RESET_INVALID=10d 

  ######### THESE SETTINGS ARE SPECIFIC TO DAEMON MODE  ########## 
# denyhosts log文件 
DAEMON_LOG = /var/log/denyhosts 
DAEMON_SLEEP = 30s 
# 该项与PURGE_DENY 设置成一样，也是清除hosts.deniedssh 用户的时间 
DAEMON_PURGE = 1h 
```





## 四、启动服务

服务并查看状态 

## 五、通过测试

 ```bash
 # invalid、valid、root 等用户设置不同的ssh连接失败次数，来测试 denyhosts ，我这边只测试使用系统中不存在的用户进行失败登录尝试~ 
 # 我们允许 invalid 用户只能失败4次、ROOT 用户失败7次、valid用户失败10次 
 
 DENY_THRESHOLD_INVALID = 4 
 DENY_THRESHOLD_VALID = 10 
 DENY_THRESHOLD_ROOT = 7 
 
 # 测试：使用一个没有创建的用户失败登录四次，并查看 /etc/hosts.deny 
 
 echo -n ""  > /var/log/secure 
 tail -f /var/log/secure 
 tail -f /etc/hosts.deny 
 
 /var/log/secure # 日志信息： 
 /etc/hosts.deny # 信息： 
 # 用户登录信息： 
 ```



## 六、维护管理

- 关于清除
- 添加可信主机记录 

如果想删除一个已经禁止的主机IP，只在 /etc/hosts.deny 删除是没用的。需要进入 /var/lib/denyhosts 目录，进入以下操作： 

1. 停止DenyHosts服务：service denyhosts stop 

2. 在 /etc/hosts.deny 中删除你想取消的主机IP 

3. 编辑 DenyHosts 工作目录的所有文件 /var/lib/denyhosts，并且删除已被添加的主机信息。 

```bash
/var/lib/denyhosts/hosts 
/var/lib/denyhosts/hosts-restricted 
/var/lib/denyhosts/hosts-root 
/var/lib/denyhosts/hosts-valid 
/var/lib/denyhosts/users-hosts 
/var/lib/denyhosts/users-invalid 
/var/lib/denyhosts/users-valid 
```



4. 添加你想允许的主机IP地址到 

`/var/lib/denyhosts/allowed-hosts `

5. 启动DenyHosts服务： service denyhosts start 

```bash
#! /bin/bash

clean(){
    echo "try clean $ip is denyhost info"    
    sed -i '/'$ip'/d' /usr/share/denyhosts/data/hosts
    sed -i '/'$ip'/d' /usr/share/denyhosts/data/hosts-root
    sed -i '/'$ip'/d' /usr/share/denyhosts/data/hosts-valid
    sed -i '/'$ip'/d' /usr/share/denyhosts/data/hosts-restricted
    sed -i '/'$ip'/d' /usr/share/denyhosts/data/users-hosts
    sed -i '/'$ip'/d' /etc/hosts.deny

}
```



## 七、发送信息 

通过邮件接收 denyhosts 所

1. 修改 /etc/denyhosts.conf 配置档，并重启 denyhosts 服务 

```bash
ADMIN_EMAIL = xx 
SMTP_HOST = mail.server.com 
SMTP_PORT = 25 
SMTP_FROM = DenyHosts <xx>
```

2. 通过其他客户端进行多次失败登录尝试 