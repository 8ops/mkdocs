# cloudstack

虚拟机管理

## cloudstack

[Reference](https://cloudstack.apache.org)

```bash
docker run --name cloudstack-simulator -p 5050:5050 \
  -d apache/cloudstack-simulator:4.18.1.0

docker run --name cloudstack-simulator -p 5050:5050 \
  -d apache/cloudstack-simulator:4.23.0.0

docker run --name cloudstack-simulator -p 5050:5050 \
  -d apache/cloudstack-simulator:latest

cloudstack
admin:password

```



## oVirt

ovirt-engine

```bash
hostnamectl set-hostname ovirt.8ops.top
echo "10.101.9.179  ovirt.8ops.top" >> /etc/hosts

wget -O /etc/yum.repos.d/ovirt-4.0.repo https://resources.ovirt.org/pub/yum-repo/ovirt-release40.rpm
yum repolist
yum install ovirt-engine -y # 因网络会花很长时间

engine-setup
# 一直 Yes，以下三点注意
# FQDN: ovirt.8ops.top
# firewalld: No
# week password: 忽略

# 浏览器访问 https://ovirt.8ops.top
# 报 No appropriate protocol (protocol is disabled or cipher suites are inappropriate)
vim /usr/lib/jvm/java-1.8.0-openjdk-1.8.0.412.b08-1.el7_9.x86_64/jre/lib/security/java.security
jdk.tls.disabledAlgorithms=SSLv3, TLSv1, TLSv1.1, RC4, DES, MD5withRSA, \
    DH keySize < 1024, EC keySize < 224, 3DES_EDE_CBC, anon, NULL, \
    include jdk.disabled.namedCurves
# to
jdk.tls.disabledAlgorithms=RC4, DES, MD5withRSA, \
    DH keySize < 1024, EC keySize < 224, 3DES_EDE_CBC, anon, NULL, \
    include jdk.disabled.namedCurves  
    
systemctl restart ovirt-engine
systemctl restart httpd


```



