# mkdocs

[Reference](https://github.com/squidfunk/mkdocs-material)

## 一、 安装向导

```bash
pip install mkdocs

mkdocs new guide
cd guide
mkdocs serve

pip install mkdocs-material
pip install mkdocs-minify-plugin 

mkdocs gh-deploy --force
```



## 二、Comment

[gitalk](https://stardusten.github.io/coding-notes/tools/Mkdocs/)



## 三、效果演示

```bash
- [x] a
- [ ] b
- [x] c

$a^2$

- 加粗 bold
- 斜体字 斜体字
- 加粗斜体 粗斜体
- 下划线 ^^Insert me^^
- 删除线 Delete me
- 增加 {++ add ++}
- 修改 {~ is ~> are ~}
- 删除 {– del –}
- 高亮 {== highlight ==}
- 注释 {>> comment <<}
- 上标 H^2^O, text^a\ superscript^
- 下标 CH3CH2OH, texta\ subscript
- 行内代码高亮：:::java System.out.println("hello"); or #!python println('hello')
- 键盘快捷键标签：++ctrl+alt+f++

!!! note "custom title or blank"
    text

# 可折叠，+默认打开
???+ danger highlight blink "custom title or blank"
    text vtext text, text, v<br>
    text vtext text, text, v
    #```python
    # text1 = "Hello, "
    # text2 = "world!"
    # print text1 + text2
    #```
```

- [x] a
- [ ] b
- [x] c

$a^2$


- 加粗 bold
- 斜体字 *斜体字*
- 加粗斜体 *粗斜体*
- 下划线 ^^Insert me^^
- 删除线 Delete me
- 增加 {++ add ++}
- 修改 {~ is ~> are ~}
- 删除 {– del –}
- 高亮 {== highlight ==}
- 注释 {>> comment <<}
- 上标 H^2^O, text^a\ superscript^
- 下标 CH_3CH2OH, texta\ subscript
- 行内代码高亮：`:::java System.out.println("hello");` or `#!python println('hello')`
- 键盘快捷键标签：++ctrl+alt+f++

!!! note "custom title or blank"
    text



可折叠，+默认打开

???+ danger highlight blink "custom title or blank"
    text vtext text, text, v<br>
    text vtext text, text, v

    ```python
    text1 = "Hello, "
    text2 = "world!"
    print text1 + text2
    ```
