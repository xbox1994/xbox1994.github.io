---
layout: post
title: "开源产品商业化成功是一种怎样的体验"
date: 2017-09-11 01:18:59 +0800
comments: true
tags: 生活绝非编码
---
Docker：泻药
<!--more-->

##从前的Docker
2013年年初，一个叫做dotCloud的PaaS供应商将其内部项目Docker开源之后，Docker便慢慢进入我们的视野，这家公司甚至卖出所有PaaS业务，改名为Docker.Inc，专注于Docker的开发与推广。

2014年，Docker公司进行了多次收购，当年6月，Docker 1.0版本正式发布。同时发布Swarm、Machine与Compose编排与自动化工具优化用户体验。

拿出2014年底的一张老图，当时已经有许多国内外巨头已经采用或者将他们自己的工具、操作系统与Docker进行集成。

{% img /images/blog/2017-09-11_1.jpg 'image' %}

对于一个新的技术来说，有一个"技术热门度曲线"模型。分别有启动、泡沫、低谷、爬升、高原期。一个工具能够如此之火不免会让人觉得是否有吹嘘夸张和跟风之嫌，所以用户们会深入评定并发现技术存在的不足，热度便会下降。然而Docker没有活在他人的定义中，从始至终Docker似乎在告诉世界，标准是这样定义的，跟着我的方向走就行了，

{% img /images/blog/2017-09-11_2.jpg 'image' %}

然而在最近几年，Docker Cloud与Docker EE的容器即服务（CaaS）战略已经逐步成为主流，商业化模式也逐渐成熟，国内云厂商也开始提供各种容器服务试图从中分一杯羹。

**从前的Docker，从内部项目走向公司走向挑战标准的产品，Docker是把握到了什么能让自己一出生就屹立不倒，获得众多大厂的青睐？开源项目也能赚到钱？Docker真有那么好吗？**

##Moby？？？
（？？？黑人问号）第一眼看上去还以为是Docker被摩拜收购了。

###生态系统的完善
刚接触Docker的时候，“Docker”对我来说是一个工具，有着非常方便的操作可以让我启动一个与世隔绝的环境，并且可以在所有系统上跑，当时觉得这个工具简直上天了，他的前途可谓一片光明。

> Docker 在过去的两年里经历了指数级增长.DockerHub 的下载量从1亿增加到了60亿，为了保持这一增速，Docker 选择打破现有的一体化结构.分为更小的开源组件，包括 containerd, libnetwork, swarmkit, LinuxKit。

Docker的生态系统在一步一步成长，组件化开发的Docker本来就依赖大量组件的开发与拼接，这些组件的组装工作是大量重复与无用的工作，于是为了让任何人都能方便的组装自己的容器系统创建了Moby。

{% img /images/blog/2017-09-11_3.jpeg 'image' %}

所以，对于开源社区来说，Moby用原来的Docker项目加上一个容器集成系统取代了原来的Docker项目，完成了一个生态系统的完善，让每人都能自定义自己的容器。然而这只是官方给出来的解释。

###恐怖的流量转换
“Docker”这个关键字从出现到更名为“Moby”之前，在各种论坛、社交工具以及人们的脑海中已经留下了无法磨灭的痕迹，在各种搜索引擎的索引文件中也一定会存在优先级比较高的”Docker“关键字，以及大量相关索引链接、网页快照。

所以不管“Docker”的定义是否已经改变，我们一提到或者搜索的时候，大量流量就会被导向同一个搜索结果。在Docker商业化之后，最迫切需要用户了解到的就是Docker有什么产品，从Docker Cloud到Docker EE，天天烧投资商的钱也不是个事。于是Docker公司做出了一个影响比较大的举动，改名。

然而以开源为本的商业模式实在难以回本，技术、代码已经公开，凭什么可以赚到钱？开源赚到的影响力？实在太虚了，影响力要足够大，产品要足够好用，然后搞几个更多功能的商业产品才能让客户买单，那么是什么让Docker可以赚取足够资本，保其五年无虞？就凭Docker这个拿以前存在的技术包装个UI加几个实用的功能吗？请看下文。

##Docker的成功与责任

###凭什么
* Cgroup：Google在2006年启动开发。
* Namespace：Linux提供的一种内核级别环境隔离的方法。
* Aufs：未合并到Linux但存在于Debain的文件系统。
* LXC：Linux原生容器工具。

这些技术在Docker出现很多年前就已经存在于Linux或相关系统中了，其实简单来说，

Docker工具 = Cgroup + Namespace + rootfs + 容器引擎（用户态工具）。由于Docker抓住了以下的几点，成功看起来就比较简单：

* 微服务的设计艺术：轻量级虚拟化、与内核无缝结合的运行效率优势与极小的系统开销；将各个组件单独部署的思想。
* 与时代结合的契机：我们正处在一个信息爆炸的时代，对应用的性能、功能、体验的要求日益提高，单体应用的噩梦早已出现，微服务与云服务更是一个时下流行并且势在必行的概念与实践；云平台要求的虚拟化技术对于性能要求特别苛刻。
* 现有技术的丰富、完善：基于LXC容器技术的完善、加强、应用化。

###能力越大，责任越大
站在巨人的肩膀上拿到苹果之后，我还想...成为巨人！

{% img /images/blog/2017-09-11_4.gif 'image' %}

除了Docker这个工具相关的一些project：engine/compose/registry/machine/swarm/kitematic/hyperkit（其中基于hypervisor的hyperkit、负责集群管理的swarm分别在容器的可移植性和分布式实践作出贡献），对容器的核心技术的推进有更大贡献的项目有：

* LibContainer：Docker创建的容器引擎，负责创建容器、API调用的实现。
* LibNetwork： Docker提出的容器的网络模型。
* Unikernel：Docker收购的新型容器技术。

这些是Docker开发或收购的一些容器核心技术，即使作为前身是PaaS的商业公司也能在在丰富完善Docker功能的之后依然保持组件开源，也是为开源界与容器技术做出了一定具有责任的贡献。

在硬件虚拟化方面，VMWare与Virtualbox已经占领市场很多年；在操作系统虚拟化方面，Docker在成为容器技术方面的主流甚至标准之后，如果能与行业大拿一起创造或者制定标准，则是功在当代，利在千秋。

##参考
```
https://www.starduster.me/2017/04/29/why-docker-created-the-moby-project/
https://www.zhihu.com/question/58805021
《Docker进阶与实战》
```

## 号外号外
最近在总结一些针对**Java**面试相关的知识点，感兴趣的朋友可以一起维护~  
地址：[https://github.com/xbox1994/2018-Java-Interview](https://github.com/xbox1994/2018-Java-Interview)
