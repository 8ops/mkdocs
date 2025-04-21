# LLM

私有化使用，需求量越来越大，一般出于

- 个性化交互形式
- 私有知识库，拒绝互联网的安全隐患



**一般体现形式**

- ollama server + desktop 交互
- ollama server + browser 交互



**私有化处理环节**

- chat model，用于语义化理解聊天内容，模拟与人交互
- 向量数据库，用于预处理私有知识库内容
- embedding model，处理私有知识库内容的模型 [nomic-embed-text](https://ollama.com/library/nomic-embed-text)



## 一、模型容器

[ollama](https://ollama.com/)

[lm studio](https://lmstudio.ai/)

```bash
# 加速下载
wget https://github.moeyy.xyz/https://github.com/ollama/ollama/releases/download/v0.5.7/ollama-linux-amd64
```



### 1.1 使用集锦

```bash
ollama run deepseek-r1:1.5b
ollama run deepseek-r1:7b
ollama run deepseek-r1:8b
ollama run deepseek-r1:14b
ollama run deepseek-r1:32b
ollama run deepseek-r1:70b
ollama run deepseek-r1:671b

OLLAMA_HOST=0.0.0.0:19090 ollama serve
OLLAMA_HOST=0.0.0.0:19090 ollama pull deepseek-r1:1.5b
OLLAMA_HOST=0.0.0.0:19090 ollama pull deepseek-r1:14b
OLLAMA_HOST=0.0.0.0:19090 ollama pull deepseek-r1:32b

OLLAMA_HOST=0.0.0.0:19090 ollama serve
OLLAMA_HOST=0.0.0.0:19090 ollama run deepseek-r1:1.5b

http://10.110.83.55:19090/

# 一样的
docker pull dyrnq/open-webui
docker pull ghcr.io/open-webui/open-webui:main

# example
docker run -d -p 3000:8080 -v open-webui:/app/backend/data --name open-webui --add-host=host.docker.internal:host-gateway --restart always ghcr.io/open-webui/open-webui:dev

docker run -d -p 3000:8080 -e OLLAMA_BASE_URL=https://example.com -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main

docker run -d -p 3000:8080 --gpus all --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:cuda

# sample
docker run -d -p 19090:8080 \
    -e OLLAMA_BASE_URL=http://10.110.83.55:19090/ \
    -v open-webui:/app/backend/data \
    --name open-webui \
    --restart always \
    ghcr.io/open-webui/open-webui:main
```

v0.5.14 解决文档上传失败的BUG。



## 二、下载模型

```bash
ollama pull deepseek-r1:1.5b
```



> ollama.services

```bash
[Unit]
Description=OLLAMA AI Service
After=network-online.target

[Service]
ExecStart=/usr/local/bin/ollama serve
User=ollama
Group=ollama
Restart=always
RestartSec=3
Environment="PATH=/data/anaconda3/condabin:/usr/local/anaconda3/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/usr/local/cuda/bin:/root/go/bin:/root/bin"
Environment="OLLAMA_HOST=0.0.0.0:19090"
Environment="OLLAMA_GPU_LAYER=cuda"
Environment="CUDA_VISIBLE_DEVICES=1" #use gpu

[Install]
WantedBy=default.target
```







## 三、对话交互

[open-webui](https://github.com/open-webui/open-webui)

[lm studio](https://lmstudio.ai/)

[anythingllm](https://anythingllm.com/)



docker 

- open-webui
- anytinglm



### 3.1 open-webui

```bash
# 普通用户打开预设模型
# 管理员面板 --> 设置 --> 模型 --> 可见性[由 private 变更为 public]
# OR
# 建立用户角色再将模型加入角色，将用户加入角色，普通用户登录后可见模型

```



### 3.2 lm studio



### 3.3 anythingllm

[anythingllm desktop](https://anythingllm.com/desktop)

[env.example](https://github.com/Mintplex-Labs/anything-llm/blob/bffdfffe81bcae39b62218a897ca2732c5168937/server/.env.example)

```bash
docker pull mintplexlabs/anythingllm:1.4

export STORAGE_LOCATION=/data1/lib/anythingllm && \
    mkdir -p $STORAGE_LOCATION && \
    touch "$STORAGE_LOCATION/.env" && \
    chown 1000.1000 -R $STORAGE_LOCATION

cat > $STORAGE_LOCATION/.env <<EOF
###########################################
######## LLM API SElECTION ################
###########################################
LLM_PROVIDER='ollama'
OLLAMA_BASE_PATH='http://10.110.83.55:19090/'
OLLAMA_MODEL_PREF='deepseek-r1:7b'
OLLAMA_MODEL_TOKEN_LIMIT=4096
EOF

docker run -d -p 19091:3001 \
    --name anythingllm \
    --restart always \
    --cap-add SYS_ADMIN \
    -v ${STORAGE_LOCATION}:/app/server/storage \
    -v ${STORAGE_LOCATION}/.env:/app/server/.env \
    -e STORAGE_DIR="/app/server/storage" \
    mintplexlabs/anythingllm:1.4
```



### 3.4 ragflow

[Reference](https://github.com/infiniflow/ragflow)

```bash
```





## 四、增强模型

https://www.modelscope.cn/models/liush99/ollama_models

Modelfile

Generate a response

prompt



## 五、关键问题

```bash
# 1. 下载模型加速，复用？
默认存储在 ~/.ollama 拷贝可用

# 2. open-webui 模型对普通用户可见
在“管理员面板 --> 设置 --> 模型 --> 可见性[由 private 变更为 public]”
或进行用户权限分组管理，在模型中指定权限组可见

# 3. 导入预设（自定义语料）？

# 4. 查询模型（没有答案时不胡编乱造）

# 5. open-webui 允许普通用户注册？
在管理员面板设置，需要管理员激活

# 6. 创建模型 modelfile

```

