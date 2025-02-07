# LLM

## 一、模型容器

[ollama](https://ollama.com/)

[lm studio](https://lmstudio.ai/)

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
docker run -d -p 19090:8080 -e OLLAMA_BASE_URL=http://10.110.83.55:19090/ -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main
```





## 二、下载模型







## 三、对话交互

[open-webui](https://github.com/open-webui/open-webui)

[lm studio](https://lmstudio.ai/)

[anytingllm](https://anythingllm.com/)



### 3.1 open-webui

```bash
# 普通用户打开预设模型
# 管理员面板 --> 设置 --> 模型 --> 可见性[由 private 变更为 public]
# 
```



## 四、关键问题

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

