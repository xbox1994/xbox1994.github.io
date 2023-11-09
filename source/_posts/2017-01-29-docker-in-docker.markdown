---
layout: post
title: "Docker in Docker"
date: 2017-01-29 14:52:48 +0800
comments: true
tags: DevOps
---
我想过一个非常有意思的东西:在docker里面运行docker,然后在docker里运行的docker中再运行一个docker,接着在docker里运行的docker里运行的docker中再开一个docker..接着迭代100次会发生什么
<!--more-->
结合这篇文章:https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/
以及自己的经验与实践总结出下文.

"If you want the short solution without the details, just scroll to the bottom of this article. ☺"

##Bad
如果你在docker中运行了docker,会导致一下问题:

1.当你使用-privileged的时候会导致一个在内部docker与外部docker之间的安全配置无法合并的冲突,是关于LSM (Linux Security Modules)的

2.外部docker运行在正常的文件系统中,但内部docker运行在写时拷贝的文件系统,会直接导致无法运行或者因为命名空间的问题影响其他container

##Solution
其实基本上来说是不存在需要在docker中跑docker这种需求的,你想要的只是在docker中启动一个docker的container来运行你的程序,并不关心这个container在哪个docker进程中.下面提供一种方式可以让你在docker内部调用这个docker程序开启新的container帮助你完成工作:

```
docker run -v /var/run/docker.sock:/var/run/docker.sock ...
```

这样你程序所在的container中已经有权限访问docker的socket,因此可以用docker run启动同胞兄弟而不是子容器

```
/ # docker ps
➜  ~ docker run -v /var/run/docker.sock:/var/run/docker.sock -ti docker
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
8c84704e890e        docker              "docker-entrypoint..."   2 seconds ago       Up 1 second                             brave_lichterman
/ # docker run -v /var/run/docker.sock:/var/run/docker.sock -ti docker
/ # docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
34dcf16326c2        docker              "docker-entrypoint..."   3 seconds ago       Up 2 seconds                            inspiring_mcnulty
8c84704e890e        docker              "docker-entrypoint..."   37 seconds ago      Up 36 seconds                           brave_lichterman
```

##Practice
使用上述Solution打包一个docker镜像
###构建打包镜像的环境
网上实在没有找到包含docker+aws+packer的ubuntu docker镜像,以下是dockerfile
```
FROM ubuntu:14.04

# install docker
RUN apt-get update \
    && apt-get -y install ca-certificates \
		curl \
		openssl \
		unzip

ENV DOCKER_BUCKET get.docker.com
ENV DOCKER_VERSION 1.13.0
ENV DOCKER_SHA256 fc194bb95640b1396283e5b23b5ff9d1b69a5e418b5b3d774f303a7642162ad6

RUN set -x \
	&& curl -fSL "https://${DOCKER_BUCKET}/builds/Linux/x86_64/docker-${DOCKER_VERSION}.tgz" -o docker.tgz \
	&& echo "${DOCKER_SHA256} *docker.tgz" | sha256sum -c - \
	&& tar -xzvf docker.tgz \
	&& mv docker/* /usr/local/bin/ \
	&& rmdir docker \
	&& rm docker.tgz \
	&& docker -v

# install aws
RUN apt-get install -y python-pip groff-base
RUN pip install awscli

# install packer
RUN curl -OL#\
 https://releases.hashicorp.com/packer/0.12.2/packer_0.12.2_linux_amd64.zip &&\
 unzip packer_0.12.2_linux_amd64.zip -d /usr/local/bin/

# copy file
WORKDIR /build
COPY infrastructure infrastructure
COPY pipeline/test/env_packet/packet4testEnv.sh /usr/local/bin

ENTRYPOINT ["packet4testEnv.sh"]
```
然后添加打包脚本
```
echo "----------------------------------build packet environment"
docker build -t packer_aws_env -f ./pipeline/test/env_packet/Dockerfile .
echo "----------------------------------tag image"
docker tag packer_aws_env $ECR_REPOSITORY:sf-test-packet
echo "----------------------------------aws login"
aws ecr get-login | bash
echo "----------------------------------push to ecr"
docker push $ECR_REPOSITORY:sf-test-packet
```
###结合packer与ecr构建并上传镜像
外层docker环境
```
echo "----------------------------------pull docker image from ecr"
aws ecr get-login | bash
docker pull $ECR_REPOSITORY:sf-test-packet

echo "----------------------------------run packer in docker and packet for test environment"
docker run --rm \
 -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
 -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
 -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION \
 -e ECR_LOGIN_SERVER=$ECR_LOGIN_SERVER \
 -e ECR_REPOSITORY=$ECR_REPOSITORY \
 $ECR_REPOSITORY:sf-test-packet

```
内层docker环境
```
"run_command": ["-d", "-i", "-t", "-v", "/var/run/docker.sock:/var/run/docker.sock", "{{.Image}}", "/bin/bash"]
```

## 号外号外
最近在总结一些针对**Java**面试相关的知识点，感兴趣的朋友可以一起维护~  
地址：[https://github.com/xbox1994/2018-Java-Interview](https://github.com/xbox1994/2018-Java-Interview)
