---
layout: post
title: "[译]How HTTPS Secures Connections"
date: 2017-03-19 04:15:33 +0800
comments: true
tags: 翻译
---
译自：https://blog.hartleybrody.com/https-certificates/
<!--more-->
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

##HTTPS加密全过程
我们首先来熟悉一下加密的全过程，然后对其中的证书交换细节作详细解释。

1. Hello - 握手开始于客户端发送Hello消息。包含服务端为了通过SSL连接到客户端的所有信息，包括客户端支持的各种密码套件和最大SSL版本。服务器也返回一个Hello消息，包含客户端需要的类似信息，包括到底使用哪一个加密算法和SSL版本。
2. 证书交换 - 现在连接建立起来了，服务器必须证明他的身份。这个由SSL证书实现，像护照一样。SSL证书包含各种数据，包含所有者名称，相关属性（域名），证书上的公钥，数字签名和关于证书有效期的信息。客户端检查它是不是被CA验证过的且根据[数字签名](https://www.jianshu.com/p/9db57e761255)验证内容是否被修改过。注意服务器被允许需求一个证书去证明客户端的身份，但是这个只发生在敏感应用。
3. 密钥交换 - 先使用RSA非对称公钥加密算法（客户端生成一个对称密钥，然后用SSL证书里带的服务器公钥将改对称密钥加密。随后发送到服务端，服务端用服务器私钥解密，到此，握手阶段完成。）或者DH交换算法（上面有）在客户端与服务端双方确定一将要使用的密钥，这个密钥是双方都同意的一个简单，对称的密钥，这个过程是基于非对称加密方式和服务器的公钥/私钥的。
4. 加密通信 - 在服务器和客户端加密实际信息是用到对称加密算法，用哪个算法在Hello阶段已经确定。对称加密算法用对于加密和解密都很简单的密钥，这个密钥是基于第三步在客户端与服务端已经商议好的。与需要公钥/私钥的非对称加密算法相反。

参考：  
http://robertheaton.com/2014/03/27/how-does-https-actually-work/  
https://mp.weixin.qq.com/s?__biz=MjM5MjY3OTgwMA==&mid=2652455231&idx=1&sn=42fc62fd1b27e3f9355b83fcc0f91e77

##传输层安全（TLS）
我们将要深入了解密码学的世界，但是你不需要很多经验去跟上我们的节奏。我们将真正只涉及一些表面的东西。

密码学是保护通信存在潜在对手的做法-有人获取想去破坏通信或者只是监听。

TLS-SSL的继承者-是一个最多被用来实现HTTP加密连接的协议（比如HTTPS）。TLS在[OSI模型](https://en.wikipedia.org/wiki/OSI_model#Examples)中比HTTPS在更低的级别，在web请求之间，TLS连接发生在HTTP连接建立之前。

TLS是一个混合加密系统，意味着它将利用多个加密步骤，我们来看看有哪些：

1. 共享密码生成和授权（确保你是你说的那个人）的**公钥加密**
2. 使用共享密钥加密请求和相应的**对称密钥加密**

##公钥加密

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

_**A的混合体=（根<sup>A的私钥</sup>）%素数**_

_**B的混合体=（根<sup>B的私钥</sup>）%素数**_

%是模，取余数

所以A在常量（根和素数）上加上他的私钥，B也这样做。一旦他们收到对方的混合体，他们执行更多的数学运算来导出会话中的信息。


_**A的计算：（B的混合体<sup>A的私钥</sup>)%素数**_

_**B的计算：（A的混合体<sup>B的私钥</sup>)%素数**_

这个计算公式为A和B产生相同的数字，这个数字就是在会话中被共享的秘密。牛逼！

为了少一些数学概念，维基有一个很好的有混合颜色的图

![](https://blog.hartleybrody.com/wp-content/uploads/2013/07/Diffie-Hellman_Key_Exchange.png)

注意起始颜色（黄色）最终是如何与A和B的颜色混合。这就是最终如何在双方是一样的过程。被通过连接发送的只是中途混合的过程，这对任何监听这个连接的人是没有意义的。

译者Java实现：

```java
	import java.math.BigInteger;

public class Main {
    //公开的A和B都知道的素数和素数的原根
    public static final BigInteger ROOT = BigInteger.valueOf(5);
    public static final BigInteger PRIME = BigInteger.valueOf(97);

    public static void main(String[] args) {
        ShyMan a = new ShyMan(111);
        int mixtureA = a.getMixture();
        ShyMan b = new ShyMan(222);
        int mixtureB = b.getMixture();

        //mixtureA and mixtureB will be transmitted in network, but it is meaningless for anyone
        System.out.println(mixtureA);
        System.out.println(mixtureB);

        //Alice and Bob will get the same key number from each other
        System.out.println(a.getCommonKey(mixtureB));
        System.out.println(b.getCommonKey(mixtureA));
    }
}

class ShyMan {
    //自己的私有密值,不会告诉任何人
    private int private_key_number;

    public ShyMan(int private_key_number) {
        this.private_key_number = private_key_number;
    }

    public int getMixture() {
        return Main.ROOT.pow(private_key_number).mod(Main.PRIME).intValue();
    }

    public int getCommonKey(int mixture) {
        return BigInteger.valueOf(mixture).pow(private_key_number).mod(Main.PRIME).intValue();
    }
}
```

##对称密钥加密
公钥交换在每次会话中仅需要发生一次，就是在客户端和服务端连接的时候。一旦他们确认使用这个公钥，客户端和服务端用[对称密钥加密系统](https://en.wikipedia.org/wiki/Symmetric-key_algorithm)，这更有利于高效的通信因为它在每次通信中都节省了一次往返。

在他们使用公钥的基础上，加上一个商定的密码套件（本质上是一个加密算法的集合），客户端和服务端现在就可以加密通信，窥探着也只能看见乱七八糟的数据来回。

##验证
DH允许双方创建一个私有且共享的密钥，但是他们怎么知道他们得到了对方真正的消息？我们到目前为止还没有谈论过验证这个东西。

如果我拿起我的电话给朋友打电话并且我们用DH来加密，但是有没有可能我的这次通信被截获然后实际上我在和别人通话？我确实在进行安全的通信-一旦我们开始商议DH密钥那么没有任何人能解码我们的通信-但是对方不一定是我们想联系的那个人。那么这样还是非常危险的。

为了解决验证这个问题，我们需要[公钥基础设施](https://en.wikipedia.org/wiki/Public_key_infrastructure)来确保他确实是他。这个基础设施的建立是为了创建，管理和注销签名证书。证书是一个头疼的事这是因为你要付费，为了让你的网站使用HTTPS。

但是什么是证书？它怎么就能让通信变得安全？
##证书
从一个比较高的角度来看，公钥证书是个用数字签名将机器的公钥和机器的身份绑定的文件，证书上的数字签名是用来让某个个人或组织担保一个特定的公钥属于另外某个个人或者组织的。

证书基本上将域名与特定公钥联系起来。这就防止监听者看到公钥，然后假装成服务端欺骗客户端。

在上面电话通信的例子中，攻击者可以试图将他的公钥替换掉我朋友的，但是证书上的签名不能被替换。

为了被一般浏览器信任，证书必须被证书证书颁发机构（CA）签名。CA是执行手动检查和审查的公司，确保申请的实体是一个

1. 真实的人或者存在于公共记录的商业实体
2. 他们申请的证书有可控制的域名

一旦CA验证申请人是真实的并且有他们自己的域名，CA将给证书签名，基本上如果他们批准之后，网站的公钥就应该被信任了。

你的浏览器预先加载了一个受信任的CA列表。如果服务器返回一个不是由受信任CA颁发的证书，他讲闪烁一个大红色的错误警告。否则任何人都可以绕过去从而“签署”伪造证书。

![](https://blog.hartleybrody.com/wp-content/uploads/2013/07/https-security-warning.gif)

因此即使攻击者使用它们自己机器的公钥并且生成证书说这个证书是facebook的，浏览器不能信任他因为证书的办法机构不是CA。

##关于证书的其他事项
**扩展验证证书（EV）**

除了通用的X.509证书，[扩展验证证书](https://en.wikipedia.org/wiki/Extended_validation)承诺了一个更强的信任级别。

当授予一个EV时，CA必须做更多检查拥有域名的实体的身份（通常需要护照或者水电费）。

这种证书让浏览器地址栏变绿，除了显示通常只显示的锁图标。

**可服务多个网站的同一服务器**

因为TLS在HTTP连接建立之前发生握手，如果多个网站建立在IP地址相同的同一个服务器上就会有问题。

命名的虚拟主机路由发生在Web服务器中，但是握手发生在连接到达之前。该系统的单个证书需要被发送到该计算机托管的任何站点，这可能会产生[共享主机环境的问题](https://en.wikipedia.org/wiki/Transport_Layer_Security#Support_for_name-based_virtual_servers)。

如果你用网站运营公司，那么一般你需要购买专用的IP地址在你设置HTTPS之前。否则当网站更新时每次都需要获取新证书（并且从CA那里再次验证）译者注：为什么？AWS是一个反例？

## 号外号外
最近在总结一些针对**Java**面试相关的知识点，感兴趣的朋友可以一起维护~  
地址：[https://github.com/xbox1994/2018-Java-Interview](https://github.com/xbox1994/2018-Java-Interview)
