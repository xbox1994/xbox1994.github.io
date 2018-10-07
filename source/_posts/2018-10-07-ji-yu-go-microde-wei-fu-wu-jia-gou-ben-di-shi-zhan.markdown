---
layout: post
title: "基于Go Micro的微服务架构本地实战"
date: 2018-09-28 22:43:58 +0800
comments: true
categories: 
---

本项目Github地址：https://github.com/xbox1994/GoMicroExample

<!-- more -->

## 简介
Go Micro是一个插件化的基础微服务框架，它是一部分微服务工具的集合。基于该框架可以构建出微服务应用程序。Micro的设计哲学是“可插拔”的插件化架构。在架构之外，它默认实现了consul作为服务发现，通过http、protobuf、进行通信。里面包含几乎所有微服务组件，并且支持非常好的拓展性，通过接口的设计方式，让我们可以拓展一些自己的组件，如服务发现、身份校验、配置管理等。另外，Micro工具包是建立在Go Micro基础之上的微服务工具包，提供更丰富的工具支持。

但即使称自己为框架，但是不是一个完整成熟的微服务体系，所以在下文中会以成熟的微服务体系为目标，在Go Micro的基础上添砖加瓦，以一个简单的问候系统为例搭建出一套相对完整的微服务架构。

## Go Micro使用
https://github.com/micro/go-micro

根据Getting started部分的教程，结合Consul、gRPC可以搭建起一个服务之间调用的Demo，这里就不多说了。但是这个Demo和我们想要的微服务架构还是差太多。常见的微服务架构如下图：

{% img /images/blog/2018-09-28_1.jpg 'image' %}

现在我们仅仅实现了Service Discovery以及两个srv之间的交互。下面将一步一步将微服务的主要组件加入进来。

## 服务发现注册
服务注册发现是将所有服务注册到注册中心从而注册中心能提供一个可用的服务列表，让各个服务之间知道彼此的状态与地址。比如客户端可以向注册中心发起查询，来获取服务的位置。

{% img /images/blog/2018-09-28_2.jpg 'image' %}

* 当User Service启动的时候，会向Consul发送一个POST请求，告诉Consul自己的IP和Port
* Consul 接收到User Service的注册后，每隔10s（默认）会向User Service发送一个健康检查的请求，检验User Service是否健康
* 当Order Service发送 GET 方式请求/api/addresses到User Service时，会先从Consul中拿到一个存储服务 IP 和 Port 的临时表，从表中拿到User Service的IP和Port后再发送GET方式请求/api/addresses
* 该临时表每隔10s会更新，只包含有通过了健康检查的Service

### Consul
Consul在Go Micro中用作默认服务发现系统。每当发生被注册过的服务之间的调用时，会先从Consul中查询可用的IP与Port，才能定位被调用的服务地址。对于已经注册过的服务，每隔一段时间会向服务发送一个Health Check的请求来检验服务是否正常。

在本地用最简单的方式启动Consul：`consul agent -dev`

在Go Micro中，通过在启动服务时执行自身在服务发现中的名称，就能在启动服务时自动注册到Consul中：

```go
greeterService := micro.NewService(micro.Name("go.micro.api.greeter"))
greeterService.Init()
if err := greeterService.Run(); err != nil {
	log.Fatal(err)
}
```

在你的某个服务使用`go build`打包完成之后可以在启动的时候添加`--registry_address`参数来指定Consul的地址。

## API Gateway
API Gateway 是随着微服务概念一起兴起的一种架构模式，它用于解决微服务过于分散，没有一个统一的出入口进行流量管理的问题。它类似于面向对象的外观模式。流量管理的具体问题包括：封装了内部系统架构并且提供了每个客户端定制的API、身份验证、监控、负载均衡、缓存、数据通信协议转换、统一维护流量路由表。

{% img /images/blog/2018-09-28_3.jpg 'image' %}

API Gateway的缺点是，它必须是一个被开发、部署、管理的高可用组件。还有一个风险是它变成开发瓶颈。开发人员必须更新API网关来暴露每个微服务接口。因此更新API网关的过程越少越好。然而，对于大多数现实世界的应用，使用API网管是有意义的。

### Micro Api
Micro Api是Micro工具包中实现API网关的工具，它提供HTTP并使用服务发现动态路由到适当的后端。API的请求通过HTTP提供，并通过RPC进行内部路由。我们可以利用它进行服务发现，负载平衡，编码和基于RPC的通信。

{% img /images/blog/2018-09-28_4.png 'image' %}

上图是官方给的Micro Api路由图，Micro Api是一个请求路由、格式转换的工具，只需要执行`micro api`来启动它，就可以像其他服务一样自动注册到Consul，在`8080`端口开启所有外界HTTP请求的访问入口，并将请求路由、转换到内部中。至于向加一些其他功能比如鉴权则需要实现Micro Api的插件或者在每个服务中加上鉴权的代码。当然，Consul的端口与外界访问端口都是可以配置的。

### 数据格式转换
前端需要使用Json来进行通信，但后端使用Protobuf在服务之间通信。对于外部请求，Micro Api通过接收前端HTTP请求，将请求转换之后发送到内部服务，对于服务间的请求，A服务可以直接使用go语言的gRPC客户端调用B服务的接口。相比在使用Restful方式完成服务之间的相互访问，GRPC能提供更好的性能，更低的延迟，并且生来适合与分布式系统。

gRPC是一个高性能、通用的开源RPC框架，其由Google主要面向移动应用开发并基于HTTP/2协议标准而设计，同时基于标准化的IDL（ProtoBuf）来生成服务器端和客户端代码, ProtoBuf服务定义可以作为服务契约，因此可以更好的支持团队与团队之间的接口设计，开发，测试，协作。

protoc-gen-micro是与Micro工具包类似的一个工具，在gRPC的基础之上封装了一层更加规范和易于使用的接口，我们只需要写出proto文件，执行`protoc --proto_path=proto --proto_path=${GOPATH} --micro_out=proto --go_out=proto greeter.proto`就能生成go语言版本接口文件，接口文件中定义了服务提供者应该实现哪些接口，服务调用者应该如何使用的接口。现在就需要实现服务端的接口之后在启动服务的代码中注册该proto对应的接口，如下：

proto文件：
```proto
syntax = "proto3";

import "github.com/micro/go-api/proto/api.proto";

service Greeter {
    rpc Hello(go.api.Request) returns(go.api.Response) {};  //对外的服务接口必须使用go-api的request与response，因为是与Micro Api结合使用需要统一接口
                                                            //对内的服务可以自定义参数与返回，可参考service/user/proto/user.proto
}
```

main.go：
```go
type Greeter struct {
	userClient user.UserService
}

func (ga *Greeter) Hello(ctx context.Context, req *go_api.Request, rsp *go_api.Response) error {
	log.Print("Received Greeter.Hello API request")
	return nil
}

func main() {
	greeterService := micro.NewService(
		micro.Name("go.micro.api.greeter"),
	)
	greeterService.Init()
	greeterApi.RegisterGreeterHandler(greeterService.Server(), &Greeter{
		userClient: user.NewUserService("go.micro.api.user", greeterService.Client())})

	if err := greeterService.Run(); err != nil {
		log.Fatal(err)
	}
}
```

### 统一流量入口，维护路由关系
Micro Api根据HTTP请求路径、内部服务名称、被调用方法名建立了如下的映射关系，将所有前端传递过来的请求根据该表路由到后端服务中，可以避免从前端直接调用多个后端服务而产生的混乱的交互逻辑，也相当于避免暴露出后端服务。

Path|Service|Method
----|----|----
/foo/bar	|	go.micro.api.foo	|	Foo.Bar
/foo/bar/baz	|	go.micro.api.foo	|	Bar.Baz
/foo/bar/baz/cat	|	go.micro.api.foo.bar	|	Baz.Cat

所以我们在写服务的时候需要注意服务的名称与方法名正确命名，比如`http://localhost:8080/greeter/hello`会映射到如下方法：

```go
type Greeter struct {
	userClient user.UserService
}

func (ga *Greeter) Hello(ctx context.Context, req *go_api.Request, rsp *go_api.Response) error {
}
```

### 用户身份鉴定
该功能是除了登录功能的每一个API都会调用的功能，甚至为了不嵌入到每一个服务中，统一在这里处理较好。对于容器化与无状态服务，推荐使用JWT进行身份验证。

## 配置中心
由于Micro Config不支持从Git上获取配置文件，所以选用Spring Cloud Config来实现。

Spring Cloud Config的目标是将各个微服务的配置文件集中存储一个文件仓库中（比如系统目录，Git仓库等等），然后通过Config Server从文件仓库中去读取配置文件，而各个微服务作为Config Client通过给Config Server发送请求指令来获取特定的Profile的配置文件，从而为自身的应用提供配置信息。同时还提供配置文件自动刷新功能。

{% img /images/blog/2018-09-28_5.jpg 'image' %}

具体配置过程参看：https://www.jianshu.com/p/e60f3cceaace 以及本项目中的`config`文件夹。

## 服务容错保护
服务熔断：当服务A调用服务B的请求满足一定的规则，比如10秒内请求数达到20个，并且有一半以上的请求失败了，此时我们通过切断对服务B的调用来保护系统的整体响应，这种操作即为服务熔断。  
服务降级：在服务B被熔断之后，服务A不会真正地调用服务B。取而代之的是，我们在服务A中定义一个服务降级逻辑（通常是一个fallback接口），此时服务A会直接调用服务降级逻辑快速获取返回结果。

```go

type clientWrapper struct {
	client.Client
}

func (c *clientWrapper) Call(ctx context.Context, req client.Request, rsp interface{}, opts ...client.CallOption) error {
	return hystrix.Do(req.Service()+"."+req.Method(), func() error {
		return c.Client.Call(ctx, req, rsp, opts...)
	}, func(err error) error {
		// 可以在这里自定义服务降级逻辑
		log.Printf("fallback error!!!!!  %v", err)
		return err
	})
}

func NewClientWrapper() client.Wrapper {
	return func(c client.Client) client.Client {
		return &clientWrapper{c}
	}
}

func Configure(names []string) {
	// hystrix有默认的参数配置，这里可以对某些api进行自定义配置
	config := hystrix.CommandConfig{
		Timeout:               2000,
		MaxConcurrentRequests: 100,
		ErrorPercentThreshold: 25,
	}
	configs := make(map[string]hystrix.CommandConfig)
	for _, name := range names {
		configs[name] = config
	}
	hystrix.Configure(configs)

    // 还能结合hystrix dashboard来将服务状态动态可视化出来
	hystrixStreamHandler := hystrix.NewStreamHandler()
	hystrixStreamHandler.Start()
	go http.ListenAndServe(net.JoinHostPort("", "8181"), hystrixStreamHandler)
	log.Println("Launched hystrixStreamHandler at 8181")
}
```

## 整体架构
以 greeter/hello 为例，请求流程图如下：

{% img /images/blog/2018-09-28_6.jpg 'image' %}

1. 访问greeter/hello
2. Micro Api解析请求，验证身份是否有效，决定请求是否继续传递，如果有效，则将解析出来的用户信息写到header中
3. GreeterService接收到gRPC请求并路由到Greeter.Hello方法中，调用其中的逻辑，尝试发送请求到UserService得到用户的其他信息，header也转发过去
4. UserService根据header中得到的id查询数据库得到具体的用户信息并返回

在服务间请求调用过程中，会有Hystrix来提供服务容错机制。在所有服务启动之前，会请求Config Service来获得对应服务的对应环境的配置信息。

## TODO
由于相关资料太少，搭建的过程比较坎坷，实现的方式也有待改进，会在日后使用的过程中继续优化。

以上仅仅是在本地搭建的一个微服务架构，而线上环境则需要更多服务节点以及更健壮的架构支持，比如API Gateway可能有多个，需要在前面再加一层Nginx进行负载均衡，那么如何让可能动态改变的API Gateway服务地址写入到Nginx的静态配置文件中？此时就需要结合consul-template，动态将地址更新Nginx的配置文件中。还有比如添加EFK、Zipkin、Promethus等日志监控机制。

还有很重要的一个点是与Docker、容器编排工具结合来实施自动化可伸缩动态部署，Go Micro也能够支持K8S，只是例子较少，等待日后开发构建。

最后一个问题是流水线自动化部署，使用Jenkins或GoCD工具将部署流程给自动化起来，比如在build阶段生成docker image然后push到registry中，在deploy阶段调用容器编排工具触发容器自动更新image重启服务。

## 参考
https://gocn.vip/question/1999  
http://sjyuan.cc/topics/  
