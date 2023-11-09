---
layout: post
title: "OAuth2原理与LinkedIn的第三方分享实战"
date: 2018-12-30 23:19:45 +0800
comments: true
tags: 后台
---

<!-- more -->

## OAuth是什么
开放授权（OAuth）是一个开放标准，允许用户让第三方应用访问该用户在某一网站上存储的私密的资源（如照片，视频，联系人列表），而无需将用户名和密码提供给第三方应用。在全世界得到广泛应用，目前的版本是2.0版。

比如我的应用需要实现在领英上替用户分享一个动态，但是只有得到用户的授权才能在我的应用中调用领英的API进行分享操作，如果直接让用户把用户名密码传到我的应用，确实可以实现，但是有以下问题：

* 为了后续的服务，我的应用会保存用户的密码，在我的应用中保存密码很不安全
* 用户无法限制我的应用中能进行哪些操作
* 领英必须要有密码登录的功能，而单纯的密码登录并不安全
* 我的应用中还需要处理验证码这样的额外身份验证情况
* 用户只有修改密码，才能收回权限，但会让所有获得用户授权的第三方应用程序全部失效
* 只要有一个第三方应用程序被破解，就会导致用户密码泄漏，以及所有被密码保护的数据泄漏

OAuth就是为了解决上面这些问题而诞生的。

## OAuth原理

     +--------+                               +---------------+
     |        |--(A)- Authorization Request ->|   Resource    |
     |        |                               |     Owner     |
     |        |<-(B)-- Authorization Grant ---|               |
     |        |                               +---------------+
     |        |
     |        |                               +---------------+
     |        |--(C)-- Authorization Grant -->| Authorization |
     | Client |                               |     Server    |
     |        |<-(D)----- Access Token -------|               |
     |        |                               +---------------+
     |        |
     |        |                               +---------------+
     |        |--(E)----- Access Token ------>|    Resource   |
     |        |                               |     Server    |
     |        |<-(F)--- Protected Resource ---|               |
     +--------+                               +---------------+

* Client：客户端，第三方应用，我的应用就是一个Client
* Resource Owner ：用户
* Authorization Server：授权服务器，即提供第三方登录服务的服务器，如领英
* Resource Server：服务提供商，通常和授权服务器属于同一应用，如领英

根据上图的信息，我们可以知道OAuth2的基本流程为：
1. 用户调用第三方应用的功能，如分享，该功能需要使用用户在服务提供商上的权限，所以第三方应用直接重定向到授权服务器的登录、授权页面等待用户登录、授权。
2. 用户登录之后同意授权，并返回一个凭证（code）给第三方应用
3. 第三方应用通过第二步的凭证（code）向授权服务器请求授权
4. 授权服务器验证凭证（code）通过后，同意授权，并返回一个服务访问的凭证（Access Token）。
5. 第三方应用通过第四步的凭证（Access Token）向服务提供商请求相关资源。
6. 服务提供商验证凭证（Access Token）通过后，将第三方应用请求的资源返回。

简单来说，OAuth在"客户端"与"服务提供商"之间，设置了一个授权层。"客户端"不能直接登录"服务提供商"，只能登录"授权层"，以此将用户与客户端区分开来。"客户端"登录"授权层"所用的凭证（Access Token），与用户的密码不同。用户可以在登录的时候，授权服务器指定授权层令牌的权限范围和有效期。

## LinkedIn的OAuth2交互
下面以在我的应用上实现在领英中替用户分享一个动态为例子，真切地来体验一把OAuth2。

交互图如下，细节会在下面写到：

{% img /images/blog/2018-12-30_1.png 'image' %}

### 配置LinkedIn应用程序
除了领英，其他任意开发者平台都需要我们在平台上注册一个App才能给我们调用平台API的权限，也方便平台对我们的资质审核以及调用管理。

所以首先我们得去领英开发者平台去注册一个App：
https://www.linkedin.com/developer/apps/new

{% img /images/blog/2018-12-30_2.png 'image' %}

* Keys: 完成之后会得到App相关的Key，这是在后续OAuth2交互时需要向领英提供身份验证。  
* 权限：在用户登录时会给用户展示出我的应用需要哪些权限，我的应用最后调用API的时候会检测权限是否允许。  
* 回调API接口：这是在OAuth2交互时需要验证的一个参数，领英只会与已识别为可信终端的URL进行通信。  

### 获取用户授权凭证Code
用户在我的应用中点击【分享】按钮，会发送一个GET请求到`myApp/linkedin/auth/authorization`，其中`linkedin/auth/authorization`是我的应用里暴露出的一个专门用来进行验证的接口。

我的应用收到请求之后直接回复重定向到领英的授权页面，并且重定向的url中必须包含领英实现的OAuth2的一些参数，如下：
{% img /images/blog/2018-12-30_3.png 'image' %}

其中state参数是防止csrf攻击加入进来的，关于csrf以及本例中对csrf防范的实现会在文章最后一部分提到。

在go语言+Beego框架中的实现如下：

```go
func (c *AuthorizationController) Get() {
	host := beego.AppConfig.String("host")
	state := util.Generate(10) // random string with length 10
	clientId := beego.AppConfig.String("linkedin_client_id") // 创建app得到的key
	linkedinOauth2AuthorizationUrl := "https://www.linkedin.com/oauth/v2/authorization?response_type=code&client_id=%s&redirect_uri=%s/linkedin/auth/callback&state=%s"
	uri := fmt.Sprintf(linkedinOauth2AuthorizationUrl, clientId, host, state)

	c.SetSession("_csrf_Token", state)
	c.Redirect(uri, 302)
}
```

### 浏览器跳转到领英页面等待授权
浏览器从上一步中根据重定向url跳转到领英页面，等待用户登录并授权，如果用户已经登录就直接跳转，如下图：

{% img /images/blog/2018-12-30_4.jpg 'image' %}

用户如果点击Cancel，或者请求因任何其他原因而失败，则会将其重定向回redirect_uri的URL，并附加一些错误参数。

用户如果点击Allow，用户批准您的应用程序访问其成员数据并代表他们与LinkedIn进行交互，也会将其重定向回redirect_uri，并附加重要参数**code**

### 通过Code拿到Token，并实现分享
redirect_uri就是我的应用中的callback接口，这个接口等待用户传递一个允许授权的凭证code，在我的应用中就可以拿这个code去领英中申请access token，以后就拿着这个access token去访问领英中允许访问的资源了

```go
func (c *CallbackController) Get() {
	// csrf validation
	csrfToken := c.GetSession("_csrf_Token")
	if csrfToken != c.GetString("state") {
		c.Data["json"] = map[string]interface{}{
			"error":             c.GetString("csrf error"),
			"error_description": c.GetString("error_description")}
		c.ServeJSON()
		return
	}

	// user cancel authorization request or linkedin server error
	if c.GetString("error") != "" {
		c.Data["json"] = map[string]interface{}{
			"error":             c.GetString("error"),
			"error_description": c.GetString("error_description")}
		c.ServeJSON()
		return
	}

	// user accept authorization request
	code := c.GetString("code")
	if code != "" {
		// get access token by code
		accessToken := getAccessToken(code)
		// share by access token
		shareResponse := share(accessToken.AccessToken)
		c.Data["json"] = &shareResponse
		c.ServeJSON()
		return
	}
}
```

getAccessToken和share方法仅仅是发送请求到领英的REST API接口，实际上如果领英有golang的sdk的话，就不需要我们自己使用golang的http包来自己封装请求处理结果了，但可惜领英并没有。

最后给一个GIF图，该图包含了所有的流程展示，从点击【分享】按钮（调用localhost/linkedin/auth/authorization接口）开始：

{% img /images/blog/2018-12-30_5.gif 'image' %}

## CSRF
[跨站请求伪造(Cross-site request forgery)](http://en.wikipedia.org/wiki/Cross-site_request_forgery)， 简称为 CSRF，是 Web 应用中常见的一个安全问题。前面的链接也详细讲述了 CSRF 攻击的实现方式。

当前防范 CSRF 的一种通用的方法，是对每一个用户都记录一个无法预知的 cookie 数据，然后要求所有提交的请求（POST/PUT/DELETE）中都必须带有这个 cookie 数据。如果此数据不匹配 ，那么这个请求就可能是被伪造的。

我们这里防范CSRF的方法就是通过在用户第一次点击分享时（调用/linkedin/auth/authorization）在Session中存储一个字符串：

```go
func (c *AuthorizationController) Get() {
	...
	c.SetSession("_csrf_Token", state)
	...
}

```

当用户浏览器拿到用户的授权凭证code之后发送给我的应用时（调用/linkedin/auth/callback）检测此时请求中的state与之前在Session中存储的字符串是否相同。

```go

func (c *CallbackController) Get() {
	...
	csrfToken := c.GetSession("_csrf_Token")
	if csrfToken != c.GetString("state") {
		c.Data["json"] = map[string]interface{}{"error": "xsrf error"}
		c.ServeJSON()
		return
	}
	...
}
```

如果相同则能判断是用户的请求，如果不同，则可能是用户点击了其他用户伪造的一个链接发送的请求，从而可以防止code被发送到恶意网站上去

## 本文资源
代码及部分图片工程文件：https://github.com/xbox1994/OAuth2-LinkedIn.git

## 参考
https://zh.wikipedia.org/wiki/%E5%BC%80%E6%94%BE%E6%8E%88%E6%9D%83  
http://www.ruanyifeng.com/blog/2014/05/oauth_2_0.html  
https://developer.linkedin.com/docs/share-on-linkedin  
https://zhuanlan.zhihu.com/p/20913727  
https://www.cnblogs.com/flashsun/p/7424071.html  
https://beego.me/docs/mvc/controller/xsrf.md  
