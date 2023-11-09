---
layout: post
title: "Docker port与iptables"
date: 2017-02-04 16:57:08 +0800
comments: true
tags: DevOps
---
一个请求是如何从实体机传递到我们的应用的

iptables -> docker deamon -> docker bridge network -> docker container -> app
<!--more-->
##从iptables开始
参考:https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/4/html/Security_Guide/s1-firewall-ipt-fwd.html

维基百科:iptables，一个运行在用户空间的应用软件，通过控制Linux内核netfilter模块，来管理网络数据包的流动与转送。

因为公网IP的稀有与昂贵,公司一般只有一个公网IP,使用局域网与私有IP是访问公网资源的常用方式.防火墙与路由器可以将请求转发到内网机器上,也可以将传入路由到对应内网节点.这样的转发很危险,特别是攻击者伪装成内网节点.为了防止这种情况，iptables提供了可以实现的路由和转发策略，以防止网络资源的异常使用。

####iptables的FORWARD策略
控制经过本节点的数据包路由的位置,例如转发到所有节点

如果这样设置,在这个防火墙之后的所有节点都可以接收到数据包,相当于创建了一个路由规则,发送到这个路由的数据包都可以达到数据包内包含的预期节点,且都通过eth1设备
```
iptables -A FORWARD -i eth1 -j ACCEPT
iptables -A FORWARD -o eth1 -j ACCEPT
```

此时内网节点还不能正常访问外网,需要将内网IP伪装成路由IP来访问外网资源
```
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```

如果你想让一个内网节点成为外部可用的服务器,使用DNAT转发策略,将外部请求转发到改内网节点,Docker就是使用这个策略将请求转发到对应container中
```
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 80 -j DNAT --to 172.31.0.23:80
```
##iptables结合docker deamon转发
参考:https://wiki.archlinux.org/index.php/Network_bridge_(%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87) <Docker进阶与实战>

####iptables -> docker deamon
Docker deamon在启动container时会在主机上采用iptables的DNAT策略,将iptables接受到的请求转发给改container所属的内网节点
```
root@ip-172-31-18-147:/home/ubuntu# docker run -itd -p 80:80 nginx

root@ip-172-31-18-147:/home/ubuntu# docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                         NAMES
660b89af3737        nginx               "nginx -g 'daemon ..."   3 seconds ago       Up 2 seconds        0.0.0.0:80->80/tcp, 443/tcp   amazing_dijkstra
r

root@ip-172-31-18-147:/home/ubuntu# iptables -L
Chain FORWARD (policy DROP)
target     prot opt source               destination
DOCKER     all  --  anywhere             anywhere
Chain DOCKER (1 references)
target     prot opt source               destination
ACCEPT     tcp  --  anywhere             172.17.0.2           tcp dpt:http

```

####docker deamon -> docker bridge network
Docker deamon启动时会在主机创建一个Linux网桥(网桥:网桥是一种软件配置，用于连结两个或更多个不同网段。网桥的行为就像是一台虚拟的网络交换机，工作于透明模式（即其他机器不必关注网桥的存在与否）。任意的真实物理设备（例如 eth0）和虚拟设备（例如 tap0）都可以连接到网桥。)(默认为docker0).

容器启动时会创建一对veth pair,docker将一端挂在docker0网桥上,另一端放到容器的Network Namespace内,从而实现容器与主机通信的目的.
{% img /images/blog/docker_bridge_network.png 'image' 'images' %}

####docker bridge network -> docker container
当前没有容器运行,网桥上没有网络接口,但默认分配了172.17.0.1/16的子网
```
root@ip-172-31-18-147:/home/ubuntu# ip addr show docker0
5: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default
    link/ether 02:42:51:23:1f:10 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 scope global docker0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:51ff:fe23:1f10/64 scope link
       valid_lft forever preferred_lft forever
```
然后启动一个container测试,container会自动加入到该子网中
```
root@ip-172-31-18-147:/home/ubuntu# docker run -it ubuntu:14.04
root@82c955281fdb:/# ip addr show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
931: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 02:42:ac:11:00:02 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.2/16 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:acff:fe11:2/64 scope link
       valid_lft forever preferred_lft forever
```

_**综上所述,Docker会为我们创建一个iptables转发规则,将从外界接收到的请求转发到Docker在启动container时创建的子网中的对应节点**_

## 号外号外
最近在总结一些针对**Java**面试相关的知识点，感兴趣的朋友可以一起维护~  
地址：[https://github.com/xbox1994/2018-Java-Interview](https://github.com/xbox1994/2018-Java-Interview)
