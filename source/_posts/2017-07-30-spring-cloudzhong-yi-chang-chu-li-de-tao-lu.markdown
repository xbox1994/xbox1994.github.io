---
layout: post
title: "Spring Cloud中异常处理的套路"
date: 2017-07-30 01:55:36 +0800
comments: true
categories: 后台
---
异常在Java中有两种分类：Error（OutOfMemoryError之类的我们自己程序无法处理的非常严重的错误，Java推荐不catch，让程序随之崩溃）、Excepiton（NullPointerException之类的并不致命的错误，Java觉得indicates conditions that a reasonable application might want to catch，推荐catch），本文以下内容涉及到的都是Exception。

本文会结合REST API与Spring的一些具体实践来探讨一下异常处理的套路。
<!--more-->
#异常与异常处理机制的意义
关于异常是拿来干什么的，很多人老程序员认为就是拿来我们Debug的时候排错的，当然这一点确实是异常机制非常大的一个好处，但异常机制包含着更多的意义。

* **关注业务实现**。异常机制使得业务代码与异常处理代码可以分开，你可以将一些你调用数据库操作的代码写在一个方法里而只需要在方法上加上throw DB相关的异常。至于如何处理它，你可以在调用该方法的时候处理或者甚至选择不处理，而不是直接在该方法内部添加上if判断如果数据库操作错误该如何办，这样业务代码会非常混乱。
* **统一异常处理**。与上一点有所联系。我当前所在项目的实践是，自定义业务类异常，在Controller或Service中抛出，让后使用Spring提供的异常接口统一处理我们自己在内部抛出的异常。这样一个异常处理架构就非常明了。
* **程序的健壮性**。如果没有异常机制，那么来了个对空对象的某方法调用怎么办呢？直接让程序挂掉？这令人无法接受，当然，我们自己平时写的一些小的东西确实是这样，没有处理它，让后程序挂了。但在web框架中，可以利用异常处理机制捕获该异常并将错误信息传递给我们然后继续处理下个请求。所以异常对于健壮性是非常有帮助的。

> 异常处理（又称为错误处理）功能提供了处理程序运行时出现的任何意外或异常情况的方法。异常处理使用 try、catch 和 finally 关键字来尝试可能未成功的操作，处理失败，以及在事后清理资源。

#先分类(dian cai)吧
我把异常根据意义成三种：业务、系统、代码异常，不同的异常采用不同的处理方式。
##业务异常
```java
@GetMapping("/{id}")
public ReservationDetail getDetail(@PathVariable String id) {
    ReservationDetail result = applicationService.getReservationDetail(id);
    if (result == null) {
        throw new InfoNotFoundExcepiton("reservation with id=" + id + " is not exist");
    }

    return result;
}
```
以上代码当没有查到数据的时候抛出一个InfoNotFoundExcepiton异常，查询一个信息但不存在，没有任何系统级别的错误发生，而是数据确实不存在，此时属于业务异常。这个例子比较局限，其他的场景可能有一个用户想访问某个API，但是没有权限，此时可以返回无权限的业务异常。

将所有业务异常抛出，并通过Spring提供的接口进行统一处理，要注意的是，返回码也是需要分别标示的，对于意义不同的业务异常，对应的错误返回码也是需要被指定的：

```java
@RestControllerAdvice
public class ControllerAdvice {

    private static final Logger logger = LoggerFactory.getLogger(ControllerAdvice.class);

    @ExceptionHandler(Throwable.class)
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    public ErrorResult handleOtherException(Throwable e) {
        RestControllerAdvice
        return new ErrorResult(ErrorCode.UNKNOWN, e.getMessage());
    }

    @ExceptionHandler(ResourceAccessException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public ErrorResult handleResourceNotFoundException(ResourceAccessException e) {
        logger.error(e.getMessage(), e);
        return new ErrorResult(ErrorCode.RESOURCE_NOT_FOUND, e.getMessage());
    }

}

```
这种异常处理方式个人认为在我们代码中越多越好，如果能在代码中涵盖业务中的很多边界值，对于整体应用的**健壮性**提升有着非常大的帮助，并且对于前端来说，前端可以根据此异常信息给予用户更加明确**友好的错误提示**：

```
携带错误码为500的错误请求：
{
    "message": "cannot find pre inspection base info by order id: 1",
    "error_code": "SERVICE_REQUEST_ERROR"
}
```

##系统异常
这种异常在调试时非常常见，要么是某个服务挂掉了，或者超时这样的情况，跟业务没有关系，也不是代码中的BUG导致的，这个时候我们必须设计好一个预案去cover这种风险。

在微服务架构中，这种情况时有发生，如在我翻译过的[这篇文章](http://www.wangtianyi.top/blog/2017/05/05/gou-jian-wei-fu-wu-wei-fu-wu-jia-gou-zhong-de-jin-cheng-jian-tong-xin/)中提到的，使用Netflix Hystrix解决，在Spring Cloud中已经携带该模块。具体如下：

* 网络超时 - 不会无限期等待并使用超时策略。这可以确定资源不会被无限期被捆绑在一起
* 限制未完成的请求的数量 - 对于客户端可以使用特定服务的未完成请求数量强加一个上限。如果到达限制，提出额外的请求可能没有意义，这些尝试需要立即失败。
* 使用断路器模式 - 跟踪成功和失败的数量。如果错误率超过预定的阈值，断路器跳闸，以便以后的尝试失败。如果很多请求失败，建议服务设为不可用，发请求也是没有意义的。但超时之后，客户端应该再次尝试，如果成功，关闭断路器。
* 提供备用逻辑 - 当请求失败后执行备用逻辑。比如返回缓存数据或者默认值比如空的推荐。

**那么问题来了，这些异常可以与其他异常分类统一格式返回给前端吗？**

```java
@ExceptionHandler(Throwable.class)
```
这行代码捕捉了所有的异常，包括Error级别的，这是根据特定项目需求来确定的，所以即使是Error也需要记录下来，出错之后方便错误的排查。
##代码异常
我把代码中存在的BUG叫做代码异常，与系统异常不同的是，这种异常只能尽量避免与预防。比如程序员没有考虑到的情况导致空指针异常、SQL语句编写错误导致SQLException。在线上环境是非常严重的错误，需要立马开hotfix分支去修的，因为没有编写对应的业务处理方式，最严重的后果可能导致某个用户扣了钱但是没有显示支付成功。

和系统异常一样，这些异常由于是Throwable异常类下的异常，所以会被返回给前端。
#异常处理流程与规范
异常处理流程在微服务架构中可能会比直接向前端发送异常信息这个过程麻烦一些，如Service向BFF层级传递异常一级。
##异常在服务之间的传递
API Gateway (with Zuul) => BFF => 某服务

由于BFF与服务之间是通过Feign连接，所以我们需要自己统一一下错误格式成为业务相关的格式返回给前端而不是直接将细化某个Java异常类的全部异常信息交给前端。

{% img /images/blog/2017-07-30.png 'image' %}

在这张图中，在BFF中检测参数是否匹配，在Service中检测是否资源存在，如果在BFF中抛出异常，则将INVALID_PARAMETER异常返回给前端，如果在Service中抛出异常，则将SERVICE_REQUEST_ERROR返回给前端。也就是将异常做出简单的分类：业务异常、非业务异常，非业务异常中可以像上面分类一样继续分类。
##约定返回格式
前后端统一错误格式，需要规定如下：

* 返回格式：JSON
* 返回请求状态码：根据不同请求对应的状态码意义返回
* 返回具体格式如下

```
{
   "message": "reservation details doesn't exist with id: xxx",
   "errorCode": "SERVICE_REQUEST_ERROR",
}
```

## 号外号外
最近在总结一些针对**Java**面试相关的知识点，感兴趣的朋友可以一起维护~  
地址：[https://github.com/xbox1994/2018-Java-Interview](https://github.com/xbox1994/2018-Java-Interview)
