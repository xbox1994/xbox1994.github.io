---
layout: post
title: "[译][MicroService 7]将巨无霸重构成微服务"
date: 2017-06-01 23:08:21 +0800
comments: true
categories: MicroService
---

<!--more-->

#微服务重构概述
将单体应用程序转换成微服务的过程是[应用程序现代化](https://en.wikipedia.org/wiki/Software_modernization)的一种形式。

你应该逐步重构单体应用程序而不是重写。随着时间的推移，单体应用实现的功能量会减少，知道它完全消失或者成为另一个微服务。这种策略类似于在在高速上以70英里/小时驾驶汽车，但是比重写风险小多了。

Martin Fowler将这种应用现代化策略看做[扼杀者应用](http://www.martinfowler.com/bliki/StranglerApplication.html)。名字来源于热带雨林中发现的扼杀者藤蔓。一只藤蔓生在一棵树上为了得到森林冠层上方的阳光。有时，树死了，留下一棵树状的藤蔓。应用现代化就是这样。我们将构建一个新的应用，包含遗留应用周围的终将死掉的微服务。

![](https://cdn-1.wp.nginx.com/wp-content/uploads/2016/03/Richardson-microservices-part7-fig.png)

让我们看看不同的策略。

#策略1 - 停止挖掘
[孔洞法则](https://en.wikipedia.org/wiki/Law_of_holes)是，每当你在一个洞里，你应该停止挖掘。当你的单体应用变得无法管理时，这是个很好的建议。换句话说，你应该停止让整体更大。这意味着当你实现新功能时你不应该像整体添加更多代码。而是应该将新的代码放到独立的微服务中。下图显示了应用这个方法之后的系统架构。

![](https://cdn-1.wp.nginx.com/wp-content/uploads/2016/03/Adding_a_secure_microservice_alongside_a_monolithic_application.png?_ga=2.40418021.633879600.1496325382-897858824.1491727609)

除了新服务和巨无霸，还有两个组件。第一个是**请求路由器**，处理收到的请求。路由器发送请求到对应的新服务上的新功能模块中。将以前的请求路由到巨无霸上。

另一个组件是**胶水代码**，将服务与巨无霸集成。一个服务很少孤立存在，并且通常需要访问巨无霸拥有的数据。胶水代码在两者之间，服务与数据集成。抽离出来的服务使用胶水代码读取和写入由巨无霸拥有的数据。

服务有三种方式访问巨无霸的数据：

* 调用巨无霸提供的API
* 访问巨无霸的数据库
* 维护自己的数据副本，与巨无霸的数据库同步

The glue code is sometimes called an anti‑corruption layer. That is because the glue code prevents the service, which has its own pristine domain model, from being polluted by concepts from the legacy monolith’s domain model. The glue code translates between the two different models. The term anti‑corruption layer first appeared in the must‑read book Domain Driven Design by Eric Evans and was then refined in a white paper. Developing an anti‑corruption layer can be a non‑trivial undertaking. But it is essential to create one if you want to grow your way out of monolithic hell.

实现轻量级服务的好处：

* 阻止巨无霸变得更难管理
* 独立开发部署和扩展

但是这种方法没有解决整体的问题。要分解整体，我们来看这样做的策略。

#策略2 - 前后端分离
缩小巨无霸的策略是从业务逻辑和数据访问层中拆分出表示层。典型的企业应用程序包含至少三种不同的组件：

* 表现层 - 来处理HTTP请求和实现基于Web UI的API。在具有复杂的用户界面的应用中，表现层通常有很多代码。
* 业务逻辑层 - 作为应用核心并实现业务规则的组件。
* 数据访问层 - 访问基础设施的组件比如数据库和消息代理。

在表现层逻辑和业务和数据访问的逻辑之间有清晰的缝隙。业务层有由一个或者多个外观组成的粗粒度API，它封装了业务逻辑组件。这个API是一个天然的缝隙来让你分离巨无霸的。

![](https://cdn-1.wp.nginx.com/wp-content/uploads/2016/04/Richardson-microservices-part7-refactoring.png?_ga=2.120084943.633879600.1496325382-897858824.1491727609)

优点：

* 独立开发部署和扩展。允许开发人员在表现层的快速迭代。
* 暴露了一个可以由微服务滴啊用的远程API

然而这个方式也仅仅是局部解决方案。一个或者两个应用依然是一个不可管理的巨无霸。最后用下面的方式来消除剩余的整体。

#策略3 - 抽取服务
杀手锏是将庞大的现有模块转变为独立的微服务。每次你提取一个模块并且将它转成一个服务，巨无霸就会变小。一代你转换了足够多的谋爱，巨无霸将不在是一个问题。或者它完全消失，或者变成足够小的一个服务。

##被转换模块的优先级
将模块转换成服务是耗时的，所以你应该排一下你从中得到收益的模块顺序。

这些是明显有收益的一些模块：

* 改动频繁的模块。
* 对资源需求不同于其他模块的模块。比如将具有内存数据库的模块转换成服务之后就可以把它部署在有大内存的主机上。
* 仅通过异步消息与应用通信的模块。容易且便宜，来积累经验。

##如何抽取一个模块

###模块和巨无霸之间定义一个粗粒度的接口
它大多是双向API，因为巨无霸需要服务拥有的数据，反之亦然。但通常很难实现因为模块和应用的其他部分之间存在依赖关系和细粒度的交互模式。你经常需要进行重大的代码更改才能打破依赖关系。

一旦实现了粗粒度的API，你就可以将模块变成独立的服务。还需要编写代码让服务与巨无霸通过IPC机制通信。下图是重构前后。

![](https://cdn-1.wp.nginx.com/wp-content/uploads/2016/04/Richardson-microservices-part7-extract-module.png)

Z需要被提取，但被X使用，Z又使用Y。第一部就是定义粗粒度的API。第一个接口是由X用来调用Z的入栈接口。第二个接口是Z来调用Y的出站接口。

###将模块转换为独立服务
入站和出站的接口使用IPC机制编写代码。你很可能需要通过将Z和微服务[Chassis](http://microservices.io/patterns/microservice-chassis.html)框架结合来处理比如服务发现的问题。

一旦完成之后，模块将独立于其他模块。甚至可以从头开始重写服务；在这种情况下，API代码将成为两个领域模型之间转换的反腐层。每次你提取一个服务，你就向微服务方向迈出一步。随着时间推移，整体将会缩小并且你将拥有越来越多的微服务。

#总结
将现有应用程序迁移到微服务时应用程序现代化的一种方式。你不应该通过重写应用来迁移到微服务。而是你应该增量重构你的代码，逐步替换成一系列微服务。有三种策略来满足你。随着微服务数量增长，你的开发团队的灵活性和速度将会增加。