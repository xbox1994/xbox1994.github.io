---
layout: post
title: "基于Go Micro的微服务架构本地实战"
date: 2019-03-26 17:00:00 +0800
comments: true
categories: 后台
---

本项目Github地址：https://github.com/xbox1994/GoMicroExample

<!-- more -->

## 简介
Go Micro是一个插件化的基础微服务框架，它是一部分微服务工具的集合。基于该框架可以构建出微服务应用程序。Micro的设计哲学是“可插拔”的插件化架构。在架构之外，它默认实现了consul作为服务发现，通过http、protobuf、进行通信。里面包含几乎所有微服务组件，并且支持非常好的拓展性，通过接口的设计方式，让我们可以拓展一些自己的组件，如服务发现、身份校验、配置管理等。另外，Micro工具包是建立在Go Micro基础之上的微服务工具包，提供更丰富的工具支持。

但即使称自己为框架，但是不是一个完整成熟的微服务体系，所以在下文中会以成熟的微服务体系为目标，在Go Micro的基础上添砖加瓦，以一个简单的例子为例搭建出一套相对完整的微服务架构。

## Go Micro使用
https://github.com/micro/go-micro

根据Getting started部分的教程，结合consul、gRPC可以搭建起一个服务之间调用的Demo，这里就不多说了。但是这个Demo和我们想要的微服务架构还是差太多。常见的微服务架构如下图：

{% img /images/blog/2018-09-28_1.jpg 'image' %}

现在我们仅仅实现了Service Discovery以及两个srv之间的交互。下面将一步一步将微服务的主要组件结合Go Micro的[核心组件](https://micro.mu/docs/go-micro-architecture_cn.html#%E7%9B%B8%E5%85%B3%E5%8C%85)（注册、选择器、传输、代理、编码、服务端、客户端）加入进来，同时包含一些新手的使用经验。

## 服务发现注册
#### 原理
服务注册发现是将所有服务注册到注册中心从而注册中心能提供一个可用的服务列表，让各个服务之间知道彼此的状态与地址。比如客户端可以向注册中心发起查询，来获取服务的位置。下面均以consul为例，说明原理。

{% img /images/blog/2018-09-28_2.jpg 'image' %}

* 当User Service启动的时候，会向consul发送一个POST请求，告诉consul自己的IP和Port
* consul 接收到User Service的注册后，每隔10s（默认）会向User Service发送一个健康检查的请求，检验User Service是否健康
* 当Order Service发送 GET 方式请求/api/addresses到User Service时，会先从consul中拿到一个存储服务 IP 和 Port 的临时表，从表中拿到User Service的IP和Port后再发送GET方式请求/api/addresses
* 该临时表每隔10s会更新，只包含有通过了健康检查的Service

每当发生被注册过的服务之间的调用时，会先从consul中查询可用的IP与Port，才能定位被调用的服务地址。对于已经注册过的服务，应该让consul客户端每隔一段时间会向服务发送一个Health Check的请求来检验服务是否正常。

在Go Micro中，通过在启动服务时执行自身在服务发现中的名称，就能在启动服务时自动注册到consul中：

```go
greeterService := micro.NewService(micro.Name("go.micro.api.greeter"))
greeterService.Init()
if err := greeterService.Run(); err != nil {
	log.Fatal(err)
}
```

#### 健康检查机制带来的问题（Go Micro组件 - 注册 Registry）
在Go Micro中可以使用consul、etcd、zookeeper、dns、gossip等等提供支持。服务使用启动注册关机卸载的方式注册。服务可以选择性提供过期TTL和定时重注册来保证服务在线，以及在服务不在线时把它清理掉。默认使用的注册中心是mdns，可以使用环境变量`MICRO_REGISTRY`或命令行`--registry`指定为consul或其他注册中心。

使用consul之后的坑在于，在程序关闭的时候，如通过IDEA的调试模式启动的程序，或在K8S容器中运行的程序，在退出的时候可能不会发送Registering node的请求，导致consul依然认为该服务正常，依然会把已经关闭的节点当成健康服务，这是go micro中使用consul的[健康检查机制](https://www.consul.io/docs/agent/checks.html)的问题。

在Go Micro源码的micro/go-micro/registry/consul_registry.go中，如果不使用TCP或TTL注册方式，则不会告知consul，我已经配置了一个健康检查的机制，所以除非我自己手动解除或在consul里发送命令删除，该节点一直会存在。

```go
var check *consul.AgentServiceCheck

if regTCPCheck {
	deregTTL := getDeregisterTTL(regInterval)

	check = &consul.AgentServiceCheck{
		TCP:                            fmt.Sprintf("%s:%d", node.Address, node.Port),
		Interval:                       fmt.Sprintf("%v", regInterval),
		DeregisterCriticalServiceAfter: fmt.Sprintf("%v", deregTTL),
	}

	// if the TTL is greater than 0 create an associated check
} else if options.TTL > time.Duration(0) {
	deregTTL := getDeregisterTTL(options.TTL)

	check = &consul.AgentServiceCheck{
		TTL:                            fmt.Sprintf("%v", options.TTL),
		DeregisterCriticalServiceAfter: fmt.Sprintf("%v", deregTTL),
	}
}
```

所以我们必须添加额外的配置比如`MICRO_REGISTER_TTL=10;MICRO_REGISTER_INTERVAL=5;`让我们使用TTL的方式，如果10秒内我的服务没有向consul发送请求，服务则是断开状态。也可以使用TCP方式让consul来请求你的服务检查是否健康

但这种方式并不是完美的，如果使用上面的参数，在服务关闭的5秒后，consul中该服务依然是健康的，其他服务请求consul会拿到这个已经关闭的服务的地址。由于consul和etcd都没有和zookeeper的一样的临时节点，无法做到立马在服务关闭的时候让注册中心感知，所以在实时性要求高的服务上下线的情景下应该使用zookeeper

另一方面，上面我们写了三种健康检查的具体方式，可以大体分为客户端心跳（TTL、临时节点）和服务端主动探测（TCP）两种方式。客户端心跳中，长连接的维持和客户端的主动心跳都只是表明链路上的正常，不一定是服务状态正常。服务端主动调用服务进行健康检查是一个较为准确的方式，返回结果成功表明服务状态确实正常，但也存在问题。服务注册中心主动调用 RPC 服务的某个接口无法做到通用性；在很多场景下服务注册中心到服务发布者的网络是不通的，服务端无法主动发起健康检查。所以如何取舍，还是需要根据实际情况来决定，根据不同的场景，选择不同的策略。

#### 服务之间的负载均衡（Go Micro组件 - 选择器 Selector）
选择器是构建在服务注册中心上的负载均衡抽象，负责通过Go Micro组件 - 客户端调用内部服务的策略。它允许服务被过滤函数过滤掉不提供服务，也可以通过选择适当的算法来被选中提供服务，算法可以是随机、轮询（客户端均衡）、最少链接（leastconn）等等。选择器通过客户端创建语法时发生作用。客户端会使用选择器而不是注册表，因为它提供内置的负载均衡机制。

consul提供的负载均衡能力太弱，只有作为DNS查询的时候可以使用随机循环策略进行负载均衡，所以一般是[结合Fabio、Nginx](https://www.hashicorp.com/blog/load-balancing-strategies-for-consul)进行真实有效的负载均衡。在Go Micro中，请求路由访问某个服务的过程是（以consul为例）：

1. 根据服务名称去查询consul得到所有该服务的节点列表（micro/go-micro/registry/consul_registry.go GetService方法）
2. 根据选择器策略从节点列表中选择一个节点并发送请求（micro/go-micro/client/rpc_client.go next方法）

可以参考[这里](https://github.com/micro/examples/blob/master/client/selector/selector.go)实现自己的selector，本项目中不包含选择器的实现

## API 网关
API Gateway 是随着微服务概念一起兴起的一种架构模式，它用于解决微服务过于分散，没有一个统一的出入口进行流量管理的问题。它类似于面向对象的外观模式。流量管理的具体问题包括：封装了内部系统架构并且提供了每个客户端定制的API、身份验证、监控、负载均衡、缓存、数据通信协议转换、统一维护流量路由表。

{% img /images/blog/2018-09-28_3.jpg 'image' %}

API Gateway的缺点是，它必须是一个被开发、部署、管理的高可用组件。另外，开发人员必须更新API网关来暴露每个微服务接口。因此更新API网关的过程越少越好。然而，对于大多数现实世界的应用，使用API网关是必不可少的。

#### Micro Api
Micro Api是Micro工具包中实现API网关的工具，它提供HTTP并使用服务发现动态路由到适当的后端。API的请求通过HTTP提供，并通过RPC进行内部路由。我们可以利用它进行服务发现，负载平衡，编码和基于RPC的通信。

{% img /images/blog/2018-09-28_4.png 'image' %}

上图是官方给的Micro Api路由图，Micro Api是一个请求路由、格式转换的工具，只需要执行`micro api`来启动它，就可以像其他服务一样自动注册到consul，在`8080`端口开启所有外界HTTP请求的访问入口，并将请求路由、转换到内部中。至于向加一些其他功能比如鉴权则需要实现Micro Api的插件，可以参考项目中的实现。

#### 数据格式转换（Go Micro组件 - 编码 Codec）
编码组件用于在消息传输到两端时进行编码与解码，可以是json、protobuf、bson、msgpack等等。与其它编码方式不同的我们支持RPC格式的。所以我们有JSON-RPC、PROTO-RPC、BSON-RPC等格式。编码包把客户端与服务端的编码隔离开来，并提供强大的方法来集成其它系统，比如gRPC、Vanadium等等。

编码组件是框架内部的工作，开发时不需要关心，我们需要关心的是：前端需要使用Json来进行通信，但后端使用Protobuf在服务之间通信。对于外部请求，Micro Api通过接收前端HTTP请求，将请求转换之后发送到内部服务，对于服务间的请求，A服务可以直接使用go语言的gRPC客户端调用B服务的接口。相比在使用Restful方式完成服务之间的相互访问，gRPC能提供更好的性能，更低的延迟，并且生来适合与分布式系统。

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

#### 统一流量入口，维护路由关系
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

#### 用户身份鉴定
该功能是除了登录功能的每一个API都会调用的功能，甚至为了不嵌入到每一个服务中，统一在这里处理较好。对于容器化与无状态服务，可以使用JWT进行身份验证，以下是一个例子，从Authorization中解析出用户信息然后传递给网关后的服务。

```go
func (*Auth) Handler() plugin.Handler {
	return func(h http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			log.Println("auth plugin received: " + r.URL.Path)
			if r.URL.Path == "/user/login" {
				h.ServeHTTP(w, r)
				return
			}

			token := r.Header.Get("Authorization")
			userFromToken, e := Decode(token)

			if e != nil {
				response, _ := json.Marshal(util.CommonResponse{
					Code:    code.AuthorizationError,
					Message: "please login",
				})
				w.Write(response)
				return
			}

			r.Header.Set("X-Example-Id", userFromToken.Id)
			r.Header.Set("X-Example-Username", userFromToken.Username)
			h.ServeHTTP(w, r)
			return
		})
	}
}
```

## 服务端（Go Micro组件 - 服务端 Server）
Server包是使用编写服务的构建包，可以命名服务，注册请求处理器，增加中间件等等。服务构建在以上说的包之上，提供独立的接口来服务请求。现在服务的构建是RPC系统，在未来可能还会有其它的实现。服务端允许定义多个不同的编码来服务不同的编码消息。

比如Greeter的main.go文件，只需要实现proto文件中的Hello接口，就可以被当做服务端，结合Go Micro服务端组件使用，成为一个可被访问的服务：

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

## 客户端（Go Micro组件 - 客户端 Client）
客户端提供接口来创建向服务端的请求。与服务端类似，它构建在其它包之上，它提供独立的接口，通过注册中心来基于名称发现服务，基于选择器（selector）来负载均衡，使用transport、broker处理同步、异步消息。

比如greeter服务想要调用user服务，那么就需要将user服务的proto接口文件放到greeter服务能访问到的地方，让greeter的代码能够与之共同构建，还需要在创建greeter服务的时候将user服务的客户端创建出来，如下：

```go
func main() {
	greeterService := micro.NewService(micro.Name(micro_c.MicroNameGreeter),)
	greeterService.Init()
	greeterApi.RegisterGreeterHandler(greeterService.Server(), &Greeter{
		userClient: user.NewUserService(micro_c.MicroNameUser, greeterService.Client())})
	if err := greeterService.Run(); err != nil {
		log.Fatal(err)
	}
}
```

## 服务间异步通信（Go Micro组件 - 代理 Broker）
Broker提供异步通信的消息发布/订阅接口。对于微服务系统及事件驱动型的架构来说，发布/订阅是基础。一开始，默认我们使用收件箱方式的点到点HTTP系统来最小化依赖的数量。但是，在go-plugins是提供有消息代理实现的，比如RabbitMQ、NATS、NSQ、Google Cloud Pub Sub等等。

具体使用方法参看：https://github.com/micro/examples/tree/master/broker  

## 服务配置中心
最开始，我们的每个服务的配置文件都是在自身代码库中，当服务数量、服务所在的环境的数量达到一定数量后，管理这些分散的配置文件会成为一个痛点。由于Micro Config不支持从Git上获取配置文件，所以选用Spring Cloud Config来实现。

Spring Cloud Config的目标是将各个微服务的配置文件集中存储一个文件仓库中（比如系统目录，Git仓库等等），然后通过Config Server从文件仓库中去读取配置文件，而各个微服务作为Viper通过给Config Server发送请求来获取特定的Profile的配置文件，从而为自身的应用提供配置信息。

{% img /images/blog/2018-09-28_5.jpg 'image' %}

具体配置过程参看：https://www.jianshu.com/p/e60f3cceaace 以及本项目中的`service/config/config.go`文件、`config`项目。

## 服务容错保护
服务熔断：当服务A调用服务B的请求满足一定的规则，比如10秒内请求数达到20个，并且有一半以上的请求失败了，此时我们通过切断对服务B的调用来保护系统的整体响应，这种操作即为服务熔断。  
服务降级：在服务B被熔断之后，服务A不会真正地调用服务B。取而代之的是，我们在服务A中定义一个服务降级逻辑（通常是一个fallback接口），此时服务A会直接调用服务降级逻辑快速获取返回结果。

下面是hystrix的配置文件，定义了服务熔断标准、服务降级逻辑、数据暴露端口

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

在服务初始化的时候只需要如下配置就能利用以上的配置来针对某些接口进行容错保护，一旦到达服务降级阈值，则会调用到降级逻辑

```go
hystrix.Configure([]string{"go.micro.api.user.User.GetUserInfo"})
greeterService := micro.NewService(
	micro.Name(micro_c.MicroNameGreeter),
	micro.WrapClient(hystrix.NewClientWrapper()),
)
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
以上仅仅是在本地搭建的一个微服务架构，而线上环境则需要更多服务节点以及更健壮的架构支持，比如API Gateway可能有多个，需要在前面再加一层Nginx进行负载均衡，那么如何让可能动态改变的API Gateway服务地址写入到Nginx的静态配置文件中？此时就需要结合consul-template，动态将地址更新Nginx的配置文件中。还有比如添加EFK、Zipkin、Promethus等日志监控机制。还有与Docker、容器编排工具结合来实施自动化可伸缩动态部署。

最后一个问题是流水线自动化部署，使用Jenkins或GoCD工具将部署流程给自动化起来，比如在build阶段生成docker image然后push到registry中，在deploy阶段调用容器编排工具触发容器自动更新image重启服务。

## 参考
https://gocn.vip/question/1999  
http://sjyuan.cc/topics/  