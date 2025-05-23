# firewall

## 一、iptables

## 二、firewall-cmd

```bash
# 查看设置
firewall-cmd --state  # 显示状态
firewall-cmd --get-active-zones  # 查看区域信息
firewall-cmd --get-zone-of-interface=eth0  # 查看指定接口所属区域
firewall-cmd --panic-on  # 拒绝所有包
firewall-cmd --panic-off  # 取消拒绝状态
firewall-cmd --query-panic  # 查看是否拒绝
firewall-cmd --runtime-to-permanent # 将当前防火墙的规则永久保存；

firewall-cmd --reload # 更新防火墙规则
firewall-cmd --complete-reload
# 两者的区别就是第一个无需断开连接，就是firewalld特性之一动态添加规则，第二个需要断开连接，类似重启服务

# 将接口添加到区域，默认接口都在public
firewall-cmd --zone=public --add-interface=eth0
# 永久生效再加上 --permanent 然后reload防火墙
 
# 设置默认接口区域，立即生效无需重启
firewall-cmd --set-default-zone=public

# 查看所有打开的端口：
firewall-cmd --zone=dmz --list-ports

# 加入一个端口到区域：
firewall-cmd --zone=dmz --add-port=8080/tcp
# 若要永久生效方法同上
 
# 打开一个服务，类似于将端口可视化，服务需要在配置文件中添加，/etc/firewalld 目录下有services文件夹，这个不详细说了，详情参考文档
firewall-cmd --zone=work --add-service=smtp
 
# 移除服务
firewall-cmd --zone=work --remove-service=smtp

# 显示支持的区域列表
firewall-cmd --get-zones

# 设置为家庭区域
firewall-cmd --set-default-zone=home

# 查看当前区域
firewall-cmd --get-active-zones

# 设置当前区域的接口
firewall-cmd --get-zone-of-interface=enp03s

# 显示所有公共区域（public）
firewall-cmd --zone=public --list-all

# 临时修改网络接口（enp0s3）为内部区域（internal）
firewall-cmd --zone=internal --change-interface=enp03s

# 永久修改网络接口enp03s为内部区域（internal）
firewall-cmd --permanent --zone=internal --change-interface=enp03s

# 显示服务列表  
Amanda, FTP, Samba和TFTP等最重要的服务已经被FirewallD提供相应的服务，可以使用如下命令查看：

firewall-cmd --get-services

# 允许SSH服务通过
firewall-cmd --new-service=ssh

# 禁止SSH服务通过
firewall-cmd --delete-service=ssh

# 打开TCP的8080端口
firewall-cmd --enable ports=8080/tcp

# 临时允许Samba服务通过600秒
firewall-cmd --enable service=samba --timeout=600

# 显示当前服务
firewall-cmd --list-services

# 添加HTTP服务到内部区域（internal）
firewall-cmd --permanent --zone=internal --add-service=http
firewall-cmd --reload     # 在不改变状态的条件下重新加载防火墙

# 打开443/TCP端口
firewall-cmd --add-port=443/tcp

# 永久打开3690/TCP端口
firewall-cmd --permanent --add-port=3690/tcp

# 永久打开端口好像需要reload一下，临时打开好像不用，如果用了reload临时打开的端口就失效了
# 其它服务也可能是这样的，这个没有测试
firewall-cmd --reload

# 查看防火墙，添加的端口也可以看到
firewall-cmd --list-all

# FirewallD包括一种直接模式，使用它可以完成一些工作，例如打开TCP协议的9999端口
firewall-cmd --direct -add-rule ipv4 filter INPUT 0 -p tcp --dport 9000 -j ACCEPT

```

> Example

```bash
firewall-cmd --zone=internal --add-source=10.1.2.0/24 --permanent
firewall-cmd --reload
firewall-cmd --zone=internal --list-all

firewall-cmd --zone=internal --add-masquerade

telnet 10.1.2.51 22

```



## 三、ufw

出现在ubuntu操作系统

```bash
sudo apt update && sudo apt install ufw  # Debian/Ubuntu

sudo ufw enable   # 启用（开机自启）
sudo ufw disable  # 禁用
sudo ufw reset    # 重置所有规则

sudo ufw status verbose  # 查看规则（详细模式）
sudo ufw status numbered # 带编号的规则列表

sudo ufw allow 22/tcp       # 允许TCP 22端口（SSH）
sudo ufw deny 80/tcp        # 拒绝TCP 80端口
sudo ufw allow from 192.168.1.100  # 允许特定IP
sudo ufw deny from 10.0.0.0/24     # 拒绝子网

sudo ufw allow ssh    # 等价于 allow 22/tcp
sudo ufw allow http   # 等价于 allow 80/tcp
sudo ufw allow https  # 等价于 allow 443/tcp

sudo ufw delete allow 22/tcp  # 按规则删除
sudo ufw delete 3             # 按编号删除（需先status numbered）

sudo ufw allow proto tcp from 192.168.1.0/24 to any port 22-25  # 允许子网访问22-25端口
sudo ufw allow proto udp 53    # 允许UDP 53（DNS）

sudo ufw limit ssh  # 限制SSH连接尝试（默认6次/30秒）

sudo ufw deny out 25  # 禁止出站SMTP
sudo ufw allow out 53 # 允许出站DNS

# 启用IP转发
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# 配置转发（例：将80端口转发到内网192.168.1.2）
sudo ufw route allow proto tcp from any to 192.168.1.2 port 80
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination 192.168.1.2:80

sudo nano /etc/default/ufw
# 修改 IPV6=yes 后重启
sudo ufw disable && sudo ufw enable

sudo ufw logging on   # 开启日志（默认/var/log/ufw.log）
sudo ufw logging off  # 关闭日志
tail -f /var/log/ufw.log  # 实时查看日志

sudo ufw reload  # 重载规则

sudo ufw reset && sudo ufw enable

sudo ufw default deny incoming  # 默认拒绝所有入站
sudo ufw default allow outgoing # 默认允许所有出站
sudo ufw allow ssh              # 放行SSH
sudo ufw limit ssh              # 启用SSH速率限制
sudo ufw allow 80/tcp           # 放行HTTP
sudo ufw enable
```





