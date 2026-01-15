# Cert-Manager

## 一、Self Root CA

[Reference](https://jamielinux.com/docs/openssl-certificate-authority/introduction.html)

### 1.1 Root CA

算法使用 RSA4096 或 SHA512 。

```bash
# 1，init
ROOT_DIR=/opt/ca/root
mkdir -p ${ROOT_DIR}

# 2，openssl.cnf
cat > ${ROOT_DIR}/openssl.cnf <<EOF
[ ca ]
default_ca  = CA_default

[ CA_default ]
dir             = ${ROOT_DIR}
certs           = \$dir/certs
crl_dir         = \$dir/crl
database        = \$dir/index.txt
new_certs_dir   = \$dir/newcerts
certificate     = \$dir/key/cacert.crt
serial          = \$dir/serial
crlnumber       = \$dir/crlnumber
crl             = \$dir/crl.pem
private_key     = \$dir/key/cakey.pem
RANDFILE        = \$dir/key/.rand
unique_subject  = no

x509_extensions = usr_cert
copy_extensions = copy

name_opt    = ca_default
cert_opt    = ca_default

default_days     = 36500 # 100 years
default_crl_days = 30
default_md       = sha512
preserve         = no
policy           = policy_ca

[ policy_ca ]
countryName             = supplied
stateOrProvinceName     = supplied
organizationName        = supplied
organizationalUnitName  = supplied
commonName              = supplied
emailAddress            = optional

[ req ]
default_bits        = 4096
default_keyfile     = privkey.pem
distinguished_name  = req_distinguished_name
attributes          = req_attributes
x509_extensions     = v3_ca
string_mask         = utf8only
utf8                = yes
prompt              = no

[ req_distinguished_name ]
countryName             = CN
stateOrProvinceName     = Shanghai
localityName            = Shanghai 
organizationName        = 8OPS Technology Co Ltd
organizationalUnitName  = 8OPS Root CA
commonName              = Global 8OPS Root CA

[ usr_cert ]
basicConstraints = CA:TRUE

[ v3_ca ]
basicConstraints        = critical, CA:TRUE
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always, issuer:always
keyUsage                = critical, cRLSign, digitalSignature, keyCertSign

[ v3_intermediate_ca ]
basicConstraints        = critical, CA:TRUE, pathlen:0 # Can not sign other CAs/ICAs if pathlen: is set to 0
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always, issuer:always
keyUsage                = critical, cRLSign, digitalSignature, keyCertSign  

[ req_attributes ]
EOF

# 3，create cakey.pem
mkdir -p ${ROOT_DIR}/newcerts ${ROOT_DIR}/key
touch ${ROOT_DIR}/index.txt ${ROOT_DIR}/index.txt.attr
echo 01 > ${ROOT_DIR}/serial
openssl genrsa -out ${ROOT_DIR}/key/cakey.pem 4096

# 4，create ca.csr
openssl req -new -key ${ROOT_DIR}/key/cakey.pem -out ${ROOT_DIR}/key/ca.csr \
  -config ${ROOT_DIR}/openssl.cnf

# 5，create cacert.crt
openssl ca -selfsign -in ${ROOT_DIR}/key/ca.csr -out ${ROOT_DIR}/key/cacert.crt \
  -config ${ROOT_DIR}/openssl.cnf -extensions v3_ca

# 6，view
openssl x509 -text -in ${ROOT_DIR}/key/cacert.crt

# 生成了根CA的相关证书和私钥，可以用于签发其他的CA（二级CA），不可签发服务器证书
```



### 1.2 Intermediate CA

此二级CA不能继续签发出三级CA。

```bash
# init
ROOT_DIR=/opt/ca/root
AGENT_DIR=/opt/ca/agent
mkdir -p ${AGENT_DIR}

# openssl.cnf
cat > ${AGENT_DIR}/openssl.cnf <<EOF
[ ca ]
default_ca  = CA_default

[ CA_default ]
dir             = ${AGENT_DIR}
certs           = \$dir/certs
crl_dir         = \$dir/crl
database        = \$dir/index.txt
new_certs_dir   = \$dir/newcerts
certificate     = \$dir/key/cacert.crt
serial          = \$dir/serial
crlnumber       = \$dir/crlnumber
crl             = \$dir/crl.pem
private_key     = \$dir/key/cakey.pem
RANDFILE        = \$dir/key/.rand
unique_subject  = no

x509_extensions = usr_cert
copy_extensions = copy

name_opt    = ca_default
cert_opt    = ca_default

default_days     = 3650 # 10 years
default_crl_days = 30
default_md       = sha512
preserve         = no
policy           = policy_ca

[ policy_ca ]
countryName             = supplied
stateOrProvinceName     = supplied
organizationName        = supplied
organizationalUnitName  = supplied
commonName              = supplied
emailAddress            = optional

[ req ]
default_bits        = 4096
default_keyfile     = privkey.pem
distinguished_name  = req_distinguished_name
attributes          = req_attributes
x509_extensions     = v3_ca
string_mask         = utf8only
utf8                = yes
prompt              = no

[ req_distinguished_name ]
countryName             = CN
stateOrProvinceName     = Shanghai 
localityName            = Shanghai
organizationName        = 8OPS Technology Co Ltd
organizationalUnitName  = IT Department
commonName              = GLOBAL 8OPS Intermediate CA X1

[ usr_cert ]
basicConstraints = CA:FALSE

[ v3_ca ]
basicConstraints        = critical, CA:FALSE
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always, issuer:always
keyUsage                = critical, nonRepudiation, digitalSignature, keyEncipherment, keyAgreement 
extendedKeyUsage        = critical, serverAuth

[ req_attributes ]

EOF

# 3，create dir
mkdir -p ${AGENT_DIR}/newcerts ${AGENT_DIR}/key
touch ${AGENT_DIR}/index.txt ${AGENT_DIR}/index.txt.attr
echo 01 > ${AGENT_DIR}/serial

# 4，create cakey.pem
openssl genrsa -out ${AGENT_DIR}/key/cakey.pem 4096

# 5，create ca.csr
openssl req -new -key ${AGENT_DIR}/key/cakey.pem -out ${AGENT_DIR}/key/ca.csr \
  -config /${AGENT_DIR}/openssl.cnf

# 6，create cacert.crt
openssl ca -in ${AGENT_DIR}/key/ca.csr -out ${AGENT_DIR}/key/cacert.crt \
  -days=3650 -md sha512  -config ${ROOT_DIR}/openssl.cnf \
  -extensions v3_intermediate_ca

# 7，view
openssl x509 -text -in ${AGENT_DIR}/key/cacert.crt

# 生成了一个二级CA，这个二级CA可以签发服务器证书（不能签发其他的CA）
```



### 1.3 签发域名证书

使用二级CA签发。

```bash
# init
DOMAIN=8ops.top
ROOT_DIR=/opt/ca/root
AGENT_DIR=/opt/ca/agent
DV_DIR=/opt/ca/8ops
mkdir -p ${DV_DIR} 

# openssl.cnf
cat > ${DV_DIR}/openssl.cnf <<EOF
[ req ]
prompt             = no
distinguished_name = server_distinguished_name
req_extensions     = req_ext
x509_extensions    = v3_req
attributes         = req_attributes

[ server_distinguished_name ]
stateOrProvinceName     = Shanghai
countryName             = CN
organizationName        = 8OPS Technology Co Ltd
organizationalUnitName  = IT Department
commonName              = 8OPS 8ops.top

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage         = nonRepudiation, digitalSignature, keyEncipherment

[ req_attributes ]

[ req_ext ]
subjectAltName   = @alternate_names

[ alternate_names ]
DNS.1 = ${DOMAIN}
DNS.2 = *.${DOMAIN}

EOF

# 3，create domain.key
openssl genrsa -out ${DV_DIR}/${DOMAIN}.key 4096

# 4，create domain.csr
openssl req -new -key ${DV_DIR}/${DOMAIN}.key -out ${DV_DIR}/${DOMAIN}.csr \
  -config ${DV_DIR}/openssl.cnf

# 5，create domain.crt
# 根据CA/B论坛规定单张证书最长有效期已缩短至398天（约13个月），并计划在2029年缩短至47天
openssl ca -in ${DV_DIR}/${DOMAIN}.csr -out ${DV_DIR}/${DOMAIN}.crt \
  -days=398 -config ${AGENT_DIR}/openssl.cnf -extensions v3_ca

# 6，merge domain.pem
cat ${DV_DIR}/${DOMAIN}.crt ${AGENT_DIR}/key/cacert.crt ${ROOT_DIR}/key/cacert.crt > ${DV_DIR}/${DOMAIN}.cer
cat ${DV_DIR}/${DOMAIN}.key ${DV_DIR}/${DOMAIN}.cer > ${DV_DIR}/${DOMAIN}.pem 

# 7，view
openssl x509 -text -in ${DV_DIR}/${DOMAIN}.pem

```



>  签发CA证书和终端证书区别

1. 生成证书请求文件的时候。可查看openssl.cnf中[req]字段中扩展字段是v3_req，在v3_req中有个basicConstraints变量。
   1. 当basicConstraints=CA:TRUE时，表明要生成的证书请求是CA证书请求文件；
   2. 当basicConstraints=CA:FALSE时，表明要生成的证书请求文件是终端证书请求文件。

2. 在签发终端证书的时候使用默认扩展字段usr_cert，当签发CA证书的时候再命令行使用了extensions选项指定v3_ca字段。
   1. 在默认的usr_cert字段中 basicConstraints=CA:FALSE，表明要签发终端证书；
   2. 在v3_ca字段中 basicConstraints=CA:TRUE，表明要签发CA证书。

CA和终端证书是有区别的，CA是用来颁发终端证书和签发二级CA的，且两者是互斥的。



## 二、Cert-Manager

[Reference](https://cert-manager.io/docs/configuration/ca/)

```bash
CERT_MANAGER_VERSION=v1.19.2
helm repo add jetstack https://charts.jetstack.io
helm repo update jetstack
helm search repo cert-manager

helm show values jetstack/cert-manager \
  --version=${CERT_MANAGER_VERSION} > cert-manager.yaml-${CERT_MANAGER_VERSION}-default

# Example 
#   https://books.8ops.top/attachment/cert-manager/helm/cert-manager.yaml-v1.9.1
#   https://books.8ops.top/attachment/cert-manager/helm/cert-manager.yaml-v1.11.0
#   https://books.8ops.top/attachment/cert-manager/helm/cert-manager.yaml-v1.19.2
#   

helm install cert-manager jetstack/cert-manager \
  -f cert-manager.yaml-${CERT_MANAGER_VERSION} \
  -n cert-manager \
  --create-namespace \
  --version ${CERT_MANAGER_VERSION}

helm -n cert-manager uninstall cert-manager
```



### 2.1 私有CA签发

[Reference](https://cert-manager.io/docs/usage/ingress/)

```bash
# Example
# https://books.8ops.top/attachment/cert-manager/70-selfsign-clusterissuer.yaml
#

# 1，ROOT CA
kubectl -n cert-manager create Secrets generic 8ops-root-ca-keypair \
  --from-file=tls.crt=8ops-ca.crt \
  --from-file=tls.key=8ops-ca.key
kubectl -n cert-manager get Secrets 8ops-root-ca-keypair

# 2，ClusterIssuer 可切换成 namespace+Issuer
kubectl apply -f - << EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: 8ops-root-ca-clusterissuer
spec:
  ca:
    secretName: 8ops-root-ca-keypair
    crlDistributionPoints: # 域名证书吊销列表
    - "http://crl.8ops.top"
EOF
kubectl get ClusterIssuer 8ops-root-ca-clusterissuer # clusterissuer 不区分命名空间

# 3，Ingress auto issue/此种方式会缺失CN/O/OU，区别于Webhook的方式会缺失O/OU
kubectl apply -f - << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    cert-manager.io/cluster-issuer: 8ops-root-ca-clusterissuer # 自动签发注解
  labels:
    app: ingress-selfsign-auto
  name: ingress-selfsign-auto
  namespace: default
spec:
  ingressClassName: external
  rules:
  - host: ingress-selfsign-auto.8ops.top
    http:
      paths:
      - backend:
          service:
            name: echoserver
            port:
              number: 8080
        path: /
        pathType: Prefix
  tls:
  - hosts:
    - 8ops.top
    - www.8ops.top
    - ingress-selfsign-auto.8ops.top
    - "*.8ops.top"
    secretName: tls-8ops.top-auto # 自动生成 secret 名称
EOF
kubectl -n default get Ingress ingress-selfsign-auto

# 4，wildcard-cert
kubectl apply -f - << EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: tls-8ops.top-wildcard
  namespace: default
spec:
  secretName: tls-8ops.top-wildcard # 显示声明secrets的名称
  issuerRef:
    name: 8ops-root-ca-clusterissuer
    kind: ClusterIssuer
  privateKey: # 显示声明Key的轮询方式
    algorithm: RSA
    size: 2048 # 建议 2048，4096 没必要
    rotationPolicy: Always
  subject:
    organizations:
      - 8OPS Technology Co Ltd
    organizationalUnits:
      - IT Department
    countries:
      - CN
    provinces:
      - Shanghai
    localities:
      - Shanghai
  commonName: "8ops.top" # 建议移除未来会废弃。配置上不允许有空格，需要与dnsNames匹配。错误配置webhook会失败/LetsEncrpyt
  dnsNames:
    - "8ops.top"
    - "*.8ops.top"
    - "*.lab.8ops.top"
EOF
kubectl -n default get Certificate tls-8ops.top-wildcard

# 5，view
kubectl get ingress,secrets
NAME                                        CLASS      HOSTS                 ADDRESS         PORTS     AGE
ingress.networking.k8s.io/ingress-selfsign-auto   external   tls-8ops.top-auto    10.101.9.216   80, 443   8m13s

NAME                  TYPE                DATA   AGE
secret/tls-8ops.top-auto    kubernetes.io/tls   3      7m10s
secret/tls-8ops.top-wildcard    kubernetes.io/tls   3      7m10s

openssl x509 -in tls.crt -noout -subject -issuer
openssl x509 -in tls.crt -noout -ext subjectAltName

```



### 2.2 LetsEncrypt

> 实测效果

| 顶级域名 | 成功与否 |
| -------- | -------- |
| *.top    | √        |
| *.cn     | √        |
| *.tech   | √        |
| *.com    | √        |

[Reference](https://cert-manager.io/docs/configuration/acme/dns01/#webhook)

cert-manager also supports out of tree DNS providers using an external webhook. Links to these supported providers along with their documentation are below:

- [`AliDNS-Webhook`](https://github.com/pragkent/alidns-webhook)
- [`cert-manager-alidns-webhook`](https://github.com/DEVmachine-fr/cert-manager-alidns-webhook)
- [`cert-manager-webhook-civo`](https://github.com/okteto/cert-manager-webhook-civo)
- [`cert-manager-webhook-dnspod`](https://github.com/qqshfox/cert-manager-webhook-dnspod)
- [`cert-manager-webhook-dnsimple`](https://github.com/neoskop/cert-manager-webhook-dnsimple)
- [`cert-manager-webhook-gandi`](https://github.com/bwolf/cert-manager-webhook-gandi)
- [`cert-manager-webhook-infomaniak`](https://github.com/Infomaniak/cert-manager-webhook-infomaniak)
- [`cert-manager-webhook-inwx`](https://gitlab.com/smueller18/cert-manager-webhook-inwx)
- [`cert-manager-webhook-linode`](https://github.com/slicen/cert-manager-webhook-linode)
- [`cert-manager-webhook-oci`](https://gitlab.com/dn13/cert-manager-webhook-oci) (Oracle Cloud Infrastructure)
- [`cert-manager-webhook-scaleway`](https://github.com/scaleway/cert-manager-webhook-scaleway)
- [`cert-manager-webhook-selectel`](https://github.com/selectel/cert-manager-webhook-selectel)
- [`cert-manager-webhook-softlayer`](https://github.com/cgroschupp/cert-manager-webhook-softlayer)
- [`cert-manager-webhook-ibmcis`](https://github.com/jb-dk/cert-manager-webhook-ibmcis)
- [`cert-manager-webhook-loopia`](https://github.com/Identitry/cert-manager-webhook-loopia)
- [`cert-manager-webhook-arvan`](https://github.com/kiandigital/cert-manager-webhook-arvan)
- [`bizflycloud-certmanager-dns-webhook`](https://github.com/bizflycloud/bizflycloud-certmanager-dns-webhook)
- [`cert-manager-webhook-hetzner`](https://github.com/vadimkim/cert-manager-webhook-hetzner)
- [`cert-manager-webhook-yandex-cloud`](https://github.com/malinink/cert-manager-webhook-yandex-cloud)
- [`cert-manager-webhook-netcup`](https://github.com/aellwein/cert-manager-webhook-netcup)
- [`cert-manager-webhook-pdns`](https://github.com/zachomedia/cert-manager-webhook-pdns)

#### 2.2.1 imroc

```bash
IMROC_VERSION=1.5.2
helm repo add imroc https://imroc.github.io/cert-manager-webhook-dnspod
helm repo update imroc
helm search repo imroc

helm show values imroc/cert-manager-webhook-dnspod \
  --version ${IMROC_VERSION} > cert-manager-webhook-dnspod-imroc.yaml-${IMROC_VERSION}-default

# Example 
#   https://books.8ops.top/attachment/cert-manager/helm/cert-manager-webhook-dnspod-imroc.yaml-1.2.0
#   https://books.8ops.top/attachment/cert-manager/helm/cert-manager-webhook-dnspod-imroc.yaml-1.5.2
#   https://books.8ops.top/attachment/cert-manager/71-certificate-dnspod-imroc.yaml
#   

helm install cert-manager-webhook-dnspod-imroc imroc/cert-manager-webhook-dnspod \
    -f cert-manager-webhook-dnspod-imroc.yaml-${IMROC_VERSION} \
    -n cert-manager \
    --version ${IMROC_VERSION}

# uninstall
helm -n cert-manager uninstall cert-manager-webhook-dnspod-imroc
kubectl -n cert-manager delete \
    secret/cert-manager-webhook-dnspod-ca \
    secret/cert-manager-webhook-dnspod-letsencrypt \
    secret/cert-manager-webhook-dnspod-webhook-tls

# view
kubectl -n cert-manager get \
    all,ingress,configmap,secret,issuer,clusterissuer,certificate,CertificateRequest,cert-manager

kubectl -n default get \
    ingress,secret,issuer,clusterissuer,certificate,CertificateRequest,cert-manager,challenge,order

kubectl get challenge,order -A

# 自动生成 -auto, -wildcard
kubectl apply -f 71-certificate-dnspod-imroc.yaml

```



#### 2.2.2 qqshfox

[Reference](https://github.com/qqshfox/cert-manager-webhook-dnspod)

```bash
git clone https://github.com/qqshfox/cert-manager-webhook-dnspod.git cert-manager-webhook-dnspod-git
mv cert-manager-webhook-dnspod-git/deploy/cert-manager-webhook-dnspod cert-manager-webhook-dnspod

# Example 
#   https://books.8ops.top/attachment/cert-manager/72-certificate-dnspod-qqshfox.yaml 
#

helm upgrade --install cert-manager-webhook-dnspod-qqshfox ./cert-manager-webhook-dnspod-qqshfox \
    --namespace cert-manager \
    -f cert-manager-webhook-dnspod-qqshfox.yaml

# 自动生成
# kubectl apply -f certificate-dnspod-qqshfox.yaml

# Ingress 中 secret 签发
kubectl apply -f ingress-dnspod-qqshfox.yaml

# uninstall
helm -n cert-manager uninstall cert-manager-webhook-dnspod-qqshfox

# 注意
# 当集群中有两个 dnspod webhook 时
# 两个 webhook 的 groupName 不能相同
# 但 certificate 必须和 cert-manager 一致，默认是 cert-manager.io
```

[dns-self-check](https://cert-manager.io/docs/configuration/acme/dns01/#setting-nameservers-for-dns01-self-check)



#### 2.2.3 reodwind

```bash
REODWIND_VERSION=v1.18.2
helm repo add reodwind https://reodwind.github.io/cert-manager-dnspod-webhook
helm repo update reodwind
helm search repo reodwind
helm show values reodwind/dnspod-webhook \
  --version ${REODWIND_VERSION} > cert-manager-webhook-dnspod-reodwind.yaml-${REODWIND_VERSION}-default

# Example 
#   https://books.8ops.top/attachment/cert-manager/73-certificate-dnspod-reodwind.yaml 
#

helm install cert-manager-webhook-dnspod-reodwind reodwind/dnspod-webhook \
    -f cert-manager-webhook-dnspod-reodwind.yaml-${REODWIND_VERSION} \
    -n cert-manager \
    --version ${REODWIND_VERSION}

kubectl -n cert-manager create secret generic dnspod-secret \
  --from-literal="access-token=yourtoken" \
  --from-literal="secret-key=yoursecretkey"

```



## 三、排查问题

### 3.1 Staging证书浏览器不识别

```bash
openssl x509 -in 8ops.top-wildcard.crt -noout -issuer -subject
issuer=C=US, O=(STAGING) Let's Encrypt, CN=(STAGING) Riddling Rhubarb R12
subject=CN=8ops.top

# 签发server区别
# 测试：server: https://acme-staging-v02.api.letsencrypt.org/directory
# 正式：server: https://acme-v02.api.letsencrypt.org/directory
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: admin@8ops.top
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
    - dns01:
        webhook:
          groupName: acme.yourdomain.com
          solverName: dnspod
          config:
            secretIdRef:
              name: dnspod-api-secret
              key: secret-id
            secretKeyRef:
              name: dnspod-api-secret
              key: secret-key

```

