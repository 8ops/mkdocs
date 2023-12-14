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

