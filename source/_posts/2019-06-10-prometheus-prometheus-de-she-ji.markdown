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



