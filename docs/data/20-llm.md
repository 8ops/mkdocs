# LLM

## 一、模型容器

ollama

lm studio

```bash
OLLAMA_HOST=0.0.0.0:19090 ollama serve
OLLAMA_HOST=0.0.0.0:19090 ollama pull deepseek-r1:14b
OLLAMA_HOST=0.0.0.0:19090 ollama pull deepseek-r1:32b


ollama run deepseek-r1:1.5b
ollama run deepseek-r1:7b


OLLAMA_HOST=0.0.0.0:19090 ollama serve
OLLAMA_HOST=0.0.0.0:19090 ollama run deepseek-r1:1.5b

http://10.110.83.55:19090/





# example

docker run -d -p 3000:8080 -v open-webui:/app/backend/data --name open-webui --add-host=host.docker.internal:host-gateway --restart always ghcr.io/open-webui/open-webui:dev

docker run -d -p 3000:8080 -e OLLAMA_BASE_URL=https://example.com -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main

docker run -d -p 3000:8080 --gpus all --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:cuda

# sample

docker run -d -p 19090:8080 -e OLLAMA_BASE_URL=http://10.110.83.55:19090/ -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main
```





## 二、下载模型







## 三、对话交互

open-webui

lm studio

anytinglm

