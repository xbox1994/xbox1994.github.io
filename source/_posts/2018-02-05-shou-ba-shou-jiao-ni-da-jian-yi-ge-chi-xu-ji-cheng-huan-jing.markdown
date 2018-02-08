---
layout: post
title: "手把手教你搭建一个持续集成环境"
date: 2018-02-05 18:47:16 +0800
comments: true
categories: Devops
---

本文将带领你从0开始，用Vagrant + Docker + Ansible + Jenkins + Nginx + GitHub等工具和资源来搭建一条可执行可扩展的持续集成流水线，即使这些名字你都没听过也没关系，本文将会在需要的时候一一解释给你听。

<!-- more -->

By: 巧颖 & 天一

#总览
这是我们将要搭建的所有基础设施的总体架构图，我们将在本文中手把手教你搭建这样一个持续集成环境。

{% img /images/blog/2018-02-05_1.png 'image' %}

我们会在本地启动两台虚拟机，一台部署Nginx作为静态文件服务器，一台作为Jenkins服务器，在每台虚拟机内部安装Docker，使用Docker来完成Nginx与Jenkins的搭建、配置，然后手动在Jenkins配置内配置好一条Pipeline作为持续集成流水线，最后尝试提交一次代码去触发一次持续集成操作，将最新的html项目代码从Github上部署到Nginx中，实现持续集成。

避免本文过长，部分源代码没有贴在文中，本文参考完成源代码在此：[https://github.com/tw-wh-devops-community/cooking-chicken.git](https://github.com/tw-wh-devops-community/cooking-chicken.git)。建议参考源码阅读本文，然后自己尝试从0开始搭建一个相同的环境出来。相信你一定会碰到很多坑，但坑外便是晴天。

#首先我们需要两台机器
##我们需要Vagrant
###为什么呢
无论你用的操作系统是Windows、Mac还是Linux，Oracle的Virtual Box都支持，那么我们首先会使用Virtual Box来建立一个在硬件上绝对隔离的环境出来。

那么Vagrant就是通过方便的命令操作来简化Virtual Box的操作，同时提供了方便的虚拟机配置模块，所以我们会使用这个工具来提升虚拟机的配置效率。

###安装Vagrant
在Mac上是自带Virtual Box的，你用的版本可能需要更新才能配合Vagrant使用，Linux上请使用类似`sudo apt-get install virtualbox`的命令安装。

那么先装上Vagrant吧：

* Mac（[https://www.vagrantup.com/downloads.html](https://www.vagrantup.com/downloads.html)）
* Ubuntu（`sudo apt-get install vagrant`）

###安装Vagrant插件
由于后续操作会涉及到将Nginx机器的私钥发送给Jenkins机器来配置私钥来完成虚拟机之间的无密码访问。但私钥是在Nginx虚拟机创建之后才会由Vagrant创建的，所以需要在这个时间节点放到Jenkins目录下便于Ansible把私钥放到Jenkins虚拟机中。如果暂时不理解没有关系，请看完”开始创建世界“之后回头来看就会明白。

Vagrant的provision模块可以在虚拟机启动之后在**虚拟机内部**执行任意脚本，但是provision模块并没有提供执行**宿主机**上脚本的方式，所以需要你安装如下模块：

```
vagrant plugin install vagrant-host-shell
```

###调试的时候比较有用的操作
* 进入虚拟机：`vagrant ssh`
* 休眠：`vagrant suspend`
* 从休眠中恢复：`vagrant resume`
* 移除虚拟机所有文件：`vagrant destroy`

##我们需要Ansible
###什么是Ansible
Ansible是一种自动化部署工具，可以用来自动化管理配置项、持续交付、（AWS）云服务管理；

简单来说也就是可以批量的远程服务器上执行一系列的命令，其原理是基于ssh来和远程主机进行通信的。
###为什么用Ansible

* playbook使用的是yml语言，易读性较好；
* 没有主节点和代理，仅仅依赖于SSH，使得应用的部署简单而轻量；
* 提供了大量模块支持Google Compute Engine (GCE)， Amazon Web Service（AWS）；
* nsible支持多台服务器同时管理部署；

###安装Ansible
Ansible是基于python开发的，需要在安装有python的机器下才能够安装Ansible

* 在本机安装python：`brew install python`（Mac自带ython，因此这步可以省略，inux系统中需要安装Python）
* 安装pip：`sudo apt install python-pip`
* 安装Ansible：`sudo pip install ansible`

其他环境的安装详情请参考：[http://docs.ansible.com/Ansible/latest/intro_installation.html](http://docs.ansible.com/ansible/latest/intro_installation.html)

###目录结构
```
├── ansible.cfg
├── deploy.yml
├── hosts
└── roles
    ├── common
    │   └── tasks
    │       ├── install_docker.yml
    │       └── main.yml
    ├── jenkins
    │   ├── files
    │   │   └── docker-compose.yml
    │   └── tasks
    │       └── main.yml
    └── nginx
        ├── files
        │   └── default.conf
        ├── tasks
        │   └── main.yml
        └── templates
            └── index.html
```

####roles文件夹
roles是基于一个Ansible默认的目录结构，Ansible在执行任务的时候会去默认加载`templates`、`tasks`以及`handlers`文件夹中的文件等。我们基于roles 对内容进行分组，使得我们可以容易地将不同的环境（如Java与NodeJs）区分开来，本次Demo中的roles下有三个文件夹，分别是common、jenkins和nginx，其中每个文件夹下都会定义一些例如`tasks`任务与相关配置文件。
####role - common
前面已经说过本次demo需要在本地启动两台虚拟机，分别在内部装上docker，在common中我们定义了安装docker的task，这样在定义jenkins服务器和部署nginx的服务器中都可以调用该task来安装配置docker环境；
####role - jenkins
定义安装和部署jenkins服务器的task：其中docker-compose.yml配置文件，是用于分别对jenkins-master和jenkins_slave进行一些基本配置；task下的main.yml文件是配置一系列的安装命令，类似于在命令行中一行行输入安装和部署命令；
####role - nginx
与jenkins文件夹类似，对Nginx服务器的一些基本配置：例如Nginx配置文件default.conf，配置文件中定义了templates下的index.html作为Nginx的入口模版文件，使Nginx作为一个文件服务器。task下的main.yml文件则是与jenkins中类似，配置了安装部署命令，在使用vagrant up时通过Ansible来安装并运行Nginx服务。
###配置文件
Ansible的配置文件包括但不仅限于ansible.cfg、deploy.yml以及hosts
####ansible.cfg文件
如在本Demo中用到的几个配置：

* forks：设置在与主机通信时的默认并行进程数，默认值为5；
* inventory：设置主机与组之间的对应关系，在Ansible1.9之前使用的是hostfile；
* host\_key_checking：检测主机密钥的功能，可以通过设置值为false来禁用该功能（跳过两台主机之间首次连接需要确认的过程）；
* nocows：设置其值为1时禁用调用一些cowsay的特性，cowsay是linux系统下一个在终端用ASCII码组成的小牛，这个小牛会说出你想要它说的话。
* gathering：控制默认的远程系统变量（facts）收集，有三种不同的值； 默认是`implicit`，即每一次play，变量都会被收集，除非设置`gather_facts: False`；为`explicit`时，则facts不会被收集；为`smart`时，则没有facts的新hosts将不会被扫描，用于节省fact收集；
* fact\_caching_timeout：定义fact缓存超时时间；
* fact_caching：定义fact的缓存，2.4版本的Ansible支持`redis`和`jsonfile`两种格式的缓存文件；
* fact\_caching_connection:定义cache的存储位置，根据cache文件的格式不同定义的方式不同；

####deploy.yml文件
我们先来写一个playbook的入口配置文件：定义hosts主机、以及相应主机需要执行的tasks等；

```
- hosts: all
  tasks:
    - debug: var=ansible_distribution,ansible_env

- hosts: jenkins
  become: yes
  roles:
    - common
    - jenkins

- hosts: nginx
  become: yes
  roles:
    - common
    - nginx
```

####hosts
然后加上远程主机的网络相关配置，以如下命令为例，是为IP地址1192.168.56.102，端口号22的网络地址设置一个别名nginx，且声明其ssh private key文件的地址；

```
nginx \
ansible_ssh_host=192.168.56.102 \
ansible_connection=ssh \
ansible_ssh_user=vagrant \
ansible_ssh_port=22 \
ansible_ssh_private_key_file=../.vagrant/machines/nginx/virtualbox/private_key
```

##开始创建世界！
###Vagrantfile
我们来新建一个工程，在根目录创建一个名为Vagrantfile的文件，内容如下：

```
Vagrant.configure("2") do |config| #2代表配置文件的版本
  #对于每台虚拟机的统一配置
  config.vm.box = "ubuntu/trusty64"
  config.vm.provider :virtualbox do |v|
    v.customize ["modifyvm", :id, "--memory", 1024]
    v.customize ["modifyvm", :id, "--cpus", 1]
  end

  #对于每台虚拟机依赖的Ansible配置
  config.vm.provision :ansible do |ansible|
    ansible.verbose = "vv"
    ansible.playbook = "playbooks/deploy.yml"
    ansible.inventory_path = "playbooks/hosts"
  end

  #定义名为Nginx的主机，在宿主机上可直接访问192.168.56.101来访问Nginx
  config.vm.define "nginx" do |config|
    config.vm.hostname = 'nginx'
    config.vm.network :private_network, ip: "192.168.56.101"
  end

  #定义名为Jenkins的主机，在宿主机上可直接访问192.168.56.102来访问Jenkins
  config.vm.define "jenkins" do |config|
    config.vm.hostname = 'jenkins'
    config.vm.network :private_network, ip: "192.168.56.102"
  end
end
```

那么现在可以启动了，在命令行内跳转到根目录，使用`vagrant up`就可以将虚拟机按上面的配置启动了，同时在启动完成之后会调用provision模块跑Ansible的对应脚本安装配置虚拟机的依赖工具。启动完成之后，那么一个隔离的环境创建完毕，接下来我们可以在里面任意玩耍了。

**注意**：因为把所有的配置甚至下载启动Jenkins都写到了Ansible中，所以跑完`vagrant up`需要较长时间。

###启动、执行顺序
基本是按Vagrant的配置文件的上下顺序来启动的。具体顺序如下：

1. 按Vagrantfile安装并启动Nginx虚拟机
2. 执行Nginx虚拟机依赖的provision模块
3. 按Vagrantfile安装并启动Jenkins虚拟机
4. 执行Jenkins虚拟机依赖的provision模块

###Jenkins访问Nginx
如果你能把所有环境启动起来并能访问Jenkins主页，但此时你还无法在Jenkins上直接ssh登录到Nginx，因为此时两台机器还没有互信。但是幸运的是Vagrant启动完Nginx之后就已经将私钥（可以拿这个私钥去访问Nginx，无论你是谁）放到了宿主机上，那么你可以手动将这个私钥复制到Jenkins中，然后就可以在Jenkins中访问Nginx了。

**但是为了自动化上面的操作，进行以下的配置：**
下面这段配置会在Nginx虚拟机启动之后，Jenkins虚拟机启动之前执行。由于Jenkins虚拟机需要在部署代码的时候使用到Nginx虚拟机的私钥来部署，所以需要在Jenkins虚拟机执行Ansible之前将私钥放到Jenkins的file文件夹中。

```
config.vm.define "nginx" do |config|
  config.vm.hostname = 'nginx'
  config.vm.network :private_network, ip: "192.168.56.101"

  config.vm.provision :host_shell do |host_shell|
    host_shell.inline = 'vagrant/bootstrap.sh' #会在主机上执行的脚本
  end
end
```

另外，在Vagrantfile中，Ansible不是与两台虚拟机的配置写在一起的，那么Ansible如何判断在哪台虚拟机上安装Nginx还是Jenkins呢？因为不同的虚拟机要执行Ansible的时候会根据主机名匹配来找到对应role的tasks从而还是能找到匹配的tasks。换句话说，Nginx安装完成之后Vagrant携带Nginx相关参数执行下面这样的一行命令来用limit匹配主机与对应Ansible的tasks：

```
ansible-playbook \
--connection=ssh \
--timeout=30 \
--extra-vars="ansible_ssh_user='vagrant'" \
--limit="nginx" \
--inventory-file=playbooks/hosts \
-vv playbooks/deploy.yml
```

#虚拟机中的世界是如何构成的呢
现在你已经将所有的环境部署完成了，但是部署应用（Jenkins、Nginx）的过程还没有提及，下面将带你从Ansbile的对于每个虚拟机的任务开始，介绍相应的工具与具体的实施步骤。
##Docker
###什么是docker
Docker是一个开源的容器应用引擎，可以理解为一个存放应用容器的平台，我们只需要简单的几行命令就可以构建一个与本地环境相对隔离的环境来运行我们的应用而不影响任何角色；

基本要素：

* Container：负责应用程序的运行，包括操作系统、用户添加的文件以及元数据
* Images：只读模版，即常说的Docker镜像，用来运行Docker容器
* Dockerfile：文件指令集，用来说明如何创建Docker镜像

###为什么要用Docker
Docker的图标：
{% img /images/blog/2018-02-05_4.png 'image' %}

把一个应用封装起来，可以在任何装有Docker的环境下运行，统一运行环境；

那个大鲸鱼（或者是货轮）就是操作系统，把要交付的应用程序看成是各种货物，原本要将各种各样形状、尺寸不同的货物放到大鲸鱼上，你得为每件货物考虑怎么安放（就是应用程序配套的环境），还得考虑货物和货物是否能叠起来（应用程序依赖的环境是否会冲突）。

现在使用了集装箱（容器）把每件货物都放到集装箱里，这样大鲸鱼可以用同样地方式安放、堆叠集装了，省事省力。

###Docker中常用的命令

```
docker run xxx： 启动一个容器
docker start／stop／restart xxx：开启／停止／重启xxx的容器
docker images: 查看所有镜像列表；
docker ps：查看所有运行中的容器；
docker rmi：从本地移除一个或多个指定的镜像；
```

更多Docker相关内容请参考：https://yeasy.gitbooks.io/docker_practice/content/introduction/
###怎么用
demo中的用法：在demo中使用Docker运行Nginx和运行jenkins的方式不同；

####安装Nginx：由于Nginx只有一个container，直接使用docker中run的命令去repository中下载安装即可

* 准备文件，例如default.conf,index.html

```
- name: copy nginx config file
  copy:
    src: default.conf
    dest: /data/nginx/default.conf

- name: copy default html file
  template:
    src: index.html
    dest: /data/nginx/html/index.html
    owner: vagrant
    group: vagrant
```

* 使用Ansible中提供的Docker模块安装Nginx，包括拉docker images，设置ports，以及多久需要pull一次新代码等

```
- name: start nginx container
  docker:
    name: app
    image: nginx:alpine
    pull: always
    state: reloaded
    ports:
      - "80:80"
    volumes:
      - /data/nginx/default.conf:/etc/nginx/conf.d/default.conf
      - /data/nginx/html:/usr/share/nginx/html
```


####安装jenkins：demo中需要用到jenkins-master和jenkins-slave两个container，因此使用docker-compose更加方便
#####比较dockerfile与docker-compose
* dockerfile是把构建一个docker image过程记录到一个文档里面，通过运行docker build来进行镜像的构造。
* docker-compose则是定义你需要哪些images，每个image应该怎么配置，要挂载哪些volume等信息，但是不包含构建image的信息，像咱们demo中所用到的image都是直接从docker registry中拉取下来的，所以事实上也不需要用到dockerfile。

docker-compose.yml中定义了镜像的地址、端口号等，并通过执行它进行在docker中的部署。其中slave节点选用了jaydp17/jenkins-slave这样一个包含Java、git、curl环境的Image方便执行持续集成任务。

```
services:
  jenkins_master:
    container_name: jenkins-master
    image: jenkinsci/jenkins
    restart: always
    posts: - "8080:8080"
           - "50000:50000"
    volumns: demo/jenkins:/var/jenkins_home

  jenkins_slave_1:
    container_name: jenkins_slave_1
    image: jaydp17/jenkins-slave
    depends_on:
      - jenkins_master
    volumes:
    - /data/jenkins:/var/jenkins_home
```

###Nginx
####什么是Nginx
一款轻量级的Web 服务器/反向代理服务器及电子邮件（IMAP/POP3）代理服务器

####为什么用Nginx
首先需要一个服务器来部署我们的应用，而常用的服务器有例如apache的Apache HTTP Server、Nginx、tomcat等；
Nginx是为了解决互联网业内著名的 “C10K” 问题而生；
> The C10k problem is the problem of optimising network sockets to handle a large number of clients at the same time. The name C10k is a numeronym for concurrently handling ten thousand connections.

其中Nginx通常用来做静态内容服务器，而tomcat一般用于做动态应用的服务器，通常称之为web容器；
Nginx相比于apache的优点：

* 轻量级，同样起web服务，比apache占用更少的内存及资源；
* 抗并发，Nginx处理请求是异步非阻塞的，而apache则是阻塞型的，在高并发下Nginx能保持低资源低消耗高性能
* 提供负载均衡；
* 配置简洁；
* 社区活跃，各种高性能模块出品迅速等；

####怎么用Nginx
本次demo中使用Ansible的一个task来定义安装配置Nginx需要的操作流程，用的是docker提供的Nginx镜像，在docker中安装配置Nginx，为了使ngixn能够启动起来，我们还需要进行一系列的配置，包括配置文件和模版文件等；default.conf就是Nginx的配置文件，此处http模块的相关配置：

* listen 80：监听的端口号是80；
* default_server：设定为默认虚拟主机；
* server_name localhost：设置虚拟主机名称为localhost；
* root /usr/share/nginx/html：设置web服务URL资源映射的本地文件系统的资源所在的目录；
* index index.html index.htm：定义默认主页面；

```
server {
    listen 80 default_server;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html index.htm;
}
```

还有一些其他的配置，详情请参考[https://www.nginx.com/resources/wiki/start/topics/examples/full/](https://www.nginx.com/resources/wiki/start/topics/examples/full/)


Ansible关于Nginx的task中yml文件的配置：

创建文件夹 --> copy Nginx的配置文件到环境中 --> copy模版文件 --> 以及使用docker镜像运行Nginx；

```
- name: create folder
...
- name: copy nginx config file
...
- name: copy default html file
...
- name: start nginx container
...
```

##世界有了，来联通各国吧
到现在为止，你已经了解了所有我们使用的工具以及通过运行命令搭建完成了一套持续集成环境的基础设施，但是还需要对Jenkins进行一些配置才能真正做到持续集成。
###Jenkins的配置
现在你可以访问 http://192.168.56.102:8080 了，然后页面提示需要你输入**Administrator password**。该密码可以通过下面的方式获取：

1. 进入Jenkins虚拟机：`vagrant ssh jenkins`
2. 获取root权限：`sudo su`
3. 进入Jenkins master容器：`docker exec -it jenkins_master bash`
4. 找到密码：`cat /var/jenkins_home/secrets/initialAdminPassword`

然后将密码复制到页面上点击确定，随后点击安装推荐的插件，本文将使用到的Jenkins功能不会超出推荐的插件的范围。然后创建好用户就可以登录了。

####Slave
来到主界面之后，接下来我们来配置一台slave节点来帮我们执行任务，依次点击Manage Jenkins -> Manage Nodes -> New Node，按照下图进行配置。

{% img /images/blog/2018-02-05_2.png 'image' %}

简单起见，用密码登录的方式进行身份验证，用户名密码都为jenkins

{% img /images/blog/2018-02-05_3.png 'image' %}

如果你现在能在Jenkins界面上看到你刚刚创建的slave节点，那么已经完成配置了。另外，为了能让后面的部署过程100%在slave节点上执行，建议点击master节点右方的配置按钮将默认开启的master节点中的executors数量改为0。

####创建Pipeline
接下来我们将创建一条流水线。回到Jenkins首页，然后

1. 点击 create new jobs
2. 选择Pipeline分类点击OK
3. 勾上Poll SCM，并填入`* * * * *`，让Jenkins每分钟帮我们check一次Github上是否有提交。
4. Definition中选择'Pipeline script from SCM'，我们通过Jenkinsfile去定义整条Pipeline
5. SCM中选择Git，Repository URL	填入 https://github.com/xbox1994/chicken-html.git 或者你自己创建的包含Jenkinsfile、部署脚本、index.html的项目。
6. 完成配置，点击Save，Jenkins会自动触发第一次的持续集成。

当你能在deploy阶段看到下面的输出

```
[chicken] Running shell script
+ ./deploy.sh
--------------------------start to deploy...--------------------------
--------------------------deploy finished ! --------------------------
```

并且访问http://192.168.56.101 ，能看到下面的文字，那么恭喜你，顺利通关！

```
恭喜！
如果你能看到此页面，代码已经部署成功！可以试试修改此文件继续提交部署
```

####触发Pipeline
请尽情的提交吧，试试看Jenkins会不会把你的代码拉下来触发Pipeline。

###html项目的脚本配置
即使你已经成功触发多次Pipeline，但是其中还有些配置没有讲到，这些配置隐藏**在项目代码中**。个人认为对于这个项目有关的配置就应该放到项目代码中，除非有其他统一的配置管理方式。

比如chicken-html中的目录如下：

```
├── Jenkinsfile
├── deploy.sh
└── index.html

```

####测试、构建
如果你用到gradle、maven这样的工具来管理你的项目构建。平时在开发的时候只需要运行`./gradlew clean build`和`./gradlew test`来进行构建与测试。那么到Jenkins上也是基于这些命令来进行的
####部署代码到服务器
部署代码这步操作是会在Jenkins slave节点上进行，将从Github上拉来的代码部署到Nginx服务器中，那么最简单的方式就是使用`scp`命令将需要部署的文件发送到Nginx服务器。在Ansbile脚本中已经把Nginx服务器的私钥复制到了slave节点所在的服务器中了，所以可以直接执行`scp`命令。

在本文涉及到的html项目中的部署脚本如下：

```
#!/bin/bash
echo '--------------------------start to deploy...--------------------------'
scp -o StrictHostKeychecking=no -i /var/jenkins_home/nginx_private_key index.html vagrant@192.168.56.102:/data/nginx/html/index.html
echo '--------------------------deploy finished ! --------------------------'
```

对于Nginx服务器来说，如果配置中指定的html文件发生变化，会检测到并将最新的html文件返回给用户。

####Jenkinsfile

```
node{
    stage('git clone'){
       git url: 'https://github.com/xbox1994/chicken-html.git'
    }

    stage('test'){
        sh "echo 'test done'" /* 可以替换为./gradle test */
    }

    stage('build'){
        sh "echo 'build done'"/* 可以替换为./gradle clean build */
    }

    stage('deploy'){
        sh "./deploy.sh"
    }
}
```

这个文件定义了Jenkins中这个项目的Pipeline里应该如何被执行，每一步都做些什么操作，如定义了4个stage分别对应拉代码、测试、构建、部署，其中部署脚本执行的就是使用`scp`命令执行的。当然这个是最简单的Pipeline任务定义，你可以参考[https://jenkins.io/doc/book/pipeline/jenkinsfile/](https://jenkins.io/doc/book/pipeline/jenkinsfile/)来使用更方便的功能如“when”语句来检测上一个stage是否成功完成。