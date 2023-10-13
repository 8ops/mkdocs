# mitmproxy

## 一、协议包

### 1.1 mitmproxy

协议层抓包神器，同类型工具有charles

```bash
# server
mitmproxy 
# default port 8000

# iphone
## 设置网络代理后
## 浏览器访问 http://mitm.it 安装证书
```



双向认证场景

- 需要关闭服务器的客户端证书认证



### 1.2 charles

```bash
# default port 8888

# iphone
## 设置网络代理后
## 浏览器访问 http://charlesproxy.com/getssl
## 浏览器访问 http://char.pro/getssl

```





## 二、网络包

```bash
https://www.pgyer.com/tools/udid 通过第三方获取设备uuid

rvictl -s udid

rvictl -s c7ce66e439840cf02fa3482ae8985cca0a838e0d

iOS 虚拟网卡抓 包

 第一步：使用USB数据线将iOS设备连接到MAC上

第二步：获得iOS设备的UDID，可以使用iTools查看，也可以使用Xcode的Organizer工具查看

第三步：创建RVI接口

$ rvictl -s <UDID> 

 RVI虚拟接口的命令规则可为rvi0，rvi1，。。。,创建后可以使用以下命令查看是否创建成功

$ ifconfig rvi0

 第四步：在mac上用抓包工具wireshark或tcpdump等工具抓包分析

$ sudo tcpdump -i rvi0 -n -vv  

第五步：分析结束后，移除创建的RVI接口

$ rvictl -x <UDID>
```

