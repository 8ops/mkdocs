# conda

## 一、安装环境

```bash
# https://developer.aliyun.com/article/1023567
wget -c https://repo.anaconda.com/archive/Anaconda3-2023.09-0-MacOSX-x86_64.sh
bash Anaconda3-2023.09-0-MacOSX-x86_64.sh

# 构建Shell环境
conda create -n modelscope python=3.11.5
conda activate modelscope
pip install torch torchvision torchaudio tensorflow
pip install setuptools_scm
pip install fairseq

# 安装modelscope nlp功能
pip install "modelscope[nlp]" -f https://modelscope.oss-cn-beijing.aliyuncs.com/releases/repo.html

# 安装modelscope cv功能
pip install "modelscope[cv]" -f https://modelscope.oss-cn-beijing.aliyuncs.com/releases/repo.html

# 测试
python -c "from modelscope.pipelines import pipeline;print(pipeline('word-segmentation')('安装modelscope'))"
```



## 二、部署模型

```bash
modelscope server --model_id=qwen/Qwen-7B-Chat --revision=v1.0.5

docker run -d --rm --name modelscope-chat -e MODELSCOPE_CACHE=/modelscope_cache -v /host_path_to_modelscope_cache:/modelscope_cache -p 8000:8000 registry.cn-beijing.aliyuncs.com/modelscope-repo/modelscope:ubuntu22.04-cuda11.8.0-py310-torch2.1.0-tf2.14.0-1.10.0 modelscope server --model_id=qwen/Qwen-7B-Chat --revision=v1.0.5

docker run -d --rm --name modelscope-chat --shm-size=50gb --gpus='"device=0"' -e MODELSCOPE_CACHE=/modelscope_cache -v /host_path_to_modelscope_cache:/modelscope_cache -p 8000:8000 registry.cn-beijing.aliyuncs.com/modelscope-repo/modelscope:ubuntu22.04-cuda11.8.0-py310-torch2.1.0-tf2.14.0-1.10.0 modelscope server --model_id=qwen/Qwen-7B-Chat --revision=v1.0.5

```

