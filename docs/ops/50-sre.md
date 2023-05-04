# SRE

摘录于蘑菇街赵成的分享《[SRE 实战手册](https://time.geekbang.org/column/intro/100048201)》《[运维体系](https://time.geekbang.org/column/intro/100003401)》。


??? faq "SRE常见问题与困惑？"

    - SRE到底是什么？到底能帮我们解决什么问题？
    - 类似的方法论还有DevOps、AIOps，以及最新的混沌工程（Chaos Engineering），它们之间有什么区别？
    - SRE涉及范围如此之大，我们到底应该从哪里入手建设呢？
    - 在稳定性技术体系的建设上，我们做了大量工作，为什么还是故障频发、频频救火？难道单纯的技术保障还不够吗？
    - 每次出故障，我们都觉得响应速度和处理效率已经很高了，但是为什么业务部门和领导仍然不满意，总是指责我们开发和维护的系统不稳定？
    - 每次故障之后，最害怕的就是开复盘会，开着开着就变成了批斗会，有时候问题还没定位清楚，就开始推诿扯皮谁应该背锅了，真不知道开故障复盘会的目的是什么？
    - 引入了SRE，我们团队的能力应该怎么提升？组织架构应该怎么匹配呢？
    - SRE的要求这么高，作为个人，我应该如何提升自己的能力达到SRE的要求？
    - SRE无所不能的角色？还是运维运维的升级？
    - 没有故障，系统就一定是稳定的吗？



## 一、夯实基础

### 1.1 统一共识

![SRE稳定性保障规划图](../images/sre/intro.jpg)

> 术语

- **MTBF**，Mean Time Between Failure，平均故障时间间隔。

- **MTTR**，Mean Time To Repair，故障平均修复时间。

  - **MTTI**，Mean Time To Identify，平均故障发现时间。

  - **MTTK**，Mean Time To Know，平均故障认知时间。

  - **MTTF**，Mean Time To Fix，平均故障解决时间。

  - **MTTV**，Mean Time To Verify，平均故障修复验证时间。



### 1.2 衡量标准

#### 1.2.1 衡量方式

业务衡量系统可用性的两种方式：

- **时间纬度**：Availability = Uptime / (Uptime + Downtime)。
- **请求纬度**：Availability = Successful request / Total request。

![系统可用度对照表](../images/sre/ratio.jpg)

> 时间纬度三要素

- 衡量指标，如系统请求状态码。
- 衡量目标，如非5xx占比成功率达到95%。
- 持续时长，持续10分钟。



> 请求纬度三要素

- 衡量指标
- 衡量目标
- 统计周期



故障一定意味着不稳定，但是不稳定，并不意味着一定有故障发生。



#### 1.2.2 评估因素

> 三因素

- 成本因素，ROI 投入产出比，稳定性要求越高投入会越大。
- 业务容忍度，核心系统优先保障，非核心系统不影响主业务流程。
- 系统当前的稳定状况，定一个合理的标准比定一个更高的标准会更重要。



SRE关注的稳定性是系统的整体运行状态，而不仅仅只关注故障状态下的稳定性，在系统运行过程中的任何异常，都会被纳入稳定性的评估范畴中。



#### 1.2.3 设定过程

> 术语

- **SLI**，Service Level Indicator。如状态码为非5xx的比例。
- **SLO**，Service Level Objective。如大于等于99.95%。

SLO是SLI要达成的目标。



![SLI集合](../images/sre/slis.jpg)

合理对指标分层，不是所有指标都是适合做SLI指标。



> 选择SLI的两大原则

- 选择能够标识一个主体是否稳定的指标，如果不是这个主体本身的指标，或者不能标识主体稳定性的，就要排除在外。
- 针对电商类有用户界面的业务系统，优先选择与用户体验强相关或用户可以明显感知的指标。



快速识别SLI指标的方法：Google - **VALET**。

- V - Volume，容量。
- A - Availablity，可用性。
- L - Latency，时延。需要合理置信区间。
- E - Errors，错误率。
- T - Tickets，人工介入。低效现象。

![VALET](../images/sre/valet.jpg)



> SLO计算可用性

- 直接根据成功的定义计算，Successful = （状态码非5xx）&（时延 <= 80ms 。常用在SLA。
- SLO方法计算，Availability = SLO1 & SLO2 & SLO3。
  - SLO1，99.95%状态码成功率
  - SLO2，90% Latency <=80ms
  - SLO3，99% Latency <=200ms

[Reference](https://sre.google/workbook/slo-document/)



#### 1.2.4 Error Budget

![Error Budget](../images/sre/error-budget.jpg)

> 应用场景

- 稳定性燃尽图
- 故障定级
- 稳定性共识机制
- 基于错误预算的告警



![稳定性燃尽图](../images/sre/error-budget-burndown.jpg)

![故障定级](../images/sre/error-budget-level.jpg)



告警应该是具有指导意义。




## 二、最佳实践
