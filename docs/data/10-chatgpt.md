# chatgpt

## 一、生成式AI

```bash
# 国外使用 
https://chat.openai.com
https://bard.google.com/

# 国内使用
https://yiyan.baidu.com/
https://tongyi.aliyun.com/
https://moss.fastnlp.top/
```



## 二、ChatGPT-Web

[Reference](https://github.com/Chanzhaoyu/chatgpt-web)

```bash
# 申请 OPENAI_API_KEY
# https://platform.openai.com/api-keys

docker run --name chatgpt-web -d -p 3002:3002 \
    -e OPENAI_API_KEY=sk-xxxx \
    -e SOCKS_PROXY_HOST=127.0.0.1 -e SOCKS_PROXY_PORT=56666 \
    chenzhaoyu94/chatgpt-web:v2.11.1

#    -e HTTPS_PROXY=http://127.0.0.1:56666 \
#    -e ALL_PROXY=http://127.0.0.1:56666 \
```

