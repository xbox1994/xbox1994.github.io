---
layout: post
title: "【Prometheus】Prometheus的设计"
date: 2019-06-10 16:06:06 +0800
comments: true
tags: DevOps
---

<!-- more -->

## 简介
Prometheus是带时序数据库的开源监控告警系统

Google发起的Linux基金会旗下的原生云基金会（Cloud Native Computing Foundation,CNCF）将Prometheus纳入其第二大开源项目，Kubernetes是第一个

随着 Kubernetes 在容器调度和管理上确定领头羊的地位，Prometheus 也成为 Kubernetes 容器监控的标配

### 优点
* 提供多维度数据模型和灵活的查询方式，通过将监控指标关联多个tag，来将监控数据进行任意维度的组合，并且提供简单的PromQL查询方式，还提供HTTP查询接口，可以很方便地结合Grafana等GUI组件展示数据
* 支持服务器节点的本地存储，通过Prometheus自带的时序数据库，可以完成每秒千万级的数据存储；在保存大量历史数据的场景中，Prometheus可以对接第三方时序数据库如OpenTSDB
* 定义了开放指标数据标准，以基于HTTP的Pull方式采集时序数据，只有实现了Prometheus监控数据格式的监控数据才可以被Prometheus采集、汇总，并支持以Push方式向中间网关推送时序列数据
* 支持通过静态文件配置和动态发现机制发现监控对象，自动完成数据采集。Prometheus目前已经支持Kubernetes、etcd、Consul等多种服务发现机制，可以减少运维人员的手动配置环节，在容器运行环境中尤为重要
* 易于维护，可以通过二进制文件直接启动，并且提供了容器化部署镜像
* 支持数据的分区采样和联邦部署，支持大规模集群监控

### 架构
基本原理：通过HTTP周期性抓取被监控组件的状态，任意组件只要提供对应的 HTTP 接口并且符合 Prometheus 定义的数据格式，就可以接入Prometheus监控

{% img /images/blog/2019-06-10_1.png 'image' %}

Prometheus获取监控对象的方式：

1. 通过配置文件、文本文件等进行静态配置
2. 支持ZooKeeper、Consul、Kubernetes等方式进行动态发现，例如对于Kubernetes的动态发现，Prometheus使用Kubernetes的API查询和监控容器信息的变化，动态更新监控对象

重要组件：

* Jobs/Exporters。监控数据采集Agent，Exporter以Web API的形式对外暴露数据采集接口（”/metrics”）。通过将exporter的信息注册到Prometheus Server,实现监控数据的定时采集
* TSDB(Time Series and Spatial-Temporal Database时序时空数据库)。通过一定的规则清理和整理数据，并把得到的结果存储到新的时间序列中。支持本地存储于远端存储
* PromQL。可视化地展示收集的数据。Prometheus支持多种方式的图表可视化，例如Grafana、自带的PromDash及自身提供的模版引擎等
* AlertManager。是独立于 Prometheus 的一个组件，在触发了预先设置在Prometheus 中的高级规则后，Prometheus 便会推送告警信息到 AlertManager。AlertManager提供了十分灵活的告警方式，可以通过邮件、slack或者钉钉等途径推送
* Pushgateway。对于某些场景Prometheus无法直接拉取监控数据，Pushgateway的作用就在于提供了中间代理，例如我们可以在应用程序中定时将监控metrics数据提交到Pushgateway。而Prometheus Server定时从Pushgateway的/metrics接口采集数据。

## 设计
### 指标
**一、定义**

Prometheus的所有监控指标（Metric）被统一定义为：

`<metric name>{<label name>=<label value>, ...}`

* 指标名称。用于说明指标的含义，例如http_request_total代表HTTP的请求总数
* 标签名称。体现指标的维度特征，用于过滤和聚合。它通过标签名和标签值这种键值对的形式，形成多种维度

**二、指标分类**

* Counter。计数器类型，它的特点是只增不减，例如机器启动时间、HTTP访问量等。Counter 具有很好的不相关性，不会因为机器重启而置0。我们在使用 Counter指标时，通常会结合 rate()方法获取该指标在某个时间段的变化率，例如，“HTTP请求总量”指标就属于典型的Counter指标，通过对它进行rate()操作，可以得出请求的变化率
* Gauge。仪表盘，表征指标的实时变化情况，可增可减，例如CPU和内存的使用量、网络 I/O 大小等，大部分监控数据都是 Gauge 类型的
* Summary。用于凸显数据的分布状况。如果需要了解某个时间段内请求的响应时间，则通常使用平均响应时间，但这样做无法体现数据的长尾效应
* Histogram。反映某个区间内的样本个数，通过{le="上边界"}指定这个范围内的样本数

**三、数据样本**

Prometheus采集的数据样本都是以时间序列保存的。每个样本都由三部分组成：指标、样本值、时间戳

样本值（64位浮点数）和时间戳（精确到 ms）的组合代表在这个时间点采集到的监控数值

{% img /images/blog/2019-06-10_2.png 'image' %}

可以将一个指标的样本数据保存到一起，横轴代表时间，纵轴代表指标序列。如图所示的每一行都代表由一个指标组成的时间序列，每个点都代表一个监控数值，这些时序数据首先被保存在内存中，然后被批量刷新到磁盘

### 数据采集
**一、采集方式**

和采用Push方式采集监控数据不同，Prometheus采用 Pull方式采集监控数据。为了兼容 Push方式，Prometheus 提供了 Pushgateway组件

采用Push方式时，Agent主动上报数据，采用 Pull方式时，监控中心（Master）拉取 Agent的数据

其主要区别在于 Agent和Master的主动、被动关系，如图所示

{% img /images/blog/2019-06-10_3.png 'image' %}

具体区别如下：

 -| Push | Pull 
---- | --- | ---
实时性 | 好。可以即时上报 | 差。只能轮询 
状态保存 | Agent无状态。Agent不保存数据，但Master需要维护Agent状态 | Master无状态。Agent保存数据，Master只负责拉取数据
可控性 | 低。控制方为Agent，上报策略决定数据结果 | 高。控制方为Master，更加主动地控制采集策略
耦合度 | 高，每个Agent都需要配置Master地址 | 低，Agent不需要感知Master存在 

**二、服务发现**

* 静态文件配置。适用于有固定的监控环境、IP地址和统一的服务接口的场景，需要在配置中指定采集的目标。但如果服务发生迁移、变更，以及更换地址或者端口，就需要重新修改配置文件并通知Prometheus重新加载配置文件
* 动态发现。如图：

{% img /images/blog/2019-06-10_4.png 'image' %}

Prometheus 会从这些组件中获取监控对象，并汇总在这些组件中获取的数据，从而获取所有监控对象

以Kubernetes为例：

1. 需要在 Prometheus 里配置 Kubernetes API 的地址和认证凭据，这样Prometheus就可以连接到Kubernetes的API来获取信息
2. Prometheus 的服务发现组件会一直监听（watch）Kubernetes 集群的变化，当有新主机或加入集群的时候，会获取新主机的主机名和主机IP，如果是新创建的容器，则可以获取新创建 Pod的名称、命名空间和标签等。相应地，如果删除机器或者容器，则相关事件也会被Prometheus感知，从而更新采集对象列表

**三、数据采集**

在获取被监控的对象后，Prometheus便可以启动数据采集任务了

Prometheus采用统一的Restful API方式获取数据，具体来说是调用HTTP GET请求或metrics数据接口获取监控数据。为了高效地采集数据，Prometheus对每个采集点都启动了一个线程去定时采集数据

在修改了采集的时间间隔后，Prometheus通常通过调用Prometheus的reload接口进行配置更新

### 数据处理

Prometheus 支持数据处理，主要包括 relabel、replace、keep、drop 等操作，提供过滤数据或者修改样本的维度信息等功能。

**一、重新定义标签**

在需要添加或者替换一个标签时需要重新定义标签

通过 replace 或者 labelmap 的方式可以针对这些内部使用的标签进行重命名或者将多个标签的内容进行组合。

**二、标签筛选**

Prometheus会从 target中获取所有暴露的数据，但某些数据对 Prometheus是无用的，如果直接保存这些数据，则不仅浪费空间，还会降低系统的吞吐量

* 如果设置了keep 机制。会保留所有匹配标签的数据
* 如果设置了drop机制。会丢弃匹配标签的数据，从而完成数据过滤

除了处理 keep或 drop,Prometheus还支持 Hash的分区采集，通过对 target地址计算 Hash值，然后取模匹配 Prometheus设定的值，便可以过滤该Prometheus负责采集的 target，这也是一种服务端负载均衡的方案，从而扩展 Prometheus 的采集能力。下面是一种通过Hash取模的经典用法：

{% img /images/blog/2019-06-10_5.png 'image' %}

### 数据存储

**一、本地存储**

Prometheus的本地时间序列数据库以自定义格式在磁盘上存储时间序列数据

其中wal目录记录的是监控数据的WAL；每个block是一个目录，该目录下的chunks用来保存具体的监控数据，meta.json用来记录元数据，index则记录索引。具体内容会在有关存储的章节中详细介绍

```text
./data
├── 01BKGV7JBM69T2G1BGBGM6KB12
│   └── meta.json
├── 01BKGTZQ1SYQJTR4PB43C8PD98
│   ├── chunks
│   │   └── 000001
│   ├── tombstones
│   ├── index
│   └── meta.json
├── 01BKGTZQ1HHWHV8FBJXW1Y3W0K
│   └── meta.json
├── 01BKGV7JC0RY8A6MACW02A2PJD
│   ├── chunks
│   │   └── 000001
│   ├── tombstones
│   ├── index
│   └── meta.json
└── wal
    ├── 00000002
    └── checkpoint.000001
```

**二、远程存储**

为了提高对大量历史数据持久化存储的能力，Prometheus 在1.6版本后支持远程存储，Adapter需要实现Prometheus的read接口和write接口，并且将read和write转化为每种数据库各自的协议

{% img /images/blog/2019-06-10_6.png 'image' %}

在用户查询数据时，Prometheus会通过配置的查询接口发送 HTTP请求，查询开始时间、结束时间及指标属性等，Adapter会返回相应的时序数据；相应地，在用户写入数据时，HTTP请求Adapter的消息体会包含时序数组（样本数据）。

### 数据查询
Prometheus提供了一种名为PromQL（Prometheus查询语言）的函数查询语言，用户可以实时选择和汇总时间序列数据

这里先介绍PromQL的使用方式。例如，在查询主机CPU的使用率时可以使用：

`100 * （ 1 - avg (irate(node_cpu(mode='idle')[5m])) by(job) )`

可以看到，PromQL不仅可以做指标运算，还支持各种如 sum、avg等的函数。Prometheus 通过解析引擎将查询语句转化为 QUERY 请求，然后通过时序数据库找到具体的数据块，在数据返回后再通过支持内置的函数处理数据，最终将结果返回到前端

{% img /images/blog/2019-06-10_7.png 'image' %}

Prometheus支持Grafana等开源显示面板，通过自定义PromQL可以制作丰富的监控视图。Prometheus本身也提供了一个简单的 Web查询控制台，如图2-14所示，Web控制台包含三个主要模块：Graph指标查询，Alerts告警查询、Status状态查询

### 告警
Prometheus可以根据采集的数据设定告警规则，例如针对 HTTP请求延迟设置的告警规则如下：

`request_latency_seconds:mean5m(job="myjob") > 0.5`

Prometheus 通过预先定义的 global.evaluation_interval 定时执行这些 PromQL，如果查询的结果符合上面的告警规则，则会产生一条告警记录，但不会立即发出这条告警记录，而需要经过一个评估时间，如果在评估时间段内每个周期（Prometheus 启动时设置）都触发了该告警规则，则会向外发出这条告警

Prometheus 本身对不会对告警进行处理，需要借助另一个组件 AlertManager，主要功能：

* 告警分组。将多条告警合并到一起发送
* 告警抑制。当告警已经发出时，停止发送由此告警触发的其他错误告警
* 告警静默。在一个时间段内不发出重复的告警

### 集群

**一、联邦**

多个 Prometheus节点组成两层联邦结构，如图所示。上面一层是联邦节点，负责定时从下面的Prometheus节点获取数据并汇总，部署多个联邦节点是为了实现高可用；下层的 Prometheus 节点又分别负责不同区域的数据采集，在多机房的事件部署中，下层的每个Prometheus节点都可以被部署到单独的一个机房，充当代理。

{% img /images/blog/2019-06-10_8.png 'image' %}

这种架构不仅降低了单个Prometheus的采集负载，而且通过联邦节点汇聚核心数据，也降低了本地存储的压力。为了避免下层Prometheus的单点故障，也可以部署多套 Prometheus 节点，只是在效率上会差很多，每个监控对象都会被重复采集，数据会被重复保存

**二、Thanos**

针对Prometheus这些不足，Improbable开源了他们的Prometheus高可用解决方案 Thanos。Thanos和 Prometheus无缝集成，并为 Prometheus带来了全局视图和不受限制的历史数据存储能力

## Prometheus并非监控银弹

* Prometheus只针对性能和可用性监控，并不具备日志监控等功能，并不能通过Prometheus解决所有监控问题
* 由于对监控数据的查询通常都是最近几天的，所以 Prometheus 的本地存储的设计初衷只是存储短期（一个月）数据，并非存储大量历史数据
* Prometheus的监控数据没有对单位进行定义，这里需要使用者自己区分或者事先定义好所有监控数据单位，避免发生数据缺少单位的情况
