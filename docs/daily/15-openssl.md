# 证书管理

## 系统受信证书

```bash
# ubuntu
apt install -y ca-certificates
curl -s -o /usr/local/share/ca-certificates/xx.crt http://m.8ops.top/cert/xx.crt
md5sum /usr/local/share/ca-certificates/xx.crt
update-ca-certificates

# centos
yum install -y ca-certificates
curl -s -o /etc/pki/ca-trust/source/anchors/xx.crt http://m.8ops.top/cert/xx.crt
md5sum /etc/pki/ca-trust/source/anchors/xx.crt
update-ca-trust
```





## 查看

> 查看`pem`信息

```bash
openssl x509 -noout -text -in root.pem
```

> 查看`p12`信息

```bash
openssl pkcs12 -in root.p12  | \
openssl x509 -noout -text
```

> 查看签发时间

```bash
openssl x509 -noout -enddate -startdate -in root.crt
```



## 验收

```bash
通过命令行获取网站SSL证书
SNI Server Name Indication
当一台服务器（相同的IP地址和TCP端口号）同时托管多个域名时，可通过servername参数明文发送主机名称。

echo | openssl s_client -showcerts -connect books.8ops.top:443 | openssl x509 -noout -dates
echo | openssl s_client -showcerts -connect books.8ops.top:443 -servername books.8ops.top | openssl x509 -noout -dates
# 基本信息
echo | openssl s_client -showcerts -connect books.8ops.top:443 -servername books.8ops.top | openssl x509 -noout

# 签发时间 startdate
# 过期时间 enddate
echo | openssl s_client -showcerts -connect books.8ops.top:443 -servername books.8ops.top | openssl x509 -noout -dates

# 详情
echo | openssl s_client -showcerts -connect books.8ops.top:443 -servername books.8ops.top
echo | openssl s_client -showcerts -connect books.8ops.top:443 -servername books.8ops.top | openssl x509 -noout -text
检测OCSP状态
echo "" | openssl s_client -connect books.8ops.top:443 -status 2>/dev/null | grep -i OCSP

# 已启用
OCSP Response Status: successful (0x0)

# 未启用
OCSP response: no response sent
openssl版本
openssl version -a
```





## 签发

### 个人签发

> 方式一

通过openssl生成私钥

```bash
openssl genrsa -out server.key 1024
```

使用私钥生成自签名的cert证书文件

```bash
openssl req -new -x509 -days 3650 -key server.key -out server.crt -subj "/C=CN/ST=OPS/L=OPS/O=OPS/OU=OPS/CN=ops.top/CN=*.8ops.top"
```

> 方式二

通过openssl生成私钥

```bash
openssl genrsa -out server.key 1024
```

根据私钥生成证书申请文件csr

```bash
openssl req -new -key server.key -out server.csr
```

这里根据命令行向导来进行信息输入

使用私钥对证书申请进行签名从而生成证书

```bash
openssl x509 -req -in server.csr -out server.crt -signkey server.key -days 3650
```

> 方式三

直接生成证书文件

```bash
openssl req -new -x509 -keyout server.key -out server.crt -config openssl.cnf
```




### 机构签发

```bash
openssl genrsa -out autobestdevops.com.key 2048
```

申请文件

```bash
openssl req -new -key autobestdevops.com.key -out autobestdevops.com.csr
```



### Let's enscript

[acme.sh](<https://github.com/Neilpang/acme.sh>)

> By `dnspod`  

```bash
export DP_Id=
export DP_Key=

# issue
acme.sh --issue \
-d 8ops.top \
-d *.8ops.top \
--dns dns_dp \
--debug 2

# install
acme.sh --install-cert \
-d 8ops.top \
--key-file /etc/nginx/ssl.d/8ops.top.key \
--fullchain-file /etc/nginx/ssl.d/8ops.top.crt \
--reloadcmd "service nginx reload"

# renew
acme.sh --renew -d 8ops.top -f
```



## 转换

`TODO`



## 单向双向

什么是SSL双向认证?什么是SSL单向认证? 本文给大家介绍**SSL双向认证**和**SSL单向认证**的具体过程以及他们两者之间的区别。 

### SSL双向认证具体过程

① 浏览器发送一个连接请求给安全服务器。 

② 服务器将自己的证书，以及同证书相关的信息发送给客户浏览器。 

③ 客户浏览器检查服务器送过来的证书是否是由自己信赖的CA中心（如沃通CA）所签发的。如果是，就继续执行协议;如果不是，客户浏览器就给客户一个警告消息：警告客户这个证书不是可以信赖的，询问客户是否需要继续。 

④ 接着客户浏览器比较证书里的消息，例如域名和公钥，与服务器刚刚发送的相关消息是否一致，如果是一致的，客户浏览器认可这个服务器的合法身份。 

⑤ 服务器要求客户发送客户自己的证书。收到后，服务器验证客户的证书，如果没有通过验证，拒绝连接;如果通过验证，服务器获得用户的公钥。 

⑥ 客户浏览器告诉服务器自己所能够支持的通讯对称密码方案。 

⑦ 服务器从客户发送过来的密码方案中，选择一种加密程度最高的密码方案，用客户的公钥加过密后通知浏览器。 

⑧ 浏览器针对这个密码方案，选择一个通话密钥，接着用服务器的公钥加过密后发送给服务器。 

⑨ 服务器接收到浏览器送过来的消息，用自己的私钥解密，获得通话密钥。 

⑩ 服务器、浏览器接下来的通讯都是用对称密码方案，对称密钥是加过密的。 

双向认证则是需要服务端与客户端提供身份认证，只能是服务端允许的客户能去访问，安全性相对于要高一些。

### SSL单向认证具体过程

①客户端的浏览器向服务器传送客户端SSL协议的版本号，加密算法的种类，产生的随机数，以及其他服务器和客户端之间通讯所需要的各种信息。 

②服务器向客户端传送SSL协议的版本号，加密算法的种类，随机数以及其他相关信息，同时服务器还将向客户端传送自己的证书。 

③客户利用服务器传过来的信息验证服务器的合法性，服务器的合法性包括：证书是否过期，发行服务器证书的CA是否可靠，发行者证书的公钥能否正确解开服务器证书的"发行者的数字签名"，[服务器证书](http://www.wosign.com/products/ssl.htm)上的域名是否和服务器的实际域名相匹配。如果合法性验证没有通过，通讯将断开;如果合法性验证通过，将继续进行第四步。 

④用户端随机产生一个用于后面通讯的"对称密码"，然后用服务器的公钥(服务器的公钥从步骤②中的服务器的证书中获得)对其加密，然后将加密后的"预主密码"传给服务器。 

⑤如果服务器要求客户的身份认证(在握手过程中为可选)，用户可以建立一个随机数然后对其进行数据签名，将这个含有签名的随机数和客户自己的证书以及加密过的"预主密码"一起传给服务器。 

⑥如果服务器要求客户的身份认证，服务器必须检验客户证书和签名随机数的合法性，具体的合法性验证过程包括：客户的证书使用日期是否有效，为客户提供证书的CA是否可靠，发行CA 的公钥能否正确解开客户证书的发行CA的数字签名，检查客户的证书是否在证书废止列表(CRL)中。检验如果没有通过，通讯立刻中断;如果验证通过，服务器将用自己的私钥解开加密的"预主密码 "，然后执行一系列步骤来产生主通讯密码(客户端也将通过同样的方法产生相同的主通讯密码)。 

⑦服务器和客户端用相同的主密码即"通话密码"，一个对称密钥用于SSL协议的安全数据通讯的加解密通讯。同时在SSL通讯过程中还要完成数据通讯的完整性，防止数据通讯中的任何变化。 

⑧客户端向服务器端发出信息，指明后面的数据通讯将使用的步骤⑦中的主密码为对称密钥，同时通知服务器客户端的握手过程结束。 

⑨服务器向客户端发出信息，指明后面的数据通讯将使用的步骤⑦中的主密码为对称密钥，同时通知客户端服务器端的握手过程结束。 

⑩SSL的握手部分结束，SSL安全通道的数据通讯开始，客户和服务器开始使用相同的对称密钥进行数据通讯，同时进行通讯完整性的检验。 

SSL单向认证只要求站点部署了ssl证书就行，任何用户都可以去访问(IP被限制除外等)，只是服务端提供了身份认证。

### SSL双向认证和SSL单向认证的区别

双向认证 SSL 协议要求服务器和用户双方都有证书。单向认证 SSL 协议不需要客户拥有CA证书，具体的过程相对于上面的步骤，只需将服务器端验证客户证书的过程去掉，以及在协商对称密码方案，对称通话密钥时，服务器发送给客户的是没有加过密的(这并不影响 SSL 过程的安全性)密码方案。这样，双方具体的通讯内容，就是加过密的数据，如果有第三方攻击，获得的只是加密的数据，第三方要获得有用的信息，就需要对加密的数据进行解密，这时候的安全就依赖于密码方案的安全。而幸运的是，目前所用的密码方案，只要通讯密钥长度足够的长，就足够的安全。这也是我们强调要求使用128位加密通讯的原因。 

一般Web应用都是采用SSL单向认证的，原因很简单，用户数目广泛，且无需在通讯层对用户身份进行验证，一般都在应用逻辑层来保证用户的合法登入。但如果是企业应用对接，情况就不一样，可能会要求对客户端(相对而言)做身份验证。这时就需要做SSL双向认证。 
