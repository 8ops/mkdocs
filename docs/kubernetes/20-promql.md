# PromQL 基本使用

PromQL (Prometheus Query Language) 是 Prometheus 自己开发的数据查询 DSL 语言，语言表现力非常丰富，内置函数很多，在日常数据可视化以及rule 告警中都会使用到它。



摘抄于网友贡献。

在页面 https://prometheus.8ops.top/graph 中

```
http_requests_total{code="200"}
```

> 字符串和数字

字符串: 在查询语句中，字符串往往作为查询条件 labels 的值，和 Golang 字符串语法一致，可以使用 "", '', 或者 `` 

```
"this is a string"
```



## 一、基本概念



### 1.1 查询结果类型

PromQL 查询结果主要有 3 种类型

- 瞬时数据 (Instant vector): 包含一组时序，每个时序只有一个点，例如：**http_requests_total**
- 区间数据 (Range vector): 包含一组时序，每个时序有多个点，例如：**http_requests_total[5m]**
- 纯量数据 (Scalar): 纯量只有一个数字，没有时序，例如：**count(http_requests_total)**



### 1.2 查询条件

Prometheus 存储的是时序数据，而它的时序是由名字和一组标签构成的，其实名字也可以写出标签的形式，例如 **http_requests_total** 等价于 {name="http_requests_total"}。

一个简单的查询相当于是对各种标签的筛选

```
http_requests_total{code="200"}      # 表示查询名字为 http_requests_total，code 为 "200" 的数据
复制代码
```

查询条件支持正则匹配

```
http_requests_total{code!="200"}     # 表示查询 code 不为 "200" 的数据
http_requests_total{code=～"2.."}    # 表示查询 code 为 "2xx" 的数据
http_requests_total{code!～"2.."}    # 表示查询 code 不为 "2xx" 的数据
复制代码
```



### 1.3 操作符

Prometheus 查询语句中，支持常见的各种表达式操作符

算术运算符

```
支持的算术运算符有 +，-，*，/，%，^, 例如 http_requests_total * 2 表示将 http_requests_total 所有数据 double 一倍。
复制代码
```

比较运算符

```
支持的比较运算符有 ==，!=，>，<，>=，<=, 例如 http_requests_total > 100 表示 http_requests_total 结果中大于 100 的数据。
复制代码
```

逻辑运算符

```
支持的逻辑运算符有 and，or，unless, 例如 http_requests_total == 5 or http_requests_total == 2 表示 http_requests_total 结果中等于 5 或者 2 的数据。
复制代码
```

聚合运算符

```
支持的聚合运算符有 sum，min，max，avg，stddev，stdvar，count，count_values，bottomk，topk，quantile，, 例如 max(http_requests_total) 表示 http_requests_total 结果中最大的数据。
复制代码
```

***注意:和四则运算类型，Prometheus 的运算符也有优先级，它们遵从（^）> (\*, /, %) > (+, -) > (==, !=, <=, <, >=, >) > (and, unless) > (or) 的原则。***



### 1.4 内置函数

Prometheus 内置不少函数，方便查询以及数据格式化，例如将结果由浮点数转为整数的 floor 和 ceil

```
- floor(avg(http_requests_total{code="200"}))
- ceil(avg(http_requests_total{code="200"}))
复制代码
```

查看 http_requests_total 5分钟内，平均每秒数据

```
rate(http_requests_total[5m])
复制代码
```



## 二、语法进阶

### 2.1 即时矢量选择器

- =：匹配与标签相等的内容
- !=：不匹配与标签相等的内容
- =~: 根据正则表达式匹配与标签符合的内容
- !~：根据正则表达式不匹配与标签符合的内容



```
# 这将匹配method不等于GET,environment匹配到staging，testing或development的http_requests_total请求内容。
http_requests_total{environment=~"staging|testing|development",method!="GET"} 
复制代码
```

向量选择器必须指定一个名称或至少一个与空字符串不匹配的标签匹配器

```
# 非法表达式
  {job=~".*"}

# 合法表达式
  {job=~".+"}
  {job=~".*",method="get"}

# 有效是因为它们都有一个与空标签值不匹配的选择器
复制代码
```



### 2.2 范围矢量选择器

持续时间仅限于数字

```
s - seconds
m - minutes
h - hours
d - days
w - weeks
y - years
复制代码
```



```
# 选择在过去5分钟内为度量标准名称为http_requests_total且标签设置为job=prometheus的所有时间序列记录的所有值
http_requests_total{job="prometheus"}[5m]
复制代码
```



### 2.3 偏移量修改器

偏移修改器允许更改查询中各个即时和范围向量的时间偏移

例如：以下表达式相对于当前查询5分钟前的http_requests_total值

```
http_requests_total offset 5m
复制代码
```

偏移修改器需要立即跟随选择器

```
# 非法表达式
sum(http_requests_total{method="GET"}) offset 5m 

# 合法表达式
sum(http_requests_total{method="GET"} offset 5m)
复制代码
```

同样适用于范围向量

```
# 将返回http_requests_total一周前的5分钟增长率
rate(http_requests_total[5m] offset 1w)
复制代码
```



## 三、二元运算符

Prometheus中存在以下二进制算术运算符



### 3.1 算术二元运算符

```
+ (addition)
- (subtraction)
* (multiplication)
/ (division)
% (modulo)
^ (power/exponentiation)
复制代码
```



### 3.2 比较二元运算符

```
== (equal)
!= (not-equal)
> (greater-than)
< (less-than)
>= (greater-or-equal)
<= (less-or-equal)
复制代码
```



### 3.4 逻辑/集二进制运算符

```
and (intersection)
or (union)
unless (complement)
复制代码
```



### 3.5 聚合运算符

Prometheus支持以下内置聚合运算符，这些运算符可用于聚合单个即时向量的元素，从而生成具有聚合值的较少元素的新向量

```
sum (calculate sum over dimensions)                               # 范围内求和
min (select minimum over dimensions)                              # 范围内求最小值
max (select maximum over dimensions)                              # 范围内求最大值
avg (calculate the average over dimensions)                       # 范围内求最大值
stddev (calculate population standard deviation over dimensions)  # 计算标准偏差
stdvar (calculate population standard variance over dimensions)   # 计算标准方差
count (count number of elements in the vector)                    # 计算向量中的元素数量
count_values (count number of elements with the same value)       # 计算向量中相同元素的数量
bottomk (smallest k elements by sample value)                     # 样本中最小的元素值
topk (largest k elements by sample value)                         # 样本中最大的元素值
quantile (calculate φ-quantile (0 ≤ φ ≤ 1) over dimensions)      # 计算 0-1 之间的百分比数量的样本的最大值
复制代码
```

这些运算符可以用于聚合所有标签维度，也可以通过包含without或by子句来保留不同的维度

```
<aggr-op>([parameter,] <vector expression>) [without|by (<label list>)]
复制代码
```

解析

```
- parameter仅用于count_values，quantile，topk和bottomk
- without从结果向量中删除列出的标签，而所有其他标签都保留输出
- by相反并删除未在by子句中列出的标签，即使它们的标签值在向量的所有元素之间是相同的
复制代码
```

如果http_requests_total具有按application，instance和group标签列出的时间序列，我们可以通过以下方式

```
# 计算每个应用程序和组在所有实例上看到的HTTP请求总数
sum(http_requests_total) without (instance)
# 等同于
sum(http_requests_total) by (application, group)
复制代码
```

如果我们只对我们在所有应用程序中看到的HTTP请求总数感兴趣,可以写成

```
sum(http_requests_total)
复制代码
```

要计算运行每个构建版本的二进制文件的数量，可以写成

```
count_values("version", build_version)
复制代码
```

要在所有实例中获取5个最大的HTTP请求计数，可以写成

```
topk(5, http_requests_total)
复制代码
```



## 四、矢量匹配



### 4.1 一对一矢量匹配

一对一从操作的每一侧找到唯一的条目对。在默认情况下，这是格式为vector1  vector2之后的操作。如果两个条目具有完全相同的标签集和相应的值，则它们匹配。

ignore关键字允许在匹配时忽略某些标签，而on关键字允许将所考虑的标签集减少到提供的列表

```
<vector expr> <bin-op> ignoring(<label list>) <vector expr>
<vector expr> <bin-op> on(<label list>) <vector expr>
复制代码
```

输出示例

```
method_code:http_errors:rate5m{method="get", code="500"} 24
method_code:http_errors:rate5m{method="get", code="404"} 30
method_code:http_errors:rate5m{method="put", code="501"} 3
method_code:http_errors:rate5m{method="post", code="500"} 6
method_code:http_errors:rate5m{method="post", code="404"} 21

method:http_requests:rate5m{method="get"} 600
method:http_requests:rate5m{method="del"} 34
method:http_requests:rate5m{method="post"} 120
复制代码
```

查询示例

```
method_code:http_errors:rate5m{code="500"} / ignoring(code) method:http_requests:rate5m
复制代码
```

***这将返回一个结果向量，其中包含每个方法的状态代码为500的HTTP请求部分，在过去5分钟内测量。在不忽略（代码）的情况下，由于度量标准不共享同一组标签，因此不会匹配***

方法put和del的条目没有匹配，并且不会显示在结果中

```
{method="get"} 0.04 // 24 / 600
{method="post"} 0.05 // 6 / 120
复制代码
```



### 4.2 多对一与一对多矢量匹配

多对一和一对多匹配指的是"一"侧的每个向量元素可以与"多"侧的多个元素匹配的情况

必须使用group_left或group_right修饰符明确请求，其中left/right确定哪个向量具有更高的基数。

```
<vector expr> <bin-op> ignoring(<label list>) group_left(<label list>) <vector expr>
<vector expr> <bin-op> ignoring(<label list>) group_right(<label list>) <vector expr>
<vector expr> <bin-op> on(<label list>) group_left(<label list>) <vector expr>
<vector expr> <bin-op> on(<label list>) group_right(<label list>) <vector expr>
复制代码
```

查询示例

```
# 在这种情况下，左向量每个方法标签值包含多个条目
method_code:http_errors:rate5m / ignoring(code) group_left method:http_requests:rate5m

# 因此，我们使用group_left表明这一点
# 右侧的元素现在与多个元素匹配，左侧具有相同的方法标签
{method="get", code="500"} 0.04 // 24 / 600
{method="get", code="404"} 0.05 // 30 / 600
{method="post", code="500"} 0.05 // 6 / 120
{method="post", code="404"} 0.175 // 21 / 120
复制代码
```

***多对一和一对多匹配是高级用例，使用前请仔细认真思考***



## 五、篇外

```
abs(v instant-vector)     # 返回其绝对值
absent()                  # 如果传递给它的向量具有该元素，则返回空向量;如果传递给它的向量没有元素，则返回传入的元素。
复制代码
```

查询

```
nginx_server_connections
nginx_server_connections{endpoint="metrics",instance="192.168.43.5:9913",job="nginx-vts",namespace="dev",pod="nginx-vts-9fcd4d45b-sdqds",service="nginx-vts",status="accepted"} 89061
nginx_server_connections{endpoint="metrics",instance="192.168.43.5:9913",job="nginx-vts",namespace="dev",pod="nginx-vts-9fcd4d45b-sdqds",service="nginx-vts",status="handled"} 2

absent(nginx_server_connections{job="nginx-vts"}) => {}
absent(nginx_server_connections{job="nginx-vts123"}) => {job="nginx-vts123"}
复制代码
```

运算符（仅供参考）

```
ceil(v instant-vector)                              # 返回向量中所有样本值(向上取整数)
round(v instant-vector, to_nearest=1 scalar)        # 返回向量中所有样本值的最接近的整数,to_nearest是可选的,默认为1,表示样本返回的是最接近1的整数倍的值, 可以指定任意的值(也可以是小数),表示样本返回的是最接近它的整数倍的值
floor(v instant-vector)                             # 返回向量中所有样本值(向下取整数)
changes(v range-vector)                             # 对于每个输入时间序列，返回其在时间范围内（v range-vector）更改的次数
clamp_max(v instant-vector, max scalar)             # 限制v中所有元素的样本值，使其上限为max
clamp_min(v instant-vector, min scalar)             # 限制v中所有元素的样本值，使其下限为min
year(v=vector(time()) instant-vector)               # 返回UTC中给定时间的年份
day_of_month(v=vector(time()) instant-vector)       # 返回UTC中给定时间的月中的某一天，返回值为1到31
day_of_week(v=vector(time()) instant-vector)        # 返回UTC中给定时间的当周中的某一天，返回值为0到6
days_in_month(v=vector(time()) instant-vector)      # 返回UTC中给定时间的一个月的天数，返回值28到31
hour(v=vector(time()) instant-vector)               # 返回UTC中给定时间的当天中的某一小时，返回值为0到23
minute(v=vector(time()) instant-vector)             # 返回UTC中给定时间的小时中的某分钟，返回值为0到59
delta(v range-vector)                               # 返回一个即时向量，它计算每个time series中的第一个值和最后一个值的差别
deriv(v range-vector)                               # 计算每个time series的每秒的导数(derivative)
exp(v instant-vector)                               # 计算v中所有元素的指数函数
histogram_quantile(φ float, b instant-vector)       # 从buckets类型的向量中计算φ(0 ≤ φ ≤ 1)百分比的样本的最大值
holt_winters(v range-vector, sf scalar, tf scalar)  # 根据范围向量中的范围产生一个平滑的值
idelta(v range-vector)                              # 计算最新的2个样本值之间的差别
increase(v range-vector)                            # 计算指定范围内的增长值, 它会在单调性发生变化时(如由于目标重启引起的计数器复位)自动中断
irate(v range-vector)                               # 计算每秒的平均增长值, 基于的是最新的2个数据点
rate(v range-vector)                                # 计算每秒的平均增长值
resets(v range-vector)                              # 对于每个 time series , 它都返回一个 counter resets的次数
sort(v instant-vector)                              # 对向量按元素的值进行升序排序
sort_desc(v instant-vector)                         # 对向量按元素的值进行降序排序
sqrt(v instant-vector)                              # 返回v中所有向量的平方根
time()                                              # 返回从1970-1-1起至今的秒数,UTC时间
```

