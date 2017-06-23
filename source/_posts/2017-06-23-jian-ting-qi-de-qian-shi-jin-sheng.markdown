---
layout: post
title: "监听器的前世今生"
date: 2017-06-23 16:34:13 +0800
comments: true
categories: Spring
---
对不起我的文章中没有粗体或者高亮，只有格式的不同，因为格式已经足够明显提醒你了并且每句话都是不是废话。

<!--more-->
#世界上最早的监听器不是Servlet中的
其实这篇文章有一半与主题无关。请原谅我当了一次标题党。万恶的标题党，我自己都难以根据题目了解文章内容了。

对于大部分Java开发者来说，第一次听说监听器这个翻译过来的词汇的时候是在学习Servlet的时候听说的，还记得当年用HttpSessionListener统计在线人数，用ServletRequestListener来统计网站的访问量和初始化数据库的操作吗？

但是讲道理，监听器这个概念在很久之前就被提出来了。

> 世界上最早的窃听器是中国在2000 年前发明的。战国时代的《墨子》一 书就记载了一种 “听瓮”。这种“听瓮”是用陶制成的，大肚小口，把它埋在地下，并在瓮口蒙上一层薄薄的皮革，人伏在上面就可以倾听到城外方圆数十里的动静。到了唐代，又出现了一种 “地听”器。它是用精瓷烧制而成，形状犹如一个空心的葫芦枕头，人睡卧休息时，侧头贴耳枕在上面，就能清晰地听到30里外的马蹄声。
>
> -- 百度百科

比百科通俗易懂的解释更甚，当没有使用监听器时，战马在三十里开外向你奔来你是根本毫无察觉的，但如果不在Servlet中注册监听器，你就很难随心所欲地监控请求流或服务器的某些状态。言归正传，下面通过分析Spring中的监听器来了解一下监听器在大神的脑海中是什么样的。

#Spring中的监听器
网上关于ApplicationListener的使用教程多如繁星，但根据源码分析调度过程与监听器的使用艺术屈指可数。虽然我们在开发的时候只需要知道监听什么事件使用什么监听器就好了，但是有程序员的强迫症的话还是想看看原理的。

##源码中的原始用法
要使用Spring中监听器的功能，需要实现ApplicationListener，具体如何实现请自行百度。源码中Rod对这个接口讲解的很清楚，根据观察者模式实现，在3.0中监听器可以声明感兴趣的事件等等。

```

/**
 * Interface to be implemented by application event listeners.
 * Based on the standard {@code java.util.EventListener} interface
 * for the Observer design pattern.
 *
 * <p>As of Spring 3.0, an ApplicationListener can generically declare the event type
 * that it is interested in. When registered with a Spring ApplicationContext, events
 * will be filtered accordingly, with the listener getting invoked for matching event
 * objects only.
 *
 * @author Rod Johnson
 * @author Juergen Hoeller
 * @param <E> the specific ApplicationEvent subclass to listen to
 * @see org.springframework.context.event.ApplicationEventMulticaster
 */
public interface ApplicationListener<E extends ApplicationEvent> extends EventListener {

	/**
	 * Handle an application event.
	 * @param event the event to respond to
	 */
	void onApplicationEvent(E event);

}
```

对于我来说从头跟到尾才能把思路理清楚，在Spring boot中，我们使用SpringApplication.run方法去启动应用，那么从这个方法入手可以跟踪监听器是如何被注册以及被调用的。

下面的代码位于SimpleApplicationEventMulticaster，在这个方法执行前，我们加上了@Component的监听器会被Spring框架读取并添加到监听器的集合中，在这个方法里会将每个之前注册过的每个监听器都开启一条线程，通知所有注册了此event的监听器执行方法。

```
public void multicastEvent(final ApplicationEvent event, ResolvableType eventType) {
		ResolvableType type = (eventType != null ? eventType : resolveDefaultEventType(event));
		for (final ApplicationListener<?> listener : getApplicationListeners(event, type)) {
			Executor executor = getTaskExecutor();
			if (executor != null) {
				executor.execute(new Runnable() {
					@Override
					public void run() {
						invokeListener(listener, event);
					}
				});
			}
			else {
				invokeListener(listener, event);
			}
		}
	}
```

在使用SpringApplication.run时，会调用multicastEvent(new ApplicationStartedEvent())方法调用所有注册了ApplicationStartedEvent的监听器，还有其他官方提供的监听事件可从[Spring官方文档](https://docs.spring.io/spring/docs/current/spring-framework-reference/htmlsingle/#context-functionality-events)找到。

##结合JPA
还有一种结合JPA使用的监听器，通过在JPA实体中注册一个JPA监听器，然后在该监听器中publish事件给Spring框架，最后让Spring将该事件广播给所有注册过该事件的监听器。无图无XX，请叫我灵魂画师。

{% img /images/blog/2017-06-23_2.png 'image' %}

实体类TodoTask：

```
@Entity
@Table(name = "todo_task")
@EntityListeners({TodoTaskEntityListener.class})
```

JPA监听器TodoTaskEntityListener：

```
@Configurable
public class TodoTaskEntityListener {

    @PostPersist
    public void onPostPersist(TodoTask task) {
        logger.info("publish todo task created event");
        EventPublisher.publish(new TodoTaskCreatedEvent(task));
    }
}

```

事件监听器TodoTaskCreatedEventListener：

```
@Component
public class TodoTaskDoneEventListener implements ApplicationListener<TodoTaskDoneEvent> {
    @Autowired
    TodoTaskRepository todoTaskRepository;

    @Override
    public void onApplicationEvent(TodoTaskDoneEvent event) {
        logger.info("activity request successful, {}", activity);
        todoTaskRepository.save(task);
	}
}
```
之后，就可以使用EventPublisher.publish(new Event())来发布自定义的事件，用在数据库的增删改查前后的操作比较方便。

###使用场景
JPA监听器的使用场景与Spring应用监听器的使用场景有一定差异。首先我们要明确JPA监听器的意义，JPA是针对数据模型的监听，当数据模型被修改的时候可以触发，具体参见[这里](https://docs.jboss.org/hibernate/orm/4.0/hem/en-US/html/listeners.html)。Spring应用监听器是对于框架内部流程与自定义事件的监听。

所以，可以把JPA监听器看作持久层之内，但区别于数据模型的一层。

使用场景：

* 很多情况下，数据库中的数据和真实想要使用的数据不同，可以把数据清洗、包装
* 复用，对于会被多处调用的部分起到了复用的功能
* 性能，数据模型的前置或后置操作，比如插入与数据模型没有强依赖次序的新记录到数据库、通知其他服务本地已完成，此时是异步操作

对于前两条，当然你也可以使用AOP或者直接调用相应方法提供，但是此时意义有些许不同，区别在于对数据模型的某个具体持久化事件的监听还是对切面的监听，粒度区别较大。

##与观察者模式的关系
我们自己实现的监听器或者Spring框架自带的监听器再结合Spring对于监听的框架，是一个非常典型的观察者模式的实现，如下图。

{% img /images/blog/2017-06-23_1.png 'image' %}

* 被观察对象（Spring框架内部流程或者自定义流程）：提供addObserver()允许观察者注册。通过在事件发生时调用notifyObserves()来通知观察者。在Spring中，发送广播事件的SimpleApplicationEventMulticaster中包含的defaultRetriever.applicationListeners集合，是在Spring框架启动时已经注册了监听器的集合。
* 观察者（监听器）：实现观察者会触发的方法，等待被注册与调用。
* 三方：初始化观察者、注册观察者到被观察对象中的集合。

##为什么要使用监听器
最后强调一下，是否监听器满足你的需求，千万不要为了装逼而使用复杂高级的组件。

> 你到一个商店买东西，刚好你要的东西没有货，于是你在店员那里留下了你的电话，过了几天店里有货了，店员就打了你的电话，然后你接到电话后就到店里去取了货。
>
> -- [https://www.zhihu.com/question/19801131](https://www.zhihu.com/question/19801131)

当我们不想干预某件事的发生，而是想获得这个事件发生的详细信息利于我们下一步的行动，这时需要使用到监听器。

##注
以上只是个人总结以及个人理解，如有偏差，欢迎指正。