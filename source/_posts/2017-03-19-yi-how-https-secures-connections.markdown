---
layout: post
title: "[译]How HTTPS Secures Connections"
date: 2017-03-19 04:15:33 +0800
comments: true
categories: 翻译
---
译自：https://blog.hartleybrody.com/https-certificates/

#HTTPS如何加密连接：每个Web开发者都应该知道的东西

##为什么
在我们试图深入了解所有的原理之前，让我们讨论为什么首先加密连接是很重要的，还有HTTPS在守卫着什么。

当你发送请求给你喜爱的网站时，请求必须通过很多不同的网络连接，其中任何一个网络都可能用来窃听或者篡改你的连接。

![](https://blog.hartleybrody.com/wp-content/uploads/2013/07/series-of-tubes.png)

在局域网中，从你的电脑到其他机器，再到接入点本身，一路通过路由器和交换机到ISP（互联网提供商），这些很多请求在不同的机构中像渡轮一样传递。如果一个恶意的用户进入它们中任何一个系统，他可以看到在网线中传播的东西。

通常来说，web请求通过常规请求被发送，其中客户端的请求和服务器的请求都用明文发送。有很多原因[为什么HTTP默认不用安全加密](https://security.stackexchange.com/questions/18853/why-arent-application-downloads-routinely-done-over-https/18861#18861)：

* 安全性需要更多的计算能力
* 安全性需要更多带宽
* 安全性打破缓存机制

但是有时，作为一个web开发者，我们知道像密码或者信用卡数据一样敏感的信息将被在网络上传递，所以采取额外的预防措施防止被那些页面窃取。

##传输层安全（TLS）
我们将要深入了解密码学的世界，但是你不需要很多经验去跟上我们的节奏。我们将真正只涉及一些表面的东西。

密码学是保护通信存在潜在对手的做法-有人获取想去破坏通信或者只是监听。

TLS-SSL的继承者-是一个最多被用来实现HTTP加密连接的协议（比如HTTPS）。TLS在[OSI模型](https://en.wikipedia.org/wiki/OSI_model#Examples)中比HTTPS在更低的级别，在web请求之间，TLS连接发生在HTTP连接建立之前。

TLS是一个混合加密系统，意味着它将利用多个加密步骤，我们来看看有哪些：

1. 共享密码生成和授权（确保你是你说的那个人）的**公钥加密**
2. 使用共享密钥加密请求和相应的**对称密钥加密**

##公钥加密
译者注：目的是为了加密信息实体而得到一个双方公用的秘钥。

公钥加密是一种每一方都有在数学意义上连接彼此的公钥和私钥的加密系统。公钥用来加密明文为密文（基本上变成乱七八糟的一串字符，你懂得）而私钥是用来解密密文为明文的东西。

一旦一个消息被公钥加密，它只能被对应的私钥解密。它们不能同时拥有加密和解密的本领。公钥能被自由发布而不会影响系统的安全性，但是私钥必须不能被任何一个不是授权对象的人知道。都是因为它们的名字，公钥和私钥（are you kidding?）

公钥加密有一个很棒的好处是当开始通过一个公开，不安全的连接加密时，即使双方没有之前没有沟通过，也能创建一个加密的连接。

客户端和服务器都能拥有他们自己的私钥-以及一些公共的信息-来商定本次会话的共享密钥。这意味着即使有人在客户端和服务器之间并且监听连接建立发生，他也不能确定客户端或者服务器的密钥，或者会话的密钥。

这怎么可能？都是因为密码学！

**Diffie-Hellman**  
一个最通用的交换方式就是它。这个过程允许客户端和服务器同意一个共享的秘密，而不通过连接发送秘密。监听者不能得到这个秘密即使他正在监听每一个数据包。

一旦DH交换发生，所得到的共享秘密可以被用来加密更进一步的通信，我们会在下面看到。

**一点数学知识**		
在它后面是一个相当简单的计算方法，但是基本上不可能逆转。这是存在大素数的重要性。

如果A和B是用DH来执行数据交换，他们通过在根（通常是小数字，如2,3或5）和大素数（300+数字）上同意而开始，这两者可以在不损害交换的安全性的情况下被清楚地发送。

记住，A和B都有自己的没有被共享的私钥（100多个数字）。在网络上公开交换的是他们的私钥加上跟和素数的混合体。

A的混合体=（根<sup>A的私钥</sup>）%素数
B的混合体=（根<sup>B的私钥</sup>）%素数
%是模，取余数

所以A在常量（根和素数）上加上他的私钥，B也这样做。一旦他们收到对方的混合体，他们执行更多的数学运算来导出会话中的信息。

A的计算：
（B的混合体<sup>A的私钥</sup>)%素数
B的计算：
（A的混合体<sup>B的私钥</sup>)%素数

这个计算公式为A和B产生相同的数字，这个数字就是在会话中被共享的秘密。牛逼！

为了少一些数学概念，维基有一个很好的有混合颜色的图![](https://blog.hartleybrody.com/wp-content/uploads/2013/07/Diffie-Hellman_Key_Exchange.png)

注意起始颜色（黄色）最终是如何与A和B的颜色混合。这就是最终如何在双方是一样的过程。被通过连接发送的只是中途混合的过程，这对任何监听这个连接的人是没有意义的。

译者来了个Java实现：

	public class Test1 {
	    public static final int P=30;//公开的大家都知道的
	    public static final int G=9;//公开的大家都知道的
	 
	    public static void main(String[] args) {
	        A x = new A();
	        int one = x.getV();
	        //分割 A 代表A这边的系统加密  one 代表是给别人的值
	        B y = new B();
	        int two = y.getV();
	        //B 代表另外一边加密 two 代表是给别人的值
	        System.out.println(x.getKey(two));
	        System.out.println(y.getKey(one));
	    }
	}
	 
	class A{
	    private int a;//自己的私有密值,不会告诉任何人
	     
	    public A() {
	         Random r = new Random(200);
	        a=r.nextInt();
	    }
	     
	    public int getV(){
	        return (Test1.G^a)%Test1.P;
	    }
	     
	    public int getKey(int v){
	        return (v^a)%Test1.P;
	    }
	}
	 
	class B{
	    private int b;//自己的私有密值，不会告诉任何人
	     
	    public B() {
	        Random r = new Random(200);
	        b=r.nextInt();
	    }
	    public int getV(){
	        return (Test1.G^b)%Test1.P;
	    }
	     
	    public int getKey(int v){
	        return (v^b)%Test1.P;
	    }
	}
##对称密钥加密