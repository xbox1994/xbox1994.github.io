---
layout: post
title: "一次简单通用的压测调优实战"
date: 2018-12-08 20:16:55 +0800
comments: true
categories: 后台
---

相比于网上教你如何使用ab、jmeter工具进行压测一个接口，本文更关注在压测调优的思路上。

<!-- more -->

## 明确思路
目的：提升单个接口的QPS（每秒查询率QPS是对一个特定的查询服务器在规定时间内所处理流量多少的衡量标准。）

工具：本文不关注工具的使用，简单起见，使用apache的`ab`工具

步骤：先测试并优化一个空接口（直接返回请求的接口），拿到一个极限QPS，然后分别引进Redis、MySQL的接口分别进行测试并优化，使其尽量接近极限QPS。步骤严格遵循控制变量法。

环境：为得到尽量接近真实生产环境的数据，需要提前建立一个与生产环境几乎一致的压测环境，在压测环境上进行测试。当前环境为：AWS EC2上部署的K8S集群，共2个Node节点，CPU为2核。

## 空接口压测优化
### 获取数据
先在代码中写上一个直接返回请求的test接口，然后部署到容器集群中作为被压测的对象，再登录到另外一个作为施压机进行压测。

同时注意检测CPU，内存，网络状态，因为对于一个空接口，QPS达到上限一定是因为该服务所在宿主机的某处性能达到瓶颈。

命令：`ab -n 3000 -c 300 "http://10.1.2.3/test/"`

测试环境：
```
Requests per second:    1448.86 [#/sec] (mean)
Time per request:       69.020 [ms] (mean)

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        1    1   1.1      1       8
Processing:     5   66  29.4     63     164
Waiting:        5   66  29.4     63     164
Total:          5   67  29.7     64     165
```

在整个压测过程中，使用`top -d 0.3`发现CPU达到瓶颈，为验证我们的猜想，将相同的服务部署到另外一个CPU性能更好的机器上测试。

CPU性能提升之后的本地环境：
```
Requests per second:    3395.25 [#/sec] (mean)
Time per request:       29.453 [ms] (mean)

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    0   0.7      0       3
Processing:     2   28  13.3     26      84
Waiting:        2   28  13.3     26      84
Total:          2   29  13.4     26      86
```

### 定位问题
Processing time的解释：The server response time—i.e., the time it took for the server to process the request and send a reply

结论很明显，在Connect连接时长几乎一致的情况下，服务器端处理时间大大减少，所以**CPU**对QPS的影响是最直接的。

另外，依据经验判断，2核CPU的机器本地压测只有3k是不正常的一个数据，所以猜测框架性能有差异，所以对不同框架进行了空接口的测试，数据如下：

`beego: 12k , go micro: 3.5k, spring boot: 5.5k`

结论是**框架**直接大幅度影响性能，分析一下，go micro与beego、spring boot的区别是它是一个**微服务**架构的框架，需要consul、api gateway、后台服务一起启动，一个请求来到gateway之后，可能需要查询consul拿到后台服务的地址，还需要将JSON格式转换为gRPC格式发送给后台服务，然后接收后台服务的返回，这直接导致了在CPU计算量、网络传输量最少两倍于单体应用，即使go micro的网关和后台服务分开在两台机器上部署，测试之后QPS也只能到达5.5k。

我是直接感受到了一个微服务的缺点：相比于单体架构服务的直接返回请求，微服务架构服务的开销是很可能更大的，所以在选择架构的时候需要在性能与微服务带来的优势（服务解耦、职责单一、独立开发构建部署测试)上进行衡量，当然如果你服务器够多性能够好，当我没说。

### 进行优化
在CPU无法提升、框架无法改变的情况下，只能在框架和服务的配置、代码的使用、架构层面进行优化。

#### 1
参考go micro作者给的[方法](https://micro.mu/docs/faq.html#how-performant-is-it)，对框架的配置进行优化：

`--client_pool_size=10 # enables the client side connection pool`

再次在测试环境下测试，QPS提升300，到达1700。
 
#### 2
api gateway是所有流量都会走的地方，所以是优化的重要部分，我们先测试一下删掉其中的业务代码，QPS提升了600，到达2300，所以优化了一下这里的逻辑，QPS到达2100

```go
	if !strings.Contains(cookies, "xxx") {
		return nil, errors.New("no xxx cookie found")
	}
```

替换掉

```go
	cookiesArr := strings.Split(cookies, ";")
	for _, v := range cookiesArr {
		cookie := strings.Split(v, "=")
		if strings.Trim(cookie[0], " ") == "xxx" {
			sid = cookie[1]
			break
		}
	}
```

#### 3
最后，使用k8s的自动伸缩机制，另外部署了一组api gateway和后台服务到不同的Node上，相当于配置好了两台机器的负载均衡，QPS达到3200

## Redis相关接口优化
找到一个仅包含一次Redis get操作且无返回数据的接口作为测试接口，在空接口优化之后的基础上进行测试，QPS：2000

对于连接另外的一个服务或中间件的情况，优化的方式并不多，最常用的优化方式就是提升连接数，在服务内部将连接Redis的连接数提MaxIdle提升到800，MaxActive提升到10000，QPS提升500，达到2500。

另外可以查看Redis服务的一些配置和性能图标，当前环境下使用的是AWS上的Redis服务，可配置的项目不多，使用的是两个节点的配置，在压测的过程中查看CPU占用、连接数占用、内存占用，均未发现达到上限，所以Redis服务没有可以优化的余地。

## 数据库相关接口优化
在高并发场景下，为了尽量提升QPS，查询的操作应该尽量全部使用Redis做缓存代替或者将请求尽量拦截在查询数据库之前，所以数据库的查询操作并不是QPS提升关注的重点。

但需要对数据库进行一些通用的优化，比如主从复制，读写分离、提升连接数、在大数据量下分表、优化SQL、建立索引。下面以一个查询操作为例，一条复杂的sql为例做一次SQL优化与索引建立，以单次的查询时间为目标进行优化。

### 准备数据
先用存储过程准备50w条数据
```sql
DELIMITER $$
CREATE PROCEDURE prepare_data()
BEGIN
  DECLARE i INT DEFAULT 1;

  WHILE i < 500000 DO
    INSERT INTO game_record (app_id, token, game_match_id, user_id, nickname, device_id, prize_grade, start_time, score) VALUES ('appid', 'abc', concat('xx',i), '70961908', 'asdfafd', 'xcao', 2, 1543894842, i );
    SET i = i + 1;
  END WHILE;
END$$
DELIMITER ;

call prepare_data()
```
### 建立索引
如何选择合适的列建立索引？

1. WHERE / GROUP BY / ORDER BY / ON 的列
2. 离散度大（不同的数据多）的列使用索引才有查询效率提升
3. 索引字段越小越好，因为数据库按页存储的，如果每次查询IO读取的页越少查询效率越高
 
对于以下SQL：
```sql
select * from game_record where app_id = ? and token=? and score != -1 order by prize_grade, score limit 50
```
优化前时间: 0.551s

对于order by操作，可以建立复合索引：
```sql
create index grade_and_score on game_record(prize_grade, score)
```
优化后时间: 0.194s

### 优化SQL
这里不贴具体的SQL语句了，以下是一些SQL通用优化方式：

* 使用精确列名查询而不是*，特别是当数据量大的时候
* 减少子查询，使用Join替代
* 不用NOT IN，因为会使用全表扫描而不是索引；不用IS NULL，NOT IS NULL，因为会使索引、索引统计和值更加复杂，并且需要额外一个字节的存储空间。

还有一些具体的数据库优化策略可以参考[这里](https://github.com/xbox1994/2018-Java-Interview/blob/master/MD/%E6%95%B0%E6%8D%AE%E5%BA%93-MySQL.md)

## TODO
以上是仅仅是排除代码之后的服务和中间件压测，还应该加入代码逻辑进行更加全面的测试，然后对代码进行优化，具体优化方式请参考对应编程语言的优化方式。

如果以后碰到性能瓶颈，扩机器是最简单高效的，或者更换其他框架，或则还可以深入优化一下api gateway和后台服务交互的数据传输性能，因为这块是直接导致CPU达到瓶颈的原因。

## 总结
如果想做好一次压测和优化，需要非常清晰的思路、高效的压测方法、排查问题的套路、解决问题的方案，但最基础的还是需要知道一个请求从浏览器发送之后，到返回到浏览器，之间到底经历过什么，[这篇比较基础的文章](http://www.wangtianyi.top/blog/2017/10/22/cong-urlkai-shi-,ding-wei-shi-jie/)可以帮你了解一些，但还不够，比如这次调优中还涉及到数据库优化、Go语言、硬件性能、AWS、Docker、K8S这样的云平台和容器技术、容器编排工具，所以压测调优是一次对自己掌握服务端整个架构和细节的考验和学习过程。

以上是本人和同事在短期内协作工作之后的总结，不足之处在所难免，欢迎各种意见。
