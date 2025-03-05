# rsyncd

## 一、server

```bash
apt install rsync
yum install rsync 

cat > /etc/rsyncd.conf <<EOF
# /etc/rsyncd: configuration file for rsync daemon mode

# See rsyncd.conf man page for more options.

# configuration example:

uid = nobody
gid = nobody
use chroot = yes
max connections = 10
pid file = /var/run/rsyncd.pid
# exclude = lost+found/
# transfer logging = yes
timeout = 900
# ignore nonreadable = yes
dont compress   = *.gz *.tgz *.zip *.z *.Z *.rpm *.deb *.bz2
read only = yes

[backup]
    path = /data/backup
    uid = nobody
    gid = nobody
    use chroot = no
    read only = no
    auth users = sync
    secrets file = /etc/rsyncd/rsyncd.secrets
    hosts allow = 192.168.1.0/24,192.168.2.0/24
    hosts deny = *
    comment = finclip backup

EOF

cat >/etc/rsyncd/rsyncd.secrets <<EOF
sync:jesse
EOF
chmod 600 /etc/rsyncd/rsyncd.secrets

systemctl daemon-reload
systemctl enable rsyncd
systemctl start  rsyncd
systemctl status rsyncd
```



## 二、client

```bash
RSYNC_PASSWORD=jesse \
  /usr/bin/rsync \
  --bwlimit=4000 \
  -av \
  --delete \
  --exclude-from=/opt/scripts/sync.exclude sync@10.1.9.174::filestorage/ /data1/filestorage/

OR

/usr/bin/rsync \
  --bwlimit=4000 \
  -av \
  --delete \
  --password-file=/opt/scripts/sync.password \
  --exclude-from=/opt/scripts/sync.exclude sync@10.1.9.174::filestorage/ /data1/filestorage/

cat > /opt/scripts/sync.password <<EOF
jesse
EOF
chmod 600 /opt/scripts/sync.password

cat > /lib/systemd/system/sync-filestorage.service <<EOF
[Unit]
Description=Sync filestorage
ConditionPathExists=/opt/scripts/sync.password

[Service]
ExecStart=/opt/scripts/sync_filestorage.sh
RestartSec=10
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start sync-filestorage
systemctl enable sync-filestorage
systemctl status sync-filestorage
```



```bash
cat > /lib/systemd/system/filestorage.service <<EOF
[Unit]
Description=filestorage server daemon
Documentation=
After=network.target
Wants=

[Service]
Type=simple
ExecStart=/data1/go/bin/filestorage_run -listenAddr 0.0.0.0:18080 -rootPath /data1/filestorage
KillMode=process
Restart=on-failure
RestartSec=42s

[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reload
systemctl start  filestorage
systemctl enable filestorage
systemctl status filestorage
```



> 快捷使用

```bash
# view √
RSYNC_PASSWORD=jesse rsync -av --list-only sync@10.101.11.236::share/
RSYNC_PASSWORD=jesse rsync -av --list-only share/ sync@10.101.11.236::share/

# put √
RSYNC_PASSWORD=jesse rsync -av --list-only share/ sync@10.101.11.236::share/
rsync -av --list-only --password-file=sync.password share/ sync@10.101.11.236::share/
```



## 三、问题

### 3.1 报权限问题

```bash
# 现象
[rsync报错：rsync: chgrp “.initial-setup-ks.cfg.jaXlVz” (in backup) failed: Operation not permitted (1)]

# 解决
# 将 rsync -av source/ sync@addr::target/ 变更
# 为 rsync -rtlv source/ sync@addr::target/
# 是因为 -a 拥有归档功能
# 另需要修复target目录的权限，此前操作会将权限变更
#
# OR
#
# rsync -av --no-o --no-g source/ sync@addr::target/


```

