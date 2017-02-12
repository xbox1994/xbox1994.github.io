---
layout: post
title: "SSH登录原理简介"
date: 2017-01-16 22:19:46 +0800
comments: true
categories: Devops
---

每次都用SSH登录,却没有关心过其中的原理,实在没脸用SSH

<!--more-->
##什么是SSH?
简单说，SSH是一种网络协议，用于计算机之间的加密登录。

如果一个用户从本地计算机，使用SSH协议登录另一台远程计算机，我们就可以认为，这种登录是安全的，即使被中途截获，密码也不会泄露。

最早的时候，互联网通信都是明文通信，一旦被截获，内容就暴露无疑。1995年，芬兰学者Tatu Ylonen设计了SSH协议，将登录信息全部加密，成为互联网安全的一个基本解决方案，迅速在全世界获得推广，目前已经成为Linux系统的标准配置。

需要指出的是，SSH只是一种协议，存在多种实现，既有商业实现，也有开源实现。本文针对的实现是OpenSSH，它是自由软件，应用非常广泛。

转自http://www.ruanyifeng.com/blog/2011/12/ssh_remote_login.html

##从用到懂
###用
  Secure Shell is a protocol used to securely log onto remote systems.
  It can be used for logging or executing commands on a remote server.

  - Connect to a remote server:  
    ssh username@remote_host

  - Connect to a remote server with a specific identity (private key):  
    ssh -i path/to/key_file username@remote_host

  - Connect to a remote server using a specific port:  
    ssh username@remote_host -p 2222

  - Run a command on a remote server:  
    ssh remote_host command -with -flags

  - SSH tunneling: Dynamic port forwarding (SOCKS proxy on localhost:9999):  
    ssh -D 9999 -C username@remote_host

  - SSH tunneling: Forward a specific port (localhost:9999 to slashdot.org:80):  
    man ssh_config

  - Enable the option to forward the authentication information to the remote machine (see man ssh_config for available options):  
    ssh -o "ForwardAgent=yes" username@remote_host

引用自tldr(与fuck一样是一辈子都要用的,实在是太好用了)

具体配置SSH客户端的文件在
  - ~/.ssh/config
  - /etc/ssh/ssh_config
  
ssh_config -- OpenSSH SSH client configuration files,与SSH连接的配置项,如超时控制,连接策略

###懂
SSH之所以能够保证安全，原因在于它采用了公钥加密。  
（1）远程主机收到用户的登录请求，把自己的公钥发给用户。  
（2）用户使用这个公钥，将登录密码加密后，发送回来。  
（3）远程主机用自己的私钥，解密登录密码，如果密码正确，就同意用户登录。

SSH公钥登录：  
用户将自己的公钥储存在远程主机上。登录的时候，远程主机会向用户发送一段随机字符串，用户用自己的私钥加密后，再发回来。远程主机用事先储存的公钥进行解密，如果成功，就证明用户是可信的，直接允许登录shell，不再要求密码。

SSH私钥登录：  
类似公钥登录，前提是将一个公钥存储在远程主机上，然后加一个i参数使用这个公钥对应的私钥去加密字符串发送给服务器

###安全威胁
如果攻击者插在用户与远程主机之间（比如在公共的wifi区域），用伪造的公钥，获取用户的登录密码。再用这个密码登录远程主机，那么SSH的安全机制就荡然无存了,这就是中间人攻击,对于这个问题,SSH有自己的一套简易防范措施:

第一次连接时会显示公钥指纹，跟对方确认后连接，一般是在官方网站上有对应指纹提供给用户验证,当选择yes,就会将该主机的公钥追加到该主机本地文件~/.ssh/known_hosts中。当再次连接该主机时，会比对这次连接的主机公钥与之前保存的公钥是否一致

如果因为某种原因（服务器系统重装，服务器间IP地址交换，DHCP，虚拟机重建，中间人劫持），该IP地址的公钥改变了，当使用 SSH 连接的时候，会报错：Host key verification failed.

如果自己可以确认对方域名是绝对安全可靠的,即使IP变动也是正常的话,那么可以使用如下方式省去验证步骤:  
只需要修改 /etc/ssh/ssh_config 文件，包含下列语句：  
Host *  
 StrictHostKeyChecking no  
或者在 ssh 命令行中用 -o 参数  
ssh  -o StrictHostKeyChecking=no  192.168.0.110

如果设置了无口令 SSH 登录（即通过客户端公钥认证），就可以直接连接到远程主机。这是基于 SSH 协议的自动化任务常用的手段。

部分引用自:http://www.worldhello.net/2010/04/08/1026.html


