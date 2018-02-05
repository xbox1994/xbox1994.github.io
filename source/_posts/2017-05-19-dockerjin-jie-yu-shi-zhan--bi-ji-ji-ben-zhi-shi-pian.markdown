---
layout: post
title: "《Docker进阶与实战》笔记-基本知识篇"
date: 2017-05-19 00:09:41 +0800
comments: true
categories: DevOps
---

<!--more-->

#Docker简介
##历史与发展
2013年dotCloutd的PaaS服务商将内部项目Docker开源。这家公司随后出售PaaS，改名为Docker.Inc，专注Docker的开发与推广

Docker是一个开源的容器引擎，得益于容器技术带来的轻量级虚拟化，以及Docker在分层镜像应用上的创新，Docker在磁盘占用、性能和效率方面比传统虚拟化都有非常明显的提高，开始蚕食传统虚拟化的市场

加入Linux基金会，遵循Apache2.0协议，代码托管在GitHub

Docker省去传统虚拟化中的Hypervisor层，基于内核的Cgroup和Namespace技术与内核深度结合，性能与物理机接近

Docker不会直接与内核交互，通过Libcontainer交互，它才是真正的容器引擎

{% img /images/blog/Docker1.jpeg 'image' %}

##功能与组件
###Docker客户端
Docker是C/S架构，Docker客户端通过command或REST API发起请求

###Docker daemon
Docker server/Docker engine。驱动整个Docker功能的核心引擎。

接受客户端的请求并实现功能，涉及容器、镜像、存储，复杂的内部机制。

###Docker容器
功能上，通过Libcontainer实现对容器生命周期的管理。

概念上，容器诠释了Docker集装箱的概念，可以存放任何货物，运到世界各地。

容器不是新的概念，牛逼的是Docker把容器封装之后，与集装箱的概念对应起来，是Docker把容器推广到全世界。

###Docker镜像
与容器的动态对应，镜像是运行环境的静态体现。

相对于IOS镜像，轻量化，分层化，提供Dockerfile创建。

###Registry
存放镜像的仓库，实现了镜像的传输中转站与版本管理。

官方Registry是Docker Hub，Registry是开源项目，自己可以搭建自己的Hub或二次开发。

##概念澄清
###Docker与LXC的关系
LXC（Linux Container）：Docker 1.9之前使用的内核容器技术

Docker在LXC（Cgroup和Namespace）的基础上提供更高层的控制工具。包含以下重要特性：

* 跨主机部署。LXC受限于机器的特定配置，Docker镜像定义了可移植的镜像。
* 以应用为中心。简化应用的部署过程，在API、文档（这个真的要赞，Docker的文档是笔者读过最舒服的文档）、Dockerfile有体现。
* 版本管理。类似于Git，镜像支持提交新的版本，回退版本，追踪镜像版本的功能。镜像的增量上传下载功能。
* 组件重用。任何容器都可以用作生成另一个组件的镜像。
* 共享。Registry。
* 工具生态链。定义了API来定制容器创建和部署。非常多的工具能与Docker协作，扩展能力。

Libcontainer：Docker强大之后定义容器标准，在1.10之后用的内核容器技术库

###Docker容器与虚拟机有什么区别
硬件虚拟化技术VS操作系统虚拟化技术

Hypervisor层VSCgroup和Namespace

容器与主机共享内核，不同容器之间可以共享部分系统资源。虚拟机独占分配给自己的资源，各个虚拟机之间完全隔离，因此更加重量级并更消耗资源。

启动速度：秒与数十秒

请根据具体需求判断使用相应的隔离方式

#容器技术
相对独立的运行环境：进程的资源控制+访问隔离
##一分钟理解容器
###组成
容器 = Cgroup + Namespace + rootfs + 容器引擎（用户态工具）

###Cgroup
control group，内核的特性，限制和隔离一组进程对系统资源（CPU、内存、IO、网络）的使用。

###Namespace
将内核的全局资源做封装，使每个Namespace都有一份独立的资源，因此不同的进程在各自的Namespace内对同一种资源的使用不会相互干扰。

##容器造就Docker
Docker的核心技术：容器？分层镜像？统一应用的打包与部署方式？“Build, Ship and Run"？

* 微服务的设计艺术：轻量级虚拟化、与内核无缝结合的运行效率优势与极小的系统开销；将各个组件单独部署的思想。
* 基于LXC容器技术的完善、加强、应用化

#Docker镜像
##Docker image概念
启动容器的只读模板

Docker image表示法：远程Registry地址/命名空间/仓库名:标签

{% img /images/blog/Docker2.jpeg 'image' %}

##Docker image的组织结构
```
vagrant@workshop:/var/lib/docker$ ll
total 76
drwxr-xr-x   9 root root  4096 May 18 15:16 ./
drwxr-xr-x  52 root root  4096 Nov 22  2015 ../
drwxr-xr-x   5 root root  4096 Nov 22  2015 aufs/
drwx------   3 root root  4096 May 18 15:16 containers/
drwx------ 258 root root 28672 May 17 15:51 graph/               #image各层的元数据
-rw-r--r--   1 root root  5120 May 18 15:16 linkgraph.db
drwxr-x---   3 root root  4096 Nov 22  2015 network/
-rw-------   1 root root  2015 May 17 15:51 repositories-aufs    #image总体信息
drwx------   2 root root  4096 May 18 13:59 tmp/
drwx------   2 root root  4096 Nov 22  2015 trust/
drwx------   3 root root  4096 May 17 15:39 volumes/
```
###总体信息
```
vagrant@workshop:/var/lib/docker$ sudo cat repositories-aufs | python -m json.tool
{
    "Repositories": {
        "busybox": {
            "latest": "3d5bcd78e074f6f77b820bf4c6db0e05d522e24c855f3c2a3bbf3b1c8f967ba8"
        },
```
###数据与元数据
graph目录包含本地镜像库中所有元数据与数据信息。对于busybox

```
root@workshop:/var/lib/docker/graph/3d5bcd78e074f6f77b820bf4c6db0e05d522e24c855f3c2a3bbf3b1c8f967ba8# ll
total 48
drwx------   2 root root  4096 Nov 22  2015 ./
drwx------ 258 root root 28672 May 17 15:51 ../
-rw-------   1 root root  1074 Nov 22  2015 json
-rw-------   1 root root     1 Nov 22  2015 layersize
-rw-------   1 root root    82 Nov 22  2015 tar-data.json.gz
```

Docker daemon可以通过这些信息还原出Docker image：先通过repositories-aufs获取image对应的layer ID，再根据layer对应的元数据梳理出image包含的所有层、层与层之间的关系，然后使用联合挂载技术还原出容器启动所需要的rootfs。

###数据的组织
docker inspect对元数据（上个控制台输出的名称为json的文件）进行了整理
```
root@workshop:/var/lib/docker/graph/3d5bcd78e074f6f77b820bf4c6db0e05d522e24c855f3c2a3bbf3b1c8f967ba8# docker inspect busybox
[
{
    "Id": "3d5bcd78e074f6f77b820bf4c6db0e05d522e24c855f3c2a3bbf3b1c8f967ba8",
    "RepoTags": [
        "busybox:latest"
    ],
    "RepoDigests": [],
    "Parent": "bf0f46991aed1fa45508683e740601df23a2395c47f793883e4b0160ab906c1e",
    "Comment": "",
    "Created": "2015-10-20T21:56:30.211245109Z",
    "Container": "e97e35122eefe587151947c737439860e06866ae6b5a5da785ec76caaa46441f",
    "ContainerConfig": {
        "Hostname": "3e10a20c1b67",
        "Domainname": "",
        "User": "",
        "AttachStdin": false,
        "AttachStdout": false,
        "AttachStderr": false,
        "Tty": false,
        "OpenStdin": false,
        "StdinOnce": false,
        "Env": null,
        "Cmd": [
            "/bin/sh",
            "-c",
            "#(nop) CMD [\"sh\"]"
        ],
        "Image": "bf0f46991aed1fa45508683e740601df23a2395c47f793883e4b0160ab906c1e",
        "Volumes": null,
        "WorkingDir": "",
        "Entrypoint": null,
        "OnBuild": null,
        "Labels": null
    },
    "DockerVersion": "1.8.2",
    "Author": "",
    "Config": {
        "Hostname": "3e10a20c1b67",
        "Domainname": "",
        "User": "",
        "AttachStdin": false,
        "AttachStdout": false,
        "AttachStderr": false,
        "Tty": false,
        "OpenStdin": false,
        "StdinOnce": false,
        "Env": null,
        "Cmd": [
            "sh"
        ],
        "Image": "bf0f46991aed1fa45508683e740601df23a2395c47f793883e4b0160ab906c1e",
        "Volumes": null,
        "WorkingDir": "",
        "Entrypoint": null,
        "OnBuild": null,
        "Labels": null
    },
    "Architecture": "amd64",
    "Os": "linux",
    "Size": 0,
    "VirtualSize": 1112855,
    "GraphDriver": {
        "Name": "aufs",
        "Data": null
    }
}
]
```

Id：最上层的layerID
Parent：该layer的父层，这样就可以找到某个image的所有layer
##Docker image扩展知识
###联合挂载
把多个目录挂载到同一个目录，对外呈现这些目录的联合

只有OverlayFS在2014年合入Linxu主线，aufs只有ubuntu支持，Redhat和Suse采用devicemapper，请根据实际情况选择后端存储驱动
###写时复制
操作系统的fork：当父进程fork子进程，内核不会马上分配内存，而是让父子进程共享内存。当两者之一修改共享内存时，会触发一次缺页异常导致真正的内存分配。加速了创建速度与减少了内存的消耗。

所有的容器共享某个image的文件系统，所有数据都从image中读取，只有当要对文件进行写操作时，才从image里把要写的文件复制到自己的文件系统进行修改。从而提高加载速度并节省空间
##存在的问题
* image难以加密。image是共享的，加密会导致难以共享。有notary的镜像签名机制。
* image分层之后有大量元数据。分布式存储对小文件的支持不好。
* image制作完成之后无法修改。Dockre不提供修改或合并层的指令。