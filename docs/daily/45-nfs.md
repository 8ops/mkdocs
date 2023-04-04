# NFS

## 一、安装

<u>CentOS</u>

```bash
# Server[CentOS]
mkdir -p /data1/lib/nfs-data
chown -R nfsnobody:nfsnobody /data1/lib/nfs-data

yum install rpcbind nfs-utils 

vim /etc/exports
/data1/lib/nfs-data 10.101.0.0/16(no_root_squash,rw,async,no_subtree_check)

# 使配置生效
exportfs -a

systemctl start rpcbind nfs-utils nfs
systemctl enable rpcbind nfs-utils nfs
systemctl is-enabled rpcbind nfs-utils nfs
systemctl status rpcbind nfs-utils nfs

showmount -e 10.101.11.236 

systemctl restart rpcbind nfs-utils nfs
systemctl status  rpcbind nfs-utils nfs

showmount -e 10.101.9.179

# Client [CentOS]
yum install nfs-utils 
mkdir -p /data1/lib/nfs-data
chown -R nobody:nogroup /data1/lib/nfs-data

vim /etc/fstab
10.101.9.179:/data1/lib/nfs-data /data1/lib/nfs-data nfs4 defaults 0 0

mount -a

mount -t nfs4 10.101.11.236:/data1/lib/nfs-data /data1/lib/nfs-data

rpcinfo -p 10.101.9.179
```

<u>Ubuntu</u>

```bash
# Server[Ubuntu]
mkdir -p /data1/lib/nfs
chown -R nobody:nogroup /data1/lib/nfs

apt install rpcbind libnfs-utils nfs-common
apt install nfs-kernel-server

vim /etc/exports
/opt/lib/nfs 10.101.0.0/16(no_root_squash,rw,async,no_subtree_check)

# 使配置生效
exportfs -a

systemctl start rpcbind nfs-utils nfs-kernel-server
systemctl enable rpcbind nfs-utils nfs-kernel-server
systemctl is-enabled rpcbind nfs-utils nfs-kernel-server
systemctl status rpcbind nfs-utils nfs-kernel-server

systemctl restart rpcbind nfs-utils nfs-kernel-server
systemctl status rpcbind nfs-utils nfs-kernel-server

showmount -e 10.101.11.236

# Client[Ubuntu]
apt install nfs-common
mkdir -p /opt/lib/nfs
chown -R nfsnobody:nfsnobody /data1/lib/nfs

vim /etc/fstab
10.101.11.236:/data1/lib/nfs /data1/lib/nfs nfs4 defaults 0 0

mount -a

mount -t nfs4 10.101.11.236:/data1/lib/nfs /data1/lib/nfs

rpcinfo -p 10.101.11.236
```

