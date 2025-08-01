# curl

[Reference](https://www.thebyte.com.cn/http/https-latency.html)

![http-process](../images/http-process.png)

## 一、简单使用

### 1.1 打印详情

```bash
curl -v "https://books.8ops.top/" 
curl -vv "https://books.8ops.top/" 
curl -vvv "https://books.8ops.top/" 
curl -vvvv "https://books.8ops.top/" 
```

### 1.2 终端耗时

```bash
time curl -i "https://books.8ops.top/" 
```

### 1.3 简单耗时

```bash
curl -s -o /dev/null \
  -w "%{http_code}:%{time_connect}:%{time_starttransfer}:%{time_total}" \
  "https://books.8ops.top"
```

### 1.4 丰富耗时

```bash
# 1
curl -s -o /dev/null \
  -w "\n\nhttp_code: %{http_code}\nhttp_connect: %{http_connect}s\ncontent_type: %{content_type}s\ntime_namelookup: %{time_namelookup}s\ntime_redirect: %{time_redirect}s\ntime_pretransfer: %{time_pretransfer}s\ntime_connect: %{time_connect}s\ntime_starttransfer: %{time_starttransfer}s\ntime_total: %{time_total}s\nspeed_download: %{speed_download}KB/s\n" \
  "https://books.8ops.top/" 
  
# 2
curl -s -o /dev/null -w "\n
  http_code: \t\t %{http_code}
  http_connect: \t %{http_connect}s
  content_type: \t %{content_type}
  time_namelookup: \t %{time_namelookup}s
  time_redirect: \t %{time_redirect}s
  time_pretransfer: \t %{time_pretransfer}s
  time_appconnect: \t %{time_appconnect}s
  time_connect: \t %{time_connect}s
  time_starttransfer: \t %{time_starttransfer}s
  time_total: \t\t %{time_total}s
  speed_download: \t %{speed_download}KB/s
  \n" \
  https://books.8ops.top/
```



### 1.5 快速检测

```bash
# %{time_namelookup}：DNS 解析时间（秒）
# %{time_connect}：TCP 连接时间（秒）
# %{time_appconnect}：SSL/TLS 握手时间（秒）
# %{time_pretransfer}：请求头发送前的总时间（秒）
# %{time_starttransfer}：首字节接收前的总时间（秒）
# %{time_total}：总耗时（秒）

# 1
cat > curl-format.txt <<EOF
    time_namelookup:  %{time_namelookup}\n
       time_connect:  %{time_connect}\n
    time_appconnect:  %{time_appconnect}\n
      time_redirect:  %{time_redirect}\n
   time_pretransfer:  %{time_pretransfer}\n
 time_starttransfer:  %{time_starttransfer}\n
         --------------------\n
         time_total:  %{time_total}\n\n
EOF

# 2
cat > curl-format.txt<<EOF
          http_code:  %{http_code}\n
       http_connect:  %{http_connect}s\n
       content_type:  %{content_type}\n
       ------------------------\n
    time_namelookup:  %{time_namelookup}s\n
      time_redirect:  %{time_redirect}s\n
       time_connect:  %{time_connect}s\n
    time_appconnect:  %{time_appconnect}s\n
       ------------------------\n
   time_pretransfer:  %{time_pretransfer}s\n
 time_starttransfer:  %{time_starttransfer}s\n
         time_total:  %{time_total}s\n
     speed_download:  %{speed_download}KB/s\n\n
EOF

curl -w "@curl-format.txt" -o /dev/null -s -L -k https://books.8ops.top
```





### 1.6 curl 升级

```bash
CURL_VERSION=8.8.0
cd /opt
wget https://curl.se/download/curl-${CURL_VERSION}.tar.gz
tar xzf curl-${CURL_VERSION}.tar.gz

# 有提前升级过openssl
LD_RUN_PATH="/usr/local/openssl/lib64" \
LDFLAGS="-L/usr/local/openssl/lib64" \
CPPFLAGS="-I/usr/local/openssl/include" \
CFLAGS="-I/usr/local/openssl/include" \
./configure --prefix=/usr/local --with-openssl=/usr/local/openssl
make && make install
```





## 二、命令详解

```
-w, --write-out 

以下变量会按CURL认为合适的格式输出，输出变量需要按照%{variable_name}的格式，如果需要输出%，double一下即可，即%%，同时，\n是换行，\r是回车，\t是TAB。 

url_effective The URL that was fetched last. This is most meaningful if you've told curl to follow location: headers. 

filename_effective The ultimate filename that curl writes out to. This is only meaningful if curl is told to write to a file with the --remote-name or --output option. It's most useful in combination with the --remote-header-name option. (Added in 7.25.1) 

http_code http状态码，如200成功,301转向,404未找到,500服务器错误等。(The numerical response code that was found in the last retrieved HTTP(S) or FTP(s) transfer. In 7.18.2 the alias response_code was added to show the same info.) 

http_connect The numerical code that was found in the last response (from a proxy) to a curl CONNECT request. (Added in 7.12.4) 

time_total 总时间，按秒计。精确到小数点后三位。 （The total time, in seconds, that the full operation lasted. The time will be displayed with millisecond resolution.） 

time_namelookup DNS解析时间,从请求开始到DNS解析完毕所用时间。(The time, in seconds, it took from the start until the name resolving was completed.) 

time_connect 连接时间,从开始到建立TCP连接完成所用时间,包括前边DNS解析时间，如果需要单纯的得到连接时间，用这个time_connect时间减去前边time_namelookup时间。以下同理，不再赘述。(The time, in seconds, it took from the start until the TCP connect to the remote host (or proxy) was completed.) 

time_appconnect 连接建立完成时间，如SSL/SSH等建立连接或者完成三次握手时间。(The time, in seconds, it took from the start until the SSL/SSH/etc connect/handshake to the remote host was completed. (Added in 7.19.0)) 

time_pretransfer 从开始到准备传输的时间。(The time, in seconds, it took from the start until the file transfer was just about to begin. This includes all pre-transfer commands and negotiations that are specific to the particular protocol(s) involved.) 

time_redirect 重定向时间，包括到最后一次传输前的几次重定向的DNS解析，连接，预传输，传输时间。(The time, in seconds, it took for all redirection steps include name lookup, connect, pretransfer and transfer before the final transaction was started. time_redirect shows the complete execution time for multiple redirections. (Added in 7.12.3)) 

time_starttransfer 开始传输时间。(The time, in seconds, it took from the start until the first byte was just about to be transferred. This includes time_pretransfer and also the time the server needed to calculate the result.) 

size_download 下载大小。(The total amount of bytes that were downloaded.) 

size_upload 上传大小。(The total amount of bytes that were uploaded.) 

size_header 下载的header的大小(The total amount of bytes of the downloaded headers.) 

size_request 请求的大小。(The total amount of bytes that were sent in the HTTP request.) 

speed_download 下载速度，单位-字节每秒。(The average download speed that curl measured for the complete download. Bytes per second.) 

speed_upload 上传速度,单位-字节每秒。(The average upload speed that curl measured for the complete upload. Bytes per second.) 

content_type 就是content-Type，不用多说了，这是一个访问我博客首页返回的结果示例(text/html; charset=UTF-8)；(The Content-Type of the requested document, if there was any.) 

num_connects Number of new connects made in the recent transfer. (Added in 7.12.3) 

num_redirects Number of redirects that were followed in the request. (Added in 7.12.3) 

redirect_url When a HTTP request was made without -L to follow redirects, this variable will show the actual URL a redirect would take you to. (Added in 7.18.2) 

ftp_entry_path The initial path libcurl ended up in when logging on to the remote FTP server. (Added in 7.15.4) 

ssl_verify_result ssl认证结果，返回0表示认证成功。( The result of the SSL peer certificate verification that was requested. 0 means the verification was successful. (Added in 7.19.0)) 

```

