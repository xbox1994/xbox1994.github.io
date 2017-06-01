---
layout: post
title: "[译][Microservies 4]在微服务架构中的服务发现机制"
date: 2017-05-15 23:11:02 +0800
comments: true
categories: Microservies
---

<!--more-->

##为什么用服务发现
让我们想象你正在写调用有REST API或者Thrift API的代码。为了发送请求，你的代码需要知道网络地址（IP地址和端口）。在跑在物理硬件上运行的传统应用上，服务实例的网络地址是相对静止的。比如你的代码可以读取你本地的配置文件。

在现代、基于云服务的应用，然而这是非常难以解决的问题，就像下面的图表：

![](https://cdn-1.wp.nginx.com/wp-content/uploads/2016/04/Richardson-microservices-part4-1_difficult-service-discovery.png)

服务实例动态分配网络地址。一系列服务实例会因为自动缩放、失败或升级而动态改变。所以你的客户端代码需要用更精确的服务发现机制。

有两种服务发现模式。

####客户端发现模式
当使用客户端发现，客户端对可用服务实例和经过他们的负载均衡请求有着决定网络位置的责任。客户端查询可用服务实例注册数据库。客户端用负载均衡策略去选择一个可用的服务实例然后发送请求。

下面的图标展示这个模式的结构。

![](https://cdn-1.wp.nginx.com/wp-content/uploads/2016/04/Richardson-microservices-part4-2_client-side-pattern.png)

[Netflix OSS](https://netflix.github.io/)提供一个客户端发现模式的很好的例子。[Netflix Eureka](https://github.com/Netflix/eureka)是一个服务注册表。它提供REST API给管理服务实例的注册并且查询可用实例。[Netflix Ribbon](https://github.com/Netflix/ribbon)是可以和Eureka配合使用的IPC客户端，可以处理在可用服务实例间的负载均衡。我们将在下片文章深入讨论Eureka。

客户端发现模式有很多优缺点。这种模式是相对简单的，除了服务注册表，没有其他的移动部件。并且因为客户端知道可用的服务实例，所以它可以实现智能的**基于特定应用的负载均衡策略**，比如一致地使用散列。一个很大的**缺点是需要将客户端和服务注册表结合。你必须实现客户端服务发现逻辑和框架**。

####服务端发现模式

![](https://cdn-1.wp.nginx.com/wp-content/uploads/2016/04/Richardson-microservices-part4-3_server-side-pattern.png)

客户端通过负载均衡器发送请求给服务。负载均衡器查询服务注册表并且路由每个请求到一个可用的服务实例。在客户端发现中，服务实例在服务注册表注册和注销。

AWS ELB是一个服务端发现的例子。一个ELB是通常被用来平衡外部流量。然而你可以用ELB去均衡内部的。客户端发请求通过ELB和他的DNS名字。ELB在ECS和EC2的实例间平衡流量。没有单独的服务注册表，而是EC2和ECS容器被注册到ELB自身。

HTTP服务器和负载均衡器可以用来当做服务端发现的负载均衡器。比如[这篇博文](https://www.airpair.com/scalable-architecture-with-docker-consul-and-nginx)描述用Consul Template来动态配置Nginx反向代理。Consul Template是一个可以从Consul服务注册表中拿到数据来定期重新生成任意配置文件的工具。它会运行任意的shell命令每当文件更改。在博文的描述中Consul Template生成**nginx.conf**文件用来配置反向代理，然后告诉Nginx重新加载配置。

一些部署环境比如Kubernetes和Marathon在每个主机上跑一个代理。代理充当服务端发现的负载均衡器。为了发送请求给服务端，客户端通过代理使用主机的IP地址和服务端分配的端口来路由请求。代理然后透明地转发请求到集群中某处可用的服务。

好处：服务发现的细节从客户端抽象出来。客户端只需要简单地想负载均衡器发送请求。消除实现服务发现逻辑的需要。

缺点：需要设置和管理的高可用系统组件。

##服务注册表
包含服务实例的网络位置。服务注册表需要高可用并且保持最新。客户端可以从服务注册表缓存到网络位置。然而，当信息最终变得过期，客户端无法发现服务实例。所以，服务注册表包含使用复制协议去维护一致性的一组服务器构成。

Netflix Eureka是一个服务注册表的好例子。提供了REST API来注册和查询服务实例。

Netflix通过在每个EC2可用区运行一个或多个Eureka服务来实现高可用。每个Eureka服务器都有自己的弹性IP地址。DNS TEXT记录被用来存储Eureka集群的配置，这是可用于映射可用区到Eureka服务器的网络位置的列表。当Eureka服务启动后，查询DNS去接受Eureka集群的配置，分配IP。

Eureka客户端 - 查询DNS来发现服务器的网络位置。然而，如果同一可用区没有服务器，客户端用另一个可用区的Eureka服务器。

其他服务注册表的例子：

* etcd - 高可用，分布式，一致的键值存储来分享配置和服务发现。比如Kubernetes 和Cloud Foundry.
* consul - 发现和配置服务的工具。提供API允许客户端注册和发现服务。它可以执行健康检查来决定服务可用性。
* zookeeper - 广泛使用，高性能协调服务。原来是Hadoop的子项目，现在是顶级项目。

另外，一些系统没有明确的服务注册表。服务注册表只是基础架构的内置部分。

##服务注册方式
服务实例必须能在服务注册表中注册和注销。有几种不同的方式来处理注册和注销。一个是服务实例自己去注册自己。另一个是用于其他系统组件来管理服务实例的注册。

####自注册模式
服务实例自己负责注册和注销。如果需要，服务实例发送心跳请求来防止注册过期了。

![](https://cdn-1.wp.nginx.com/wp-content/uploads/2016/04/Richardson-microservices-part4-4_self-registration-pattern.png)

一个很好的例子是[Netflix OSS Eureka client](https://github.com/Netflix/eureka)。Eureka客户端处理服务实例注册和注销的各个方面。[Spring Cloud project](http://projects.spring.io/spring-cloud/)实现包括服务发现的多种模式，可以轻松在Eureka上注册服务实例。你可以用@ EnableEurekaClient的Java注解来配置。

好处：相对简单，不需要其他系统组件

缺点：将服务实例耦合到服务注册表。你必须在每个编程语言和框架中实现注册代码。

将服务与服务注册表分离的替代方法是第三方注册模式。

##第三方注册模式
当使用第三方注册模式时，服务实例不负责向服务注册表注册自己。相反，称为*服务注册器*的另一个组件处理注册。服务注册器通过轮询部署环境或者订阅事件来跟踪

![](https://cdn-1.wp.nginx.com/wp-content/uploads/2016/04/Richardson-microservices-part4-5_third-party-pattern.png)

一个服务注册器的例子是开源的[Registrator](https://github.com/gliderlabs/registrator)。它自动注册和注销作为Docker容器的服务实例。注册商支持多个服务注册机构包括etcd和Consul。

另外一个例子是[NetflixOSS Prana](https://github.com/netflix/Prana)。主要用于非JVM语言编写的服务。它是服务实例并行运行的侧边应用程序。Prana使用Netflix Eureka注册和注销服务实例。

好处：服务和服务注册表解耦，你不需要为每种编程语言和框架实现服务注册的逻辑，而是服务实例注册功能被在专用服务中以集中方式管理。

缺点：除非内置到部署环境，否则它是你需要设置和管理的另一个高可用系统组件。

##总结
在微服务应用中，运行的服务实例集会动态更改。实例能动态分配网络位置。所以为了使客户端向服务端发送请求它必须使用服务发现机制。

服务发现的关键点是服务注册表。它2是一个可用的服务实例的数据库。提供了可管理和查询的API。服务实例通过API注册和注销到服务注册表中。

有两种服务发现模式：客户端发现和服务端发现。前者是客户端负责查询服务注册表然后选择可用实例再发送请求。后者客户端发给负载均衡器，让它帮客户端查询服务注册表和发送请求。

有两种方式注册和注销服务。自注册：服务实例自己注册自己到服务注册表中。第三方注册：第三方系统组件代表服务来操作注册和注销。

在一些部署环境中你需要用服务注册表来设置自己的服务发现基础设施比如 Netflix Eureka, etcd, or Apache Zookeeper。在其他部署环境，服务注册表是内置的。比如 Kubernetes and Marathon。他们还在扮演服务端发现路由器角色的每个集群主机上运行代理。

HTTP反向代理和负载均衡器比如NGINX能当做服务端发现的服务在均衡器。服务注册表可以推路由信息给NGINX并且触发流畅的配置更新。