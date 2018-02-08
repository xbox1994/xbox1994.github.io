---
layout: post
title: "手把手教你搭建一个持续集成环境"
date: 2018-02-05 18:47:16 +0800
comments: true
categories: Devops
---

本文将带领你从0开始，用Vagrant + Docker + Jenkins + Ansible + GitHub等工具和资源来搭建一条可执行可扩展的持续集成流水线，即使这些名字你都没听过也没关系，本文将会在需要的时候一一解释给你听。

<!-- more -->

#总览
这是我们将要搭建的所有基础设施的总体架构图，我们将在本文中手把手教你搭建这样一个持续集成环境。

{% img /images/blog/2018-02-05_1.png 'image' %}

我们会在本地启动两台虚拟机，一台部署Nginx作为静态文件服务器，一台作为Jenkins服务器，在每台虚拟机内部安装Docker，使用Docker来完成Nginx与Jenkins的搭建、配置，然后手动在Jenkins配置内配置好一条Pipeline作为持续集成流水线，最后尝试提交一次代码去触发一次持续集成操作，将最新的html项目代码从Github上部署到Nginx中，实现持续集成。

本文参考完成源代码在此：[https://github.com/tw-wh-devops-community/cooking-chicken.git](https://github.com/tw-wh-devops-community/cooking-chicken.git)。建议先按照源码跑通一次本文中的所有步骤，然后自己尝试从0开始搭建一个相同的环境出来。相信你一定会碰到很多坑，但坑外便是晴天。

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
###为什么呢
比较与命令行的好处
###安装Ansible
参考vagrant安装
###用Ansible来帮助我们创建世界
参考源代码来介绍Ansible目录结构、针对不同的虚拟机介绍所执行的相同和不同的任务
####目录结构
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
        │   └── nginx.cfg
        ├── tasks
        │   └── main.yml
        └── templates
            └── index.html
```
这里需要解释目录结构

####配置文件
将cfg yml host文件进行解释。

##开始创建世界！
###Vagrantfile
终于可以开始动手啦。我们来新建一个工程，在根目录创建一个名为Vagrantfile的文件，内容如下：

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
ansible-playbook
--connection=ssh
--timeout=30
--extra-vars="ansible_ssh_user='vagrant'"
--limit="nginx"
--inventory-file=playbooks/hosts
-vv playbooks/deploy.yml
```

#虚拟机中的世界是如何构成的呢
现在你已经将所有的环境部署完成了，但是部署的过程还没有提及，下面将带你从Ansbile的对于每个虚拟机的任务开始，介绍相应的工具与具体的实施步骤。
###Docker
###Nginx
###Jenkins

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
3. 勾上Poll SCM，并填入‘* * * * *’，让Jenkins每分钟帮我们check一次Github上是否有提交。
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