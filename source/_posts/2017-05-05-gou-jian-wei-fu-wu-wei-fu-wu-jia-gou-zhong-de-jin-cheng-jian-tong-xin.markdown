---
layout: post
title: "[译][MicroService 3]构建微服务:微服务架构中的进程间通信"
date: 2017-05-05 14:39:20 +0800
comments: true
tags: MicroService
---

在单体应用上，组件通过语言级别的方法或者方法彼此调用。相比之下，基于微服务的应用是在多台机器上运行的分布式系统。每个服务实例通常是一个进程。

<!--more-->

因此，如下图所示，服务必须用进程间通信（IPC）机制进行交互。

![](https://cdn-1.wp.nginx.com/wp-content/uploads/2015/07/Richardson-microservices-part3-monolith-vs-microservices-1024x518.png)

稍后我们会看一下特定的IPC技术，但是首先让我们探索各种设计问题。

##交互方式
当为服务选择IPC机制时，首先要考虑服务是如何交互的。有很多客户端服务端交互方式。他们可以被分成两个维度。

* 一对一 - 每个客户端的请求都被每一个服务实例处理
* 一对多 - 每个请求都被多个服务实例处理

第二个维度在同步和异步交互方面：

* 同步 - 客户端期望及时响应但可能被服务器阻塞
* 异步 - 客户端在等待回复时不会阻塞自己，响应不一定立即被服务器发送

下表显示了各种交互方式。

||一对一|一对多|
|------|------|------|
|同步|请求/回复|—| 
|异步1|通知|发布/订阅|
|异步2|请求/异步回复|发布/异步回复|

下面是一对一交互：

* 请求/回复 - 客户端发送请求给服务并且等待回复。客户端期待回复能及时到达。在基于线程的应用中，处理请求的线程可能被阻塞。
* 通知 - 客户端发送请求给服务，但是不期待回复。
* 请求/异步响应 - 客户端发送请求给服务，该服务异步回复。客户端不会等待并且假设回复可能不会马上到达。

下面是一对多交互：

* 发布/订阅 - 客户端发布通知信息，可能被0或者更多感兴趣的服务消费掉
* 发布/异步响应 - 客户端发布请求信息，对感兴趣的服务的响应等待一定的时间

每个服务通常使用这些交互方式的组合。对于一些服务，一种IPC机制就够了。其他服务可能需要用IPC机制的组合。下面的图表展示了当用户请求时，出租车应用中可能有的内部交互。

![](https://cdn-1.wp.nginx.com/wp-content/uploads/2015/07/Richardson-microservices-part3-taxi-service-1024x609.png)

服务用**通知**，**请求/回复**和**发布/订阅**的组合。比如乘客的智能手机发送**通知**给旅程管理服务区请求一次打车。旅程管理服务通过用**请求/回复**调用乘客服务来验证乘客的账户是激活的。旅程管理服务就可以创建旅程并且用**发布/订阅**去通知其他服务，包括用调度器来定位可用的司机。

##定义API
服务的API是服务和客户端的合同。不管你选什么IPC机制，用某种接口定义语言（IDL）定义服务的API是很重要的。用[API-first approach](http://www.programmableweb.com/news/how-to-design-great-apis-api-first-design-and-raml/how-to/2015/07/10)去定义服务是很好的参考。你通过编写接口和审查客户端开发人员来开始服务的开发。只有在对API定义进行迭代之后才能实现服务。进行这样的设计可以增加构建符合客户需求的服务的机会。

如本文后面你将看到的，API定义的的性质取决于你选择哪种IPC机制。如果你用消息传递，API包含消息通道和消息种类。如果你用HTTP，API包含URL和请求与回复的格式。稍后我们将更详细地描述一些IDL。

##不断更新的API
服务的API总是随着时间变化。在单体应用中，更改API和更新所有调用者通常是直接的。在基于微服务的应用中，即使全部的消费者都是统一应用中的其他服务，还是比较困难。你通常无法强制所有客户端去升级。此外，你可能会[逐步部署新的版本的服务](http://techblog.netflix.com/2013/08/deploying-netflix-api.html)，以便新老版本的服务同时运行。有一个处理问题的策略非常重要。

处理API的更改方式取决于改变的大小。一些改变是次要的并且向后兼容以前的版本。比如，你可能给请求和相应添加属性。涉及客户端和服务端是有意义的，以便遵守鲁棒性原则。客户端用老的API应该继续与新版本服务正常工作。服务对瘸着的请求提供默认值并且客户端忽略任何额外响应属性。用IPC机制和响应消息传递格式非常重要，你可以轻松开发你的API。

但是有时候你必须对API进行主要的不兼容的更改。因为你不能强制客户端立即升级，服务必须支持老版本的API一段时间。如果你用基于HTTP的机制比如REST，一个方法是把版本号嵌入URL中。每个服务实例可能同时处理多个版本。或者你可以部署每个处理特定版本的不同实例。

##处理部分失败
在前面关于API网关的文章所述，在分布式系统中存在着部分故障的风险。因为客户端和服务是独立的进程，服务可能不会及时响应客户端的请求。由于故障或者维护，服务可能会关闭。或者服务变得过载并且响应速度非常慢。

比如，考虑下这篇文章的[产品详情方案](https://www.nginx.com/blog/building-microservices-using-an-api-gateway/#product-details-scenario)。我们假设推荐服务没有响应。客户端的垃圾实现可能无限期地等待响应。结果不仅会导致用户体验不好，也会消耗线程这样的宝贵资源。最终运行时会用完线程并变得无法响应，就和下面的图一样。

![](https://cdn-1.wp.nginx.com/wp-content/uploads/2015/07/Richardson-microservices-part3-threads-blocked-1024x383.png)

为了防止这个问题，你必须设计你的服务去处理部分失败。

一个好的方法是使用[Netflix描述的方法](http://techblog.netflix.com/2012/02/fault-tolerance-in-high-volume.html)。这种策略用来处理部分错误包括：

* 网络超时 - 当等待回复时永远不会无限期等待并且总是使用超时策略。这可以确定资源不会被无限期被捆绑在一起
* 限制未完成的请求的数量 - 对于客户端可以使用特定服务的未完成请求数量强加一个上线。如果到达限制，提出额外的请求可能没有意义，这些尝试需要立即失败。
* [断路器模式](http://martinfowler.com/bliki/CircuitBreaker.html) - 跟踪成功和失败的数量。如果错误率超过预定的阈值，断路器跳闸，以便以后的尝试失败。如果很多请求失败，建议服务设为不可用，发请求也是没有意义的。超时之后，客户端应该再次尝试，如果成功，关闭断路器。
* 提供备用 - 当请求失败后执行备用逻辑。比如返回缓存数据或者默认值比如空的推荐。

[Netflix Hystrix](https://github.com/Netflix/Hystrix)是一个实现这些或者其他模式的开源库。如果你用JVM你应该考虑用它。

##IPC技术
有很多不同的IPC句式可以选择。服务能用同步请求/响应的通信机制比如基于HTTPS REST或者Thrift。或者，他们可以用异步的，基于消息的交流机制比如AMQP或STOMP。有很多不用的消息格式。服务能用易读的，基于文本的个数比如JSON和XML。或者二进制格式比如Avro或者协议缓冲区。后面我们将看一下同步的IPC机制，但是首先我们来讨论异步IPC机制。

####异步，基于消息的通信
当用异步交换消息，多进程通信。客户端通过发送消息给服务。如果服务预期回复，则通过发送单独的消息给客户端实现。因为通信是异步的，客户端不会等待回复。而是假设客户端不会立即受到回复。

消息由标题（比如发件人之类的元数据）和消息体组成。消息通过通道交换。任何数量的生产者都能发送消息给通道。相似的，任何数量的消费者可从通道接受消息。有两种通道，点对点或者发布订阅。点对点频道向正在从通道读取的消费者提供一个消息。服务使用点对点通道来描述前面提到的一对一交互风格。发布订阅通道将每个消息传递给全部附加的消费者。服务用发布订阅通道给上面描述的一对多风格。

下图显示了出租车应用可能的发布订阅通道：

![](https://cdn-1.wp.nginx.com/wp-content/uploads/2015/07/Richardson-microservices-part3-pub-sub-channels-1024x639.png)

旅行管理服务通过将旅途创建这个消息写到**针对旅程创建这个业务的发布订阅通道**来通知感兴趣的服务比如**调度器**。调度器发现可用的司机并通过写入司机推荐这个消息给**分发乘客的发布订阅通道**的方式来通知其他服务。

有很多消息系统可以选择。你应该选择一个支持各种语言的一种。一些消息系统支持标准协议比如AMQP和STOMP。其他消息系统有专有的但是记录的协议。有很多开源消息系统去选择，包括RabbitMQ, Apache Kafka, Apache ActiveMQ,和 NSQ。在高层次上来说，他们都支持消息和通道。他们都努力做到可靠，高性能和可扩展。然而，每个消息模型的细节存在不同的差异。

下面是用消息通信的优点：

* 将客户端与服务端分离 - 客户通过发送消息个合适的通道来发送请求。客户端完全不需要关注服务实例。也不需要用发现机制来确定服务的位置。
* 消息缓冲 - 使用比如HTTP这样的同步请求/响应协议，在客户端和服务端交互区间必须可用。相比之下，消息代理将消息排队知道被消费者处理。比如即使订单履行系统慢或者不可用，在线商店也能接受来自客户的订单。订单消息就被简单的放入队列中。
* 灵活的客户端-服务端交互 - 消息传递支持所有前面描述的交互方式
* 明确的进程间通信 - 基于RPC的机制尝试去调用远程服务就像本地服务一样。然而，因为物理规律和部分失败的可能性，实际上是完全不同的。消息通信使得这些差异非常明确，因此开发人员没有被弄虚作假的感觉。

下面是缺点：

* 额外操作的复杂性 - 消息系统是另一个必须安装、配置的系统。消息代理必须高可用，否则系统的可靠性会受到影响。
* 实现基于请求/响应的交互的复杂性 - 请求/响应风格的交互有一些工作去做。每个请求消息必须包含应答通道表示符和相关标识符。服务将相关ID写入响应信息。客户端使用相关ID来将请求和响应匹配。通常使用直接支持请求/响应的IPC机制更容易。

现在我们已经看过使用基于消息的IPC，我们来看看基于请求/响应的IPC。

####同步，请求/响应IPC
客户端发送请求，服务端处理请求返回。在很多客户端中，当等待响应时线程会阻塞。其他客户端可能用异步，事件驱动的方式，如Futures或Rx Observables。然而，和消息通信不同，客户端假定响应会立马收到。有很多协议可供选择。两种流行的协议是REST和Thrift。

#####REST
在现在，用REST开发是很流行的方式。REST是一种用HTTP的IPC机制。在REST中核心概念是资源，通常代表业务实例比如顾客和产品或者业务实体的集合。REST用HTTP来操纵资源。比如GET返回资源的表现形式（XML或者JSON对象）。POST代表创建新资源，PUT请求更新资源。引用Roy Fielding的创建者：


>REST提供一组架构约束，当作为整体使用时，强调了组件交互的可扩展性，接口的通用性，独立部署组件和中间组件来减少交互延迟，实施安全性和封装旧系统
- Fielding，[架构艺术和基于网络的软件架构设计](http://www.ics.uci.edu/~fielding/pubs/dissertation/top.htm)

下图显示出租车应用可能使用REST的方式：

![](https://cdn-1.wp.nginx.com/wp-content/uploads/2015/07/Richardson-microservices-part3-rest.png)

乘客的智能手机通过向旅行管理服务/trips发送POST请求来请求一次旅行。该服务通过发送GET请求给乘客管理服务得到乘客信息。在验证乘客是授权之后再创建旅行。旅行管理服务创建旅行并返回201给智能手机。

很多开发人员声明他们基于HTTP的API用的是REST。但是就像Fielding在[这篇文章](http://roy.gbiv.com/untangled/2008/rest-apis-must-be-hypertext-driven)中描述的，事实不是这样的。Leonard Richardson定义了非常有用的包含下面级别的[REST成熟度模型](http://martinfowler.com/articles/richardsonMaturityModel.html)。

* 第0层级 - 0级的API客户端通过发送HTTP POST请求给单个URL来触发服务。每个请求指定要执行的操作，操作的目的，和任何参数。
* 第1层级 - API支持资源的意图。要对资源执行相关操作，客户端发送POST请求表示动作和参数。
* 第2层级 - API支持HTTP行为：GET来获取，POST是创建，PUT是更新。请求查询参数和主题指定动作参数。这使服务能利用web基础设施比如用GET请求缓存。
* 第3层级 - 基于HATEOAS原则（Hypertext As The Engine Of Application State）。基本思想是，GET请求返回的资源包含用于这个资源上执行允许的操作的链接。比如客户端可以在订单页面上取消一个订单，这个页面是之前通过GET请求得到的订单页面。[HATEOAS的好处](http://www.infoq.com/news/2009/04/hateoas-restful-api-advantages)包括不再必须将URL写在客户端代码中。另一个好处是因为资源的表示包括可允许操作的链接，所以客户端不需要猜测当前状态要执行什么动作。

使用基于HTTP的协议有很多好处：

* HTTP是简单和友好的
* 你可以用比如Postman或者curl来测试HTTP API
* 直接支持请求/响应方式的交流
* 防火墙友好
* 不需要中间代理，简化了系统的架构

HTTP有一些缺点：

* 它直接支持请求/响应风格。你可以用HTTP或者通知，但是服务器比如始终发送HTTP响应。
* 因为客户端和服务直接交流（没有中介缓冲区），他们必须在交互期间同时运行
* 客户端必须知道每个服务的位置。和上一篇文章描述的，在现代应用中这是一个常见的问题。客户端必须使用服务发现机制去定位服务实例。

开发人员社区最近发现了定义RESTful API的价值。有几个选项，包括RAML和Swagger。一些IDL比如Swagger允许你定义请求和响应的消息。其他比如RAML需要你用独立的规范比如JSON。处理描述API之外，IDL通常有工具生成客户端和服务端框架。

#####Thrift
Apache Thrift是REST的一个有趣的替代方案。它是一个跨语言编写的RPC客户端和服务器的框架。Thrift提供C风格的IDL去定义你的API。你使用Thrift编译器去生成客户端和服务端框架，同时支持多种语言。

Thrift接口包含一个或多个服务。服务定义类似于Java接口。它是强类型方法的集合。Thrift方法可以返回（可能空）一个值或者他们定义为单向。返回值的方法实现了请求/响应的交互风格。客户端等待响应，并可能抛出异常。单向方法对应于通知这样的交互方式。服务端不发送响应。

Thrift支持各种消息格式，JSON,二进制，紧凑二进制。二进制比JSON更有效率因为解码更快。而却顾名思义，紧凑二进制是节省空间的格式。当然JSON是人性化和浏览器友好的。Thrift还提供包括原始TCP和HTTP在内的选择。原始TCP可能比HTTP更有效率。然而，HTTP是对防火墙，浏览器，我们来说都更人性化的。

####消息格式
Thrift可能只支持少量的消息格式，也许只有一个在这两种情况下，使用跨语言消息格式非常重要。即使你现在用单一语言写微服务，你将来也可能用到别的语言。

消息格式有两种主要类型：文本和二进制。基于文本的格式有JSON和XML。这些格式的优点不仅是他们是人类可读的，他们也是自我描述的。JSON的对象属性通过键值对代表。相似的，XML的属性由元素和值代表。这使得消息的消费者可以挑选他们自己感兴趣的值并忽略别的。因此，微小消息格式的变更可以很容易向后兼容。

XML文档结构由[XML模式](http://www.w3.org/XML/Schema)指定。随着时间的推移，开发人员社区已经意识到JSON需要一个类似的机制。一个选择是[JSON模式](http://json-schema.org/),或者作为IDL的一部分，Swagger。

基于文本的消息格式缺点往往是冗长的，特别是XML。因为消息是自我描述的。每个消息除了他们的值还包括属性的名字。其他缺点是解析文本的开销。因此你可能想去考虑用二进制格式。

有几种二进制可以选择。入股你用Thrift，可以选择二进制Thrift。如果你选择消息格式，热门的选项包括Protocol Buffers和Apache Avro。这两种提供IDL来定义自己的消息格式。然而，一个区别是Protocol Buffers使用标记资源，Apache Avro需要知道模式才能解释消息。因此，Protocol Buffers的API演进比Apache Avro更简单。[这篇博文](http://martin.kleppmann.com/2012/12/05/schema-evolution-in-avro-protocol-buffers-thrift.html)是Protocol Buffers和Apache Avro的绝佳比较。

##总结
微服务必须使用IPC机制来通信。当设计服务如何沟通时，你需要考虑很多问题：服务如何交互，怎样为每个服务指定API，怎样更新API，怎样处理部分故障的问题。有两种IPC机制可以用，**异步消息**或者**同步请求/响应**。在本系列的下篇文章中，我们将看到微服务中服务发现的问题。

## 号外号外
最近在总结一些针对**Java**面试相关的知识点，感兴趣的朋友可以一起维护~  
地址：[https://github.com/xbox1994/2018-Java-Interview](https://github.com/xbox1994/2018-Java-Interview)
