---
layout: post
title: "什么时候能用上设计模式？"
date: 2017-10-08 18:05:56 +0800
comments: true
categories: 后台技术
---
这是原本我觉得在这一生中很难碰到的开发实践。

<!-- more -->

#前言

粗略来说，公认的设计模式有GoF的23种设计，分为创建型、结构型、行为型。在我读大学的时候把其中十几种比较常用的模式总结过一遍，工作一年之后比较惭愧，只记得单例、简单工厂、外观、观察者模式了。

但是，前几天在项目中有一位比较资深的同事，将业务代码使用一种设计模式实现之后，让我感觉死而复生一般对设计模式再一次产生了浓厚的兴趣。

#业务中例子（管道-过滤器模式）

##问题描述
从很多不同的服务中得到了某些资源，需要将这些资源根据某些条件筛选或者拼接出业务逻辑上需要的资源，那么就需要一些处理了，当处理逻辑复杂起来，并且各个处理逻辑之间可能还有特定的联系，写在一个方法或者一个类中就显得这个方法或类职责太过杂乱了。

比如有一个Person类，需要过滤他名字中间的敏感字、对年龄作范围的检测，这些操作之间没有强相关的依赖，顺序可以乱，也可以多一个逻辑少一个逻辑，这就比较像Struts2中拦截器的可插拔的特点了。对于这种场景，为了方便扩展、调整，且不对原来的类进行修改（开闭原则），可以利用到要讲到的管道-过滤器模式。

##设计

{% img /images/blog/2017-10-18.png 'image' %}

代码请见：[这里](https://github.com/xbox1994/DesignPattern/tree/master/src/PipelineFilter)

核心模型：

* Manager：提供注册过滤器的方法，并将注册过的过滤器保存起来；提供开始过滤方法，将context依次传给所有过滤器。
* Context：将需要被过滤的实体以及过滤实体需要的信息保存在一起。
* Filter：过滤器，使用接口实现，必须提供filter方法，也可以增加getPriority方法便于排序。
* Person/Rule：需要被过滤的实体、过滤所需信息。

那么有了这样一套模式，我们可以在代码上清晰很多，一个过滤器类对应一种过滤规则；增加或删除规则只需要自己控制是否注册；调用也非常简单，构造出实体与信息之后交给Manager即可。以后，不管是增加或者删除规则，还是调整过滤的依赖，都非常方便，但缺点是并不是所有过滤器都需要context中传递的所有值。

值得提到的另一点是，Servlet中过滤器、Struts2的拦截器与这种模式有异曲同工之妙，都是将需要被处理的实体一层一层传递下去，不过是使用其他方式实现的，比如递归。其实设计模式是总结出来的一些套路，贯穿不同模式之间的思路才是精髓！

#框架中的例子
##单例+简单工厂模式
单例与工厂模式的一个经典应用场景在于Spring中IoC容器对于Bean的管理。在使用xml方式定义，创建bean的时候，定义如下配置：

```
<bean name="accountDao" class="com.test.dao.impl.AccountDaoImpl"/>
<bean name="accountService" class="com.test.service.impl.AccountServiceImpl">
	<property name="accountDao" ref="accountDao"/>
</bean>
```

然后在AccountServiceImpl中提供set方式就能这样用到Spring帮我们创建的bean了：

```
@Test
public void testByXml() throws Exception {
    ApplicationContext applicationContext=new ClassPathXmlApplicationContext("spring/spring-ioc.xml");

    AccountService accountService= (AccountService) applicationContext.getBean("accountService");
    accountService.doSomething();
}
```

Spring对每个被管理的类默认生成的是单例，并且对每个类都会生成特定的单例工厂对象，然后调用DefaultSingletonBeanRegistry中的double check lock方式得到需要的产品对象。

```
protected Object getSingleton(String beanName, boolean allowEarlyReference) {
		Object singletonObject = this.singletonObjects.get(beanName);
		if (singletonObject == null && isSingletonCurrentlyInCreation(beanName)) {
			synchronized (this.singletonObjects) {
				singletonObject = this.earlySingletonObjects.get(beanName);
				if (singletonObject == null && allowEarlyReference) {
					ObjectFactory<?> singletonFactory = this.singletonFactories.get(beanName);
					if (singletonFactory != null) {
						singletonObject = singletonFactory.getObject();
						this.earlySingletonObjects.put(beanName, singletonObject);
						this.singletonFactories.remove(beanName);
					}
				}
			}
		}
		return (singletonObject != NULL_OBJECT ? singletonObject : null);
	}
```

注意singletonObject = singletonFactory.getObject();这句，singletonFactory在初始化容器的时候已经简简单单一行，就将根据配置或注解寻找符合条件的类的这样一个非常复杂的创建对象的过程完成了（可以跟进去瞧瞧），完全不需要调用者了解其中到底做了什么，这就是简单工厂模式的好处。

其次，对于单例模式，好处则是在web应用中避免多次调用API时重复创建对象、将资源。但需要注意的是，是否需要懒加载以及线程安全则取决于单例模式的实现方式，[这里](https://github.com/xbox1994/DesignPattern/tree/master/src/Singleton)有示例代码。

##代理模式
代理模式提供了一种方式，为某个对象的行为添加其他操作，如日志记录，性能统计，安全控制，事务处理。

![](https://www.ibm.com/developerworks/cn/java/j-lo-spring-principle/image020.png)

在图中，接口类Subject只有一个方法，在编译时无法对它的实现类的对象增添方法，那么在不影响原本类的设计下动态地为它的行为添加其他操作是非常有价值的。

* 降低耦合度
* 使系统容易扩展
* 简化需求实现，提高代码复用性

在Spring中使用JDK动态代理和CGLIB动态代理。JDK动态代理通过反射来接收被代理的类，并且要求被代理的类必须实现一个接口。JDK动态代理的核心是InvocationHandler接口和Proxy类。

第二种方式是选择CGLIB（Code Generation Library），是一个代码生成的类库，可以在运行时动态的生成某个类的子类，注意，CGLIB是通过继承的方式做的动态代理，因此如果某个类被标记为final，那么它是无法使用CGLIB做动态代理的。
#回到标题
那么我们在什么时候才能用上设计模式？上面举了几个设计模式的常见使用例子，个人觉得在下面几种场景下可能需要设计模式。

1. 写给别人看的时候
2. 代码逻辑比较庞杂，理解困难的时候
3. 日后需要经常修改扩展的时候
4. 有一个优秀程序员的追求的时候
5. 写框架的时候

网上有一种观点是：设计模式是从已经写好的代码中提炼出来的，不是在还没写代码的时候设计出来的。
在没有需求没有代码的时候讨论设计模式的好处是完全没有意义的。后半句我非常赞同，但是前半句不敢苟同，设计模式确实是从以前写出来的代码中提炼出来的，但是我已经学习到了一些设计模式，那么在我以后将要但是还没写代码的时候就可以按照需求去使用相应的设计模式去进行代码设计，有何不可呢。