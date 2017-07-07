---
layout: post
title: "玩转微服务测试"
date: 2017-07-08 00:48:13 +0800
comments: true
categories: MicroService
---
本文会讲到在微服务中，测试如何在基于其意义的基础上如何配合微服务的特点被完成，不会涉及到类似测试技巧、测试性能等实现细节，但看完你会明白的是要写什么、为什么在微服务中这样写。

与单体应用测试不同的是，微服务架构中服务之间的通信非常频繁，不同服务之间的接口变更亦是如此，所以契约测试会占更重要的地位，也是本文的重点。
<!--more-->
#单元测试如何写
首先一定要明白单元测试测的是什么。

**最小可测试单元进行检查和验证，也就是单个函数内功能逻辑是否正确**

那么这句话意味着只测单元内部的东西，不会依赖实际的外部系统，所以需要Mock出外部系统，清楚了这点下面的东西就好理解了。

一个常见并且非常老的软件后台开发分层模式是数据持久层（DAO）、服务层（Service）、业务逻辑层（Controller），下面会具体分析我们应该如何写这三块的测试。对于DDD分层模型本文不予讲解，期待日后总结。
##DAO
DAO层：分两种情况。

* 不写。因为通常来说DAO层不应该包含复杂逻辑，逻辑在上两层已经留够空间去处理，应当仅是包含SQL语句的执行或者调用数据库对应的Template工具类，所以没有什么东西可以测。所以DAO层单元测试也不应该依赖外部系统，应该放到集成测试里写。[这里](https://www.petrikainulainen.net/programming/testing/writing-tests-for-data-access-code-unit-tests-are-waste/)有篇比较极端的文章支持此观点。
* 写。与不写的观点持反对意见的例外是，在DAO层使用Hibernate/Redis Template的工具来手动调用。

##Service
Service层：

* 一定要写。服务层一般拥有比较复杂的业务逻辑，可能调用到的其他服务请Mock出来。

##Controller
Controller层：

* 不一定要写。如果有比较复杂的业务逻辑则需要写。此时测Controller中的业务逻辑会调用Service，那么请Mock Service。

#集成测试如何写
关于集成测试的定义请参看百科。优点是能发现单元测试无法发现的问题，比如连接数据库端口问题、层级之间调用问题；缺点是测试经过的代码太多，难以追踪BUG所在并且花费的时间比单元测试长很多。

想强调的有两点：

* 与单元测试相同之处在于**关注的是某个层级内部的实现**，单元测试关注的层级是方法级别，集成测试关注的级别是应用级别，换句话说就是系统内部的各个层级之间是否能正常协同工作。
* 所以应用依赖的其他服务应该Mock出来，比如对于依赖的外部服务则需要Mock出来，数据库则使用类似的H2内存数据库代替MySQL进行测试。所以我们要写的测试就的是发送请求到本地服务器及内存数据库，在内存数据库增删改查。


单元测试、集成测试提到的测试的样例代码在[这里](https://github.com/xbox1994/SpringBootExample)。

#契约测试如何写
在老马给出的测试金字塔中，契约测试处于很尴尬的位置，因为图中根本就没有，不过老马要强调的是应该具有比通过GUI运行的高级端到端测试更多的低级单元测试，也没有谈到微服务，当然在这个上下文中是比较合理的。

{% img /images/blog/2017-07-08_1.png 'image' %}

##微服务中的契约测试
然而在关于微服务架构的测试中，契约测试有着至关重要的地位。

在单体应用中，大部分功能层级之间的调用是函数方法的调用，属于在本地内存中通过Java虚拟机的实现方式的调用，如果与其他服务集成不多，那么契约测试将无用武之地。在微服务架构中，情况平衡了一些，一个服务会经常调用另外的一个服务获取或同步数据，业务一旦复杂起来，服务之间也会拥有较为复杂调用的关系，虽然BFF(Backend For Frontend)减缓了这个情况，但加强了BFF与服务之间的联系。

##契约测试是什么
契约测试是验证Provider是否按照期望的方式与Consumer进行交互，简单的说是Consumer与Provider两两之间的集成，简单来说，测试的是**双方是否通过相同的API格式进行交互**。

在一般的契约测试中，有三个模型需要被建立：

* Provider：服务的提供者，接收Consumer的请求。
* Consumer: 服务的消费者，是向Provider发起请求。
* Contract: 合同、契约，Provider与Consumer的交互方式。
* 由于双方是根据生成的契约进行测试，从而可以达到**独立测试**的好处，不需要双方之间发生网络交互。

`消费者驱动契约模式`在2006年老马引用的[这篇文章](https://martinfowler.com/articles/consumerDrivenContracts.html)中提出，在[这篇文章](http://dius.com.au/2016/02/03/microservices-pact/)中解释的更接地气，是一种测试驱动开发的契约测试模式，携带着敏捷与TDD的好处，更重要的是**将提供者开发API的局面扭转成消费者驱动开发**，由于提供者开发时不清楚消费者具体需要什么，所以在集成的时候会非常难做。将文档化的API转换为契约测试依赖的数据。

{% img /images/blog/2017-07-08_2.png 'image' %}

{% img /images/blog/2017-07-08_3.png 'image' %}

下面会讲到两个符合这种模式的工具来规范化我们的契约测试的开发，人们的约定总是不够优雅并且会被打破滴所以不得不借助工具。

##Pact
###简介
Pact就是这样的测试工具，在技术雷达中提到过多次，作为CDC的实践，Pact名列前茅。

###开发流程

1. 在Consumer通过编写请求与返回格式产生Contract
2. 编写Consumer的契约测试来测试刚刚写出来的Contract是否满足Consumer调用需求
3. 在本地测试通过后将契约文件交给Provider
4. Provider使用契约文件测试Contract是否匹配。由于两端均跑过基于Contract的测试来验证契约，所以保证了两端契约是匹配的，以后不管哪一方修改端口之后一定会触发契约测试失败。

###例子
Pact支持很多语言，如Pact-JVM, Pact Ruby, Pact .NET, Pact Go, Pact.js, Pact Swift。参见[官网](https://docs.pact.io/)获取样例。

##Spring Cloud Contract
###简介
该项目于2015年开始创建核心代码，GitHub上Star虽然不多，但是功能比较强大，[这里](http://www.infoq.com/cn/news/2017/04/spring-cloud-contract)有一篇关于作者的访谈文章，对于理解这个项目比较有帮助。

###开发流程

1. 在Consumer中使用TDD开发，编写好发送请求的测试代码
2. 在Provider内定义并生成Contract，SCC会根据Contract自动生成测试代码作为契约测试，此时跑Provider的契约测试肯定是挂的
3. 实现Provider，跑过契约测试之后将生成的契约文件交给Consumer当做Mock服务器的契约规范来验证Contract是否匹配
4. 在Consumer端编写契约测试后用SCC根据契约文件启动Mock服务器来测试Consumer是否符合契约

###例子
官方有两个实现的例子，在[这里](http://cloud.spring.io/spring-cloud-contract/spring-cloud-contract.html#_step_by_step_guide_to_cdc)，忍不住吐槽一下，这个项目都两年了才100多个星星，跟着Spring和Cloud两大标签走竟然还能这么少的星星，是后端技术人员的保守跟前端那种几个月上万颗星星的浮夸相反吗？还有要注意的是除了官方文档几乎没有任何资料可以查询，给的例子用的又是很多处于BUILD版本的库，这是使用它最大的难点。

###疑问
你应该会误认为SCC使用的是提供者驱动契约模式，但其实并不是，刚刚向SCC的作者Grzejszczak确认了这一点，因为CDC的思想是消费者有需求的时候然后根据这个需求去开发提供者的API，注意第一步当我在Consumer开发的时候已经意识到需要什么API了，然后进行第二步。原话是

> that means that the source of truth in terms of contract validity is the provider side but what drives the change of the contract is the consum

##E2E测试是什么

未完待续

##注
以上是本人总结，难免偏颇，不过本人会根据本人持续变化的理解持续更新。

V1.0：2017.07.07 发表