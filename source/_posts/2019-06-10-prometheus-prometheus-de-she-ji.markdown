---
layout: post
title: "【Prometheus】Prometheus的设计"
date: 2019-06-10 16:06:06 +0800
comments: true
categories: DevOps
---

<!-- more -->

## 简介
Prometheus是带时序数据库的开源监控告警系统

Google发起的Linux基金会旗下的原生云基金会（Cloud Native Computing Foundation,CNCF）将Prometheus纳入其第二大开源项目，Kubernetes是第一个

随着 Kubernetes 在容器调度和管理上确定领头羊的地位，Prometheus 也成为 Kubernetes 容器监控的标配

#### 优点
* 提供多维度数据模型和灵活的查询方式，通过将监控指标关联多个tag，来将监控数据进行任意维度的组合，并且提供简单的PromQL查询方式，还提供HTTP查询接口，可以很方便地结合Grafana等GUI组件展示数据
* 支持服务器节点的本地存储，通过Prometheus自带的时序数据库，可以完成每秒千万级的数据存储；在保存大量历史数据的场景中，Prometheus可以对接第三方时序数据库如OpenTSDB
* 定义了开放指标数据标准，以基于HTTP的Pull方式采集时序数据，只有实现了Prometheus监控数据格式的监控数据才可以被Prometheus采集、汇总，并支持以Push方式向中间网关推送时序列数据
* 支持通过静态文件配置和动态发现机制发现监控对象，自动完成数据采集。Prometheus目前已经支持Kubernetes、etcd、Consul等多种服务发现机制，可以减少运维人员的手动配置环节，在容器运行环境中尤为重要
* 易于维护，可以通过二进制文件直接启动，并且提供了容器化部署镜像
* 支持数据的分区采样和联邦部署，支持大规模集群监控

#### 架构
基本原理：通过HTTP周期性抓取被监控组件的状态，任意组件只要提供对应的 HTTP 接口并且符合 Prometheus 定义的数据格式，就可以接入Prometheus监控

{% img /images/blog/2019-06-10_1.png 'image' %}

Pull方式的优势：

1. 降低耦合。推送系统中很容易出现因为向监控系统推送数据失败而导致被监控系统瘫痪的问题，所以通过Pull方式，被采集端无须感知监控系统的存在，完全独立于监控系统之外，提供接口暴露数据即可
2. 提升可控性。数据的采集完全由监控系统控制，只需要向配置好的目标查询数据即可，如果需要更改数据采集配置也是在监控系统中修改

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
#### 指标
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

#### 数据采集
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






