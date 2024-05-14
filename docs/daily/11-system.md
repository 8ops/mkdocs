# 系统管理

 

## 一、常用操作

```bash
# 获取 linux 操作系统的位数 
getconf LONG_BIT

# 生成密码
openssl rand -base64 20
openssl rand -hex 20

```



### 1.1 ulimit

```bash
# 系统缺省
cat >> /etc/security/limits.conf << EOF

* soft nofile 65536
* hard nofile 65536
* hard nproc 4096
* soft nproc 4096
EOF

cat > /etc/security/limits.d/90-nproc.conf << EOF
* soft    nproc     4096
EOF

ulimit -SHn 65535

# systemd 缺省
cat >> /etc/systemd/system.conf <<EOF
DefaultLimitNOFILE=65535
DefaultLimitNPROC=4096
EOF

cat >> /etc/systemd/user.conf <<EOF
DefaultLimitNOFILE=65535
DefaultLimitNPROC=4096
EOF

systemctl daemon-reexec
```





## 二、用户

```bash
# 添加用户
useradd jesse

# 添加到sudoer
# user01	ALL=(ALL) 	ALL # sudo -s 需要密码切换
# user02   ALL=(ALL)       NOPASSWD:ALL # 免密切换
jesse	ALL=(ALL) 	ALL


```



## 三、SSH

```bash
ssh -i hostname -l username
Unable to negotiate with 10.101.11.200 port 222: no matching host key type found. Their offer: ssh-rsa,ssh-dss

ssh -V
OpenSSH_9.0p1, LibreSSL 3.3.6

# 需要降级加密算法
~/.ssh/config
HostKeyAlgorithms +ssh-rsa
PubkeyAcceptedKeyTypes +ssh-rsa
```



### 3.1 ProxyCommand

`~/.ssh/config`

```bash
Host jump
    HostName 10.10.10.10
    Port 22
    User root
    IdentityFile ~/.ssh/id_rsa

Host 10.10.10.*
    Port 22
    User root
    IdentityFile ~/.ssh/id_rsa
    ProxyCommand ssh jump -W %h:%p
```

**ProxyJump**

```bash
$ ssh jump
$ ssh 10.10.10.100
```



## 四、VIM

### 4.1 语法高亮

```bash
# 查看colorscheme
ls /usr/share/vim/vim*/colors/ ~/.vim/colors
/usr/share/vim/vim90/colors:
README.txt     default.vim    elflord.vim darkblue.vim

~/.vim/colors:
solarized.vim

# vim /usr/share/vim/vimrc 
vim ~/.vimrc
syntax enable
set background=dark
colorscheme darkblue
set ruler
```



## 五、cockpit

用于 CentOS 8 的 Web 界面

```bash
systemctl start cockpit.socket   # 运行Cockpit服务

systemctl enable cockpit.socket  # 启动该服务，随系统启动一同启动

*:9090
```



## 六、SHELL

### 6.1 发送邮件

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
  -xu xx@126.com \
  -xp xx \
  -a $datafile \
  -o message-charset=utf8 \
  -o message-content-type=html 
```



### 6.2 getopts

```bash
#!/bin/bash

echo "[$OPTIND] [$#] [$*]"

while getopts ":a:bc:" opt
do
case $opt in
  a)
    echo "OUTPUT A[$OPTIND][$OPTARG]"
    ;;
  b)
    echo "OUTPUT B[$OPTIND][$OPTARG]"
    ;;
  c)
    echo "OUTPUT C[$OPTIND][$OPTARG]"
    ;;
  *)
    echo "OUTPUT *[$OPTIND][$OPTARG]"
    ;;
esac
done

shift $(($OPTIND-1))
echo "[$#] [$*]"
```

<u>debug</u>

```bash
$ ./getopts.sh
[1] [0] []
[0] []

$ ./getopts.sh -a
[1] [1] [-a]
OUTPUT *[2][a]
[0] []

$ ./getopts.sh -a a
[1] [2] [-a a]
OUTPUT A[3][a]
[0] []

$ ./getopts.sh -a a -b
[1] [3] [-a a -b]
OUTPUT A[3][a]
OUTPUT B[4][]
[0] []

$ ./getopts.sh -a a -b -c c
[1] [5] [-a a -b -c c]
OUTPUT A[3][a]
OUTPUT B[4][]
OUTPUT C[6][c]
[0] []

$ ./getopts.sh -a a -b -c c xyz
[1] [6] [-a a -b -c c xyz]
OUTPUT A[3][a]
OUTPUT B[4][]
OUTPUT C[6][c]
[1] [xyz]
```

