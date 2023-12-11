# huggingface

## 一、huggingface-cli

```bash
# # before
# python 3.x.x
# huggingface.co registry

pip install huggingface_hub

huggingface-cli login

# use proxy
export http_proxy=http://127.0.0.1:10080 all_proxy=http://127.0.0.1:10080 https_proxy=http://127.0.0.1:10080

huggingface-cli down distilbert-base-uncased-finetuned-sst-2-english

tree ~/.cache/huggingface/hub/models--distilbert-base-uncased-finetuned-sst-2-english
├── blobs
│   ├── 1e8d194203eaef261e7091a792f87162b443ba94
│   ├── 248fa5ab9d582a1e8255e3a562503e7ada42379e
│   ├── 252cf7048af94a1599019fef35961b2bd3d6db13df0b0a4b032b92baeae31939
│   ├── 3ed34255a7cb8e6706a8bb21993836e99e7b959f
│   ├── 60554cbd7781b09d87f1ececbea8c064b94e49a7f03fd88e8775bfe6cc3d9f88
│   ├── 688882a79f44442ddc1f60d70334a7ff5df0fb47
│   ├── 7c3919835e442510166d267fe7cbe847e0c51cd26d9ba07b89a57b952b49b8aa
│   ├── 7efee27005a6b1a2403dec53ea42846c70a14605
│   ├── 8587f57d6d8e31a3c93ece645ff1ed435d645861
│   ├── 9a0990c5c0e00e26cc5ca4ba5c1c3ad533de7018
│   ├── 9db97da21b97a5e6db1212ce6a810a0c5e22c99daefe3355bae2117f78a0abb9
│   ├── a8b3208c2884c4efb86e49300fdd3dc877220cdf
│   ├── b44df675bb34ccd8e57c14292c811ac7358b7c8e37c7f212745f640cd6019ac8
│   ├── b57fe5dfcb8ec3f9bab35ed427c3434e3c7dd1ba
│   ├── f84095a3e2962f44bdd2f865e4333c35ae95d73f
│   └── fb140275c155a9c7c5a3b3e0e77a9e839594a938
├── refs
│   └── main
└── snapshots
    └── 4643665f84c6760e3cbf6adaace6c398592270af
        ├── README.md -> ../../blobs/8587f57d6d8e31a3c93ece645ff1ed435d645861
        ├── config.json -> ../../blobs/b57fe5dfcb8ec3f9bab35ed427c3434e3c7dd1ba
        ├── map.jpeg -> ../../blobs/248fa5ab9d582a1e8255e3a562503e7ada42379e
        ├── model.safetensors -> ../../blobs/7c3919835e442510166d267fe7cbe847e0c51cd26d9ba07b89a57b952b49b8aa
        ├── onnx
        │   ├── added_tokens.json -> ../../../blobs/f84095a3e2962f44bdd2f865e4333c35ae95d73f
        │   ├── config.json -> ../../../blobs/7efee27005a6b1a2403dec53ea42846c70a14605
        │   ├── model.onnx -> ../../../blobs/252cf7048af94a1599019fef35961b2bd3d6db13df0b0a4b032b92baeae31939
        │   ├── special_tokens_map.json -> ../../../blobs/a8b3208c2884c4efb86e49300fdd3dc877220cdf
        │   ├── tokenizer.json -> ../../../blobs/688882a79f44442ddc1f60d70334a7ff5df0fb47
        │   ├── tokenizer_config.json -> ../../../blobs/1e8d194203eaef261e7091a792f87162b443ba94
        │   └── vocab.txt -> ../../../blobs/fb140275c155a9c7c5a3b3e0e77a9e839594a938
        ├── pytorch_model.bin -> ../../blobs/60554cbd7781b09d87f1ececbea8c064b94e49a7f03fd88e8775bfe6cc3d9f88
        ├── rust_model.ot -> ../../blobs/9db97da21b97a5e6db1212ce6a810a0c5e22c99daefe3355bae2117f78a0abb9
        ├── tf_model.h5 -> ../../blobs/b44df675bb34ccd8e57c14292c811ac7358b7c8e37c7f212745f640cd6019ac8
        ├── tokenizer_config.json -> ../../blobs/3ed34255a7cb8e6706a8bb21993836e99e7b959f
        └── vocab.txt -> ../../blobs/fb140275c155a9c7c5a3b3e0e77a9e839594a938
```



## 二、quick tour

### 2.1 model

#### 2.1.1 预下载

```python
# 默认使用本地 cache 目录的模型文件
# 提前通过 huggingface-cli 下载
# ~/.cache/huggingface/hub/models--distilbert-base-uncased-finetuned-sst-2-english
    def sentiment_analysis(self):
        classifier=transformers.pipeline("sentiment-analysis")
        out=classifier("We are very happy to show you the 🤗 Transformers library.")

        print(out)
        
# output
[{'label': 'POSITIVE', 'score': 0.9997795224189758}]
```



#### 2.1.2 代理下载

```python
# 默认使用本地 cache 目录的模型文件
# 运行过程中通过代理网络下载

    PROXYIES={"http":"http://127.0.0.1:7890","https":"http://127.0.0.1:7890"}
  
    def fill_task(self):
        model="bert-base-uncased"
        tokenizer = transformers.AutoTokenizer.from_pretrained(model,proxies=self.PROXYIES)
        unmasker=transformers.pipeline("fill-task",model=model)
        out=unmasker("The goal of life is [MASK].",top_k=5)
```



#### 2.1.3 提前下载

```bash
# https://huggingface.co/bert-base-chinese/tree/main
tree bert
bert/
└── bert-base-chinese
    ├── config.json
    ├── flax_model.msgpack
    ├── model.safetensors
    ├── pytorch_model.bin
    ├── tf_model.h5
    ├── tokenizer.json
    ├── tokenizer_config.json
    └── vocab.txt
```



```python

    MODEL_NAME=r"bert-base-chinese"
    MODEL_PATH=r"bert/bert-base-chinese"

    def model_from_path(self):
        # Load model directly
        tokenizer = transformers.AutoTokenizer.from_pretrained(self.MODEL_PATH)
        model = transformers.AutoModelForMaskedLM.from_pretrained(self.MODEL_PATH)
```



### 2.2 pipeline

```bash
# pipeline task list

- `"audio-classification"`: will return a [`AudioClassificationPipeline`].
- `"automatic-speech-recognition"`: will return a [`AutomaticSpeechRecognitionPipeline`].
- `"conversational"`: will return a [`ConversationalPipeline`].
- `"depth-estimation"`: will return a [`DepthEstimationPipeline`].
- `"document-question-answering"`: will return a [`DocumentQuestionAnsweringPipeline`].
- `"feature-extraction"`: will return a [`FeatureExtractionPipeline`].
- `"fill-mask"`: will return a [`FillMaskPipeline`]:.
- `"image-classification"`: will return a [`ImageClassificationPipeline`].
- `"image-segmentation"`: will return a [`ImageSegmentationPipeline`].
- `"image-to-image"`: will return a [`ImageToImagePipeline`].
- `"image-to-text"`: will return a [`ImageToTextPipeline`].
- `"mask-generation"`: will return a [`MaskGenerationPipeline`].
- `"object-detection"`: will return a [`ObjectDetectionPipeline`].
- `"question-answering"`: will return a [`QuestionAnsweringPipeline`].
- `"summarization"`: will return a [`SummarizationPipeline`].
- `"table-question-answering"`: will return a [`TableQuestionAnsweringPipeline`].
- `"text2text-generation"`: will return a [`Text2TextGenerationPipeline`].
- `"text-classification"` (alias `"sentiment-analysis"` available): will return a  [`TextClassificationPipeline`].
- `"text-generation"`: will return a [`TextGenerationPipeline`]:.
- `"text-to-audio"` (alias `"text-to-speech"` available): will return a [`TextToAudioPipeline`]:.
- `"token-classification"` (alias `"ner"` available): will return a [`TokenClassificationPipeline`].
- `"translation"`: will return a [`TranslationPipeline`].
- `"translation_xx_to_yy"`: will return a [`TranslationPipeline`].
- `"video-classification"`: will return a [`VideoClassificationPipeline`].
- `"visual-question-answering"`: will return a [`VisualQuestionAnsweringPipeline`].
- `"zero-shot-classification"`: will return a [`ZeroShotClassificationPipeline`].
- `"zero-shot-image-classification"`: will return a [`ZeroShotImageClassificationPipeline`].
- `"zero-shot-audio-classification"`: will return a [`ZeroShotAudioClassificationPipeline`].
- `"zero-shot-object-detection"`: will return a [`ZeroShotObjectDetectionPipeline`].
```



