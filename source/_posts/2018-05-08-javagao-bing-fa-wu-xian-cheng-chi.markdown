---
layout: post
title: "Java多线程与高并发(五):线程池"
date: 2018-05-08 08:37:16 +0800
comments: true
categories: 后台
---

<!-- more-->

# new Thread弊端
* 每次启动线程都需要new Thread新建对象与线程，性能差。线程池能重用存在的线程，减少对象创建、回收的开销。
* 线程缺乏统一管理，可以无限制的新建线程，导致OOM。线程池可以控制可以创建、执行的最大并发线程数。
* 缺少工程实践的一些高级的功能如定期执行、线程中断。线程池提供定期执行、并发数控制功能

# ThreadPoolExecutor
## 核心变量
在创建线程池时需要传入的参数
```
public static ExecutorService newFixedThreadPool(int nThreads, ThreadFactory threadFactory) {
return new ThreadPoolExecutor(nThreads, nThreads,
                              0L, TimeUnit.MILLISECONDS,
                              new LinkedBlockingQueue<Runnable>(),
                              threadFactory);
}
```

* corePoolSize：核心线程数量，线程池中应该常驻的线程数量
* maximumPoolSize：线程池允许的最大线程数，非核心线程在超时之后会被清除
* workQueue：阻塞队列，存储等待执行的任务
* keepAliveTime：线程没有任务执行时可以保持的时间
* unit：时间单位
* threadFactory：线程工厂，来创建线程
* rejectHandler：当拒绝任务提交时的策略（抛异常、用调用者所在的线程执行任务、丢弃队列中第一个任务执行当前任务、直接丢弃任务）

## 创建线程的逻辑
以下任务提交逻辑来自ThreadPoolExecutor.execute方法：  

1. 如果运行的线程数 < corePoolSize，直接创建新线程，即使有其他线程是空闲的
2. 如果运行的线程数 >= corePoolSize  
    2.1 如果插入队列成功，则完成本次任务提交  
    2.2 如果插入队列失败  
            2.2.1 如果当前线程数 < maximumPoolSize，创建新的线程放到线程池中  
            2.2.2 如果当前线程数 >= maximumPoolSize，会执行指定的拒绝策略

## [阻塞队列的策略](https://blog.csdn.net/hayre/article/details/53291712)
* 直接提交。工作队列的默认选项是SynchronousQueue，它将任务直接提交给线程而不保持它们。在此，如果不存在可用于立即运行任务的线程，则试图把任务加入队列将失败，因此会构造一个新的线程。此策略可以避免在处理可能具有内部依赖性的请求集时出现锁。直接提交通常要求无界maximumPoolSizes 以避免拒绝新提交的任务。当命令以超过队列所能处理的平均数连续到达时，此策略允许无界线程具有增长的可能性。
* 无界队列。使用无界队列（例如，不具有预定义容量的 LinkedBlockingQueue）将导致在所有 corePoolSize线程都忙时新任务在队列中等待。这样，创建的线程就不会超过 corePoolSize。（因此，maximumPoolSize的值也就无效了。）当每个任务完全独立于其他任务，即任务执行互不影响时，适合于使用无界队列；例如，在 Web页服务器中。这种排队可用于处理瞬态突发请求，当命令以超过队列所能处理的平均数连续到达时，此策略允许无界线程具有增长的可能性。
* 有界队列。当使用有限的 maximumPoolSizes 时，有界队列（如ArrayBlockingQueue）有助于防止资源耗尽，但是可能较难调整和控制。队列大小和最大池大小可能需要相互折衷：使用大型队列和小型池可以最大限度地降低CPU 使用率、操作系统资源和上下文切换开销，但是可能导致人工降低吞吐量。如果任务频繁阻塞（例如，如果它们是 I/O边界），则系统可能为超过您许可的更多线程安排时间。使用小型队列通常要求较大的池大小，CPU使用率较高，但是可能遇到不可接受的调度开销，这样也会降低吞吐量。

## 关键方法
* execute：提交任务
* submit：提交任务，能够得到执行结果
* shutdown：等待任务执行完再关闭线程池
* shutdownNow：不等待直接关闭线程池

# 常用工具
Executors是一个工具类，能快速创建实用的线程池，但是返回的ExecuteService接口缺少很多ThreadPoolExecutor的方法需要注意

## Executors.newCachedThreadPool()
corePoolSize为0，maximumPoolSize为整数最大值，keepAliveTime为60秒，队列为SynchronousQueue

创建一个可缓存线程池，如果线程池长度超过处理需要，可灵活回收空闲线程，若无可回收，则新建线程。

## Executors.newFixedThreadPool()
corePoolSize，maximumPoolSize自定义，keepAliveTime为0秒，队列为LinkedBlockingQueue

创建一个定长线程池，可控制线程最大并发数，超出的线程会在队列中等待。

## Executors.newScheduledThreadPool()
corePoolSize自定义，maximumPoolSize为整数最大值，keepAliveTime为0秒，队列为DelayedWorkQueue

创建一个定长线程池，支持定时及周期性任务执行。

## Executors.newSingleThreadScheduledExecutor()
corePoolSize为1的ScheduledThreadPool

创建一个单线程化的线程池，它只会用唯一的工作线程来执行任务，保证所有任务按照指定顺序(FIFO, LIFO, 优先级)执行

# 例子
```
public class ThreadPoolTest {
    public static void main(String[] args) {
        ExecutorService executorService = Executors.newCachedThreadPool();
        for (int i = 0; i < 10; i++) {
            int finalI = i;
            executorService.execute(() -> System.out.println(finalI));
        }
        executorService.shutdown();
    }
}
```

以上代码将非顺序输出0~9，类似于fixed，但single的将顺序输出0~9

```
public class ThreadPoolTest {
    public static void main(String[] args) {
        ScheduledExecutorService executorService = Executors.newScheduledThreadPool(3);
//        executorService.schedule(() -> System.out.println("hehe"), 1, TimeUnit.SECONDS);
        executorService.scheduleAtFixedRate(() -> System.out.println("hehe"), 1, 2, TimeUnit.SECONDS);
//        executorService.shutdown();
    }
}
```

以上代码是newScheduledThreadPool的典型使用方式，将按照计划的方式来执行任务

# 配置线程池的建议
* CPU密集型任务：CPU数 + 1
* IO密集型任务：CPU数 * 2

先将线程池大小设置为参考值，再观察任务运行情况和系统负载、资源利用率来进行适当调整。