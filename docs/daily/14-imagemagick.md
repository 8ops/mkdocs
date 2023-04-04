# 图片处理

`imagemagick`通过命令处理图片

## convert

convert顾名思义就是对图像进行转化，它主要用来对图像进行格式的转化，同时还可以做缩放、剪切、模糊、反转等操作。

> 拼接

```bash
convert 1.png 2.png +append result.png #横向
convert 1.png 2.png -append result.png #纵向
```

> 格式转换

```bash
convert foo.jpg foo.png
```

> 将所有jpg文件转化成png

```bash
mogrify -format png *.jpg 
```

> convert还可以把多张照片转化成pdf格式

```bash
convert *.jpg foo.pdf
```

> 大小缩放

```bash
convert -resize 100x100 foo.jpg thumbnail.jpg
```

```bash
convert -resize 50%x50% foo.jpg thumbnail.jpg
```

> 批量生成缩略图

```bash
mogrify -sample 80x60 *.jpg
```

```bash
mogrify -sample 80%x60% *.jpg
```

> 在一张照片的四周加上边框。其中"#000000"是边框的颜色，边框的大小为60x60

```bash
convert -mattecolor "#000000" -frame 60x60 yourname.jpg rememberyou.png
```

> 在图片上加文字。左上角10x50的位置用绿色的字写下charry.org，指定别的字体用-font

```bash
convert -fill green -pointsize 40 -draw 'text 10,50 "charry.org"' foo.png bar.png
```

> 高斯模糊。-blur参数还可以这样-blur 80x5。后面的那个5表示的是Sigma的值

```bash
convert -blur 80 foo.jpg foo.png
```

> 上下翻转

```bash
convert -flip foo.png bar.png
```

> 左右翻转

```bash
convert -flop foo.png bar.png
```

> 形成底片的样子

```bash
convert -negate foo.png bar.png
```

> 把图片变为黑白颜色

```bash
convert -monochrome foo.png bar.png
```

> 加噪声

```bash
convert -noise 3 foo.png bar.png
```

> 油画效果

```bash
convert -paint 4 foo.png bar.png
```

> 把一张图片，旋转一定的角度。30表示向右旋转30度，如果要向左旋转，度数就是负数

```bash
convert -rotate 30 foo.png bar.png
```

> 炭笔效果

```bash
convert -charcoal 2 foo.png bar.png
```

> 散射，毛玻璃效果

```bash
convert -spread 30 foo.png bar.png
```

> 漩涡，以图片的中心作为参照，把图片扭转，形成漩涡的效果

```bash
convert -swirl 67 foo.png bar.png
```

> 凸起效果，用-raise来创建凸边

```bash
convert -raise 5x5 foo.png bar.png
```

> 按比例裁剪，是从一个图片截取一个指定区域的子图片

```bash
格式：
convert -crop widthxheight{+-}x{+-}y{%}
```



```bash
width 子图片宽度
height 子图片高度
x 为正数时为从区域左上角的x坐标,为负数时,左上角坐标为0,然后从截出的子图片右边减去x象素宽度.
y 为正数时为从区域左上角的y坐标,为负数时,左上角坐标为0,然后从截出的子图片上边减去y象素高度.

convert -crop 300x400+10+10 src.jpg dest.jpg 
# 从src.jpg 坐标为x:10 y:10截取300x400的图片存为dest.jpg

convert -crop 300x400-10+10 src.jpg dest.jpg 
# 从src.jpg坐标为x:0 y:10截取290x400的图片存为dest.jpg
```

> 从图片中心位置向四周裁剪大小为 300x400的区域

```bash
convert -gravity center -crop 300x400+0+0 src.jpg dest.jpg 
```

> crop参数也可以使用百分比

```bash
convert src.jpg -crop 50% dest.jpg 

# 生成dest-[0-3].jpg的图，其实全命令可以理解为： -crop 50%x50%+0+0
# 设原图大小为200x100，则
# dest-0.jpg 为src.jpg的100x50+0+0，大小为100x50
# dest-1.jpg 为src.jpg的100x50+100+0，大小为100x50
# dest-2.jpg 为src.jpg的100x50+0+50，大小为100x50
# dest-3.jpg 为src.jpg的100x50+100+50，大小为100x50
```

> 将原图从上到下平均裁剪成4份

```bash
convert src.jpg -crop 100%x25%  dest.jpg  

# dest-0.jpg 为src.jpg的200x25+0+0，大小为200x25
# dest-1.jpg 为src.jpg的200x25+0+25，大小为200x25
# dest-2.jpg 为src.jpg的200x25+0+50，大小为200x25
# dest-3.jpg 为src.jpg的200x25+0+75，大小为200x25
```

> 只裁剪中心区域的50%

```bash
convert src.jpg -gravity center -crop 50%  dest.jpg  
```

> 若src.jpg(200x100)，则dest.jpg为从src中心位置向四周扩展50%的区域,即与执行下边命令的结果相同

```bash
convert src.jpg -gravity center -corp 100x50+40+25  dest.jpg
```



## import

import是一个用于屏幕截图的组件

> 截取屏幕的任一矩形区域


```
import foo.png
```

在输入上述的命令后，你的鼠标会变成一个十字，这个时候，你只要在想要截取的地方划一个矩形就可以了

> 截取程序的窗口


```
import -pause 3 -frame foo.png
```

回车后，用鼠标在你想截的窗口上点一下即可。参数-frame的作用是告诉import，截图的时候把目标窗口的外框架带上，参数-pause的作用很重要，你可以试着把它去掉，对比一下，你会发现，目标窗口的标题栏是灰色的，pause就是让import稍微延迟一下，等你的目标窗口获得焦点了，才开始截图，这样的图才比较自然。

截取一个倾斜的窗口
如果想让你的截图比较cool，你可以把截取一个倾斜的窗口，方法如下：

```
import -rotate 30 -pause 3 -frame foo.png
```

> 截取整个屏幕


```
import -pause 3 -window root screen.png
```

注意，暂停了3秒钟，你需要在3秒钟内切换到需要截取的画面噢。







