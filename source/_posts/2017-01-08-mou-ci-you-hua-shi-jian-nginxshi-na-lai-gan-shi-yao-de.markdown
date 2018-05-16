---
layout: post
title: "记一次性能优化探索-Nginx有什么用"
date: 2017-01-08 18:32:58 +0800
comments: true
categories: 后台
---

"这张卡马上做完了,赶紧desk check,我们先把测试环境准备好".我高高兴兴地跟洲说,随手修改了一下配置文件中的微服务访问路径,然后重启服务器,一切看起来那么的一帆风顺.  
"好的,页面开始Loading啦"...10分钟之后..."我受不了了"

<!--more-->

##问题
1.本地环境开启的应用访问EC2上的某微服务速度慢,但在EC2环境开启的应用访问该微服务速度快.

2.本地环境加载某一个页面的过程中刷新,会很长时间内没有回应
##区别
本地应用环境与EC2真实环境局别如下:  
1.本地与EC2其他微服务的连接是外网通信,运行应用的EC2实例与其他微服务的连接是内网通信  
2.本地Web Server使用的是Thin,EC2服务器使用的是Unicorn+Nginx
##猜测
首先我们觉得是网络环境的问题,因为我们同时发现上午网速确实比下午网速快,所以忍耐了很长时间没有下功夫在这方面,直到最近洲回来了,对这个访问速度感到很是愤怒.
在连接上VPN之后,发现速度什么的都不是问题,但是加载数据量较大的资源时还是比较慢
##研究
问题1:

所以开始研究第二个区别,本地测试三种环境如下图:  
1)Thin  
{% img /images/blog/home_thin.png 'image' 'images' %}
2)Unicorn  
{% img /images/blog/home_unicorn.png 'image' 'images' %}
3)Unicorn+Nginx
{% img /images/blog/home_nginx+unicorn.png 'image' 'images' %}

可以看出:  
1.对于Thin和Unicorn服务器来说,资源不论大小,他们的耗时是基本相同的.  
2.拿有Nginx的Unicorn服务器与没有Nginx的Unicorn服务器来说,数据量小的资源会稍慢一些,但数据量大的资源速度提升明显.  
3.Nginx将数据进行大幅度压缩,导致Size远小于Content

问题2:

经过测试,1)和2)都存在这个问题,但3)不存在,很明显是默认配置的服务器无法同时处理多个请求,可以通过
1.--threaded开启Thin多线程模式  
2.Nginx与多进程模式Unicorn的配合  
均可以使得不用等待上一个请求结束而直接请求另一个服务器并立马得到回应.

##服务器通信级别的原因
###Nginx对请求的压缩处理
具体解释与参数配置在  
https://www.nginx.com/resources/admin-guide/compression-and-decompression/

gzip是默认配置在nginx.conf内的,所以默认开启,如果不对数据量要求特别精细的话,默认配置完全可以满足基本需求

上图的2.5MB大文件显然被压缩成几百K的小文件在网络上进行传输,大大减轻了应用的网络负载
###Nginx对请求的合并处理
先回顾一下Nginx反向代理的原理:正向代理是将自己要访问的资源告诉Proxy,让Proxy帮你拿到数据返回给你,Proxy服务于Client,常用于翻墙和跨权限操作;反向代理也是将自己要访问的资源告诉Proxy,让Proxy帮你拿到数据返回给你,但是Proxy服务于Server,它会将请求接受完毕之后发送给某一合适的Server,常用于负载均衡.

{% img /images/blog/nginx_priciple.png 'image' 'images' %}

**_Proxy统一接收Client请求，接收完毕后才发给Server，提高Server处理效率_**

Using a reverse proxy server frees the application server from having to wait for users to interact with the web app and lets it concentrate on building pages for the reverse proxy server to send across the Internet  
https://www.nginx.com/blog/10-tips-for-10x-application-performance/

Nginx在其他方面也有好处,如直接返回静态文件,添加重定向与SSL证书,添加返回头,可参看这篇[NUS后台]
###少量请求+单机运行Nginx的坏处
Nginx是负责接收/返回请求与转发/返回请求的,在这个过程中会涉及到资源的压缩处理,势必会拖慢请求处理速度并加重Nginx运行环境的负担;同时,在转发到Server和接受Server返回的资源的过程中是会进行TCP连接的,此段的开销会拖慢整体返回速度,所以可能会出现单个请求返回速度比不使用Nginx的速度慢.

但是,在高并发情况下,才是Nginx的用武之地.如果1台实例无法处理成千上万个请求,那么就用集群吧,Nginx帮你负载均衡并添加一道隐形的安全防火墙,记住,一定要把Nginx放到一台独立的实例上而不要与其他服务共存,否则反而会影响整体处理速度.

换句话说,使用Nginx的后台架构中的单个请求的处理速度可能会慢于不使用Nginx的后台架构,但在高并发环境下,不使用Nginx的后台可能会爆掉Out of memory..使用Nginx的后台依然坚挺,为了系统的稳定性与负载均衡,使用Nginx是非常明智的选择.
##代码级别的原因
上面是针对已有代码进行的服务器通信阶段进行的分析,在代码内部实现,依然还有很多加快加载速度的方式,对于我们这个例子来说的话:  
1.前台不应该加载2.5MB这样巨大的文件,除非万不得已.在前台做数据的展现即可,不需要先拿到全部数据后做数据的查询.  
2.代码级别存在很多批处理请求,但发送的时候是单条发送,建议使用批量处理对应的API
##结论
1.网络问题是影响本地加载速度最大的因素,本地网络暂时难以改变,不连接/连接VPN+添加防火墙规则解决.  
2.代码层级可以做适当优化,解决大资源加载以及请求发送策略,将要解决.  
3.对于页面重新加载速度过慢的问题,使用多线程配置解决,已经解决.  
4.对于大资源加载问题,考虑使用Nginx压缩处理,grunt ddev已经解决.  
5.对于以后可能出现的请求数量过多问题采用Nginx+Unicorn负载均衡,已经解决.

## 号外号外
最近在总结一些针对**Java**面试相关的知识点，感兴趣的朋友可以一起维护~  
地址：[https://github.com/xbox1994/2018-Java-Interview](https://github.com/xbox1994/2018-Java-Interview)
