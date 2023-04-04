# rsyncd

## 一、server

```bash
apt install rsync
yum install rsync 

cat > /etc/rsyncd.conf <<EOF
# /etc/rsyncd: configuration file for rsync daemon mode

# See rsyncd.conf man page for more options.

# configuration example:

uid = 0
gid = 0
use chroot = yes
max connections = 10
pid file = /var/run/rsyncd.pid
# exclude = lost+found/
# transfer logging = yes
# timeout = 900
# ignore nonreadable = yes
# dont compress   = *.gz *.tgz *.zip *.z *.Z *.rpm *.deb *.bz2
read only = yes

[filestorage]
       path = /data1/filestorage
       auth users = sync
       secrets file = /etc/rsyncd/rsyncd.secrets
       comment = filestorage dir

EOF

cat >/etc/rsyncd/rsyncd.secrets <<EOF
sync:jesse
EOF
chmod 600 /etc/rsyncd/rsyncd.secrets

systemctl daemon-reload
systemctl enable rsync
systemctl start  rsync
systemctl status rsync
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

