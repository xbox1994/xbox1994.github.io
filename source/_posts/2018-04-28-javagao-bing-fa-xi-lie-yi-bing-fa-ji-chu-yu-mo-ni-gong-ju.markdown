---
layout: post
title: "Java多线程与高并发(一):并发基础与模拟工具"
date: 2018-04-28 11:09:20 +0800
comments: true
categories: 后台
---

<!-- more -->

# 基本概念
## 并发

引用知乎上一个最高赞：

> 你吃饭吃到一半，电话来了，你一直到吃完了以后才去接，这就说明你不支持并发也不支持并行。

> 你吃饭吃到一半，电话来了，你停了下来接了电话，接完后继续吃饭，这说明你支持并发。

> 你吃饭吃到一半，电话来了，你一边打电话一边吃饭，这说明你支持并行。

> 并发的关键是你有处理多个任务的能力，不一定要同时。并行的关键是你有同时处理多个任务的能力。

**并发：系统能处理多个任务，但同时只能处理一个的任务处理机制**

**并行：系统能处理多个任务，且同时还能处理多个的任务处理机制**

**高并发：系统能同时并行处理很多请求的任务处理机制**

# 并发基础
## CPU缓存
CPU的计算速度太快，但内存的传输太慢，所以引入CPU多级高速缓存，将一部分经常访问的数据放到缓存中，从而间接提高整体处理速度。

使用二级缓存或多级缓存是因为一级缓存太贵，所以次级缓存更大更便宜。

{% img /images/blog/2018-04-28_1.jpg 'image' %}

## 意义
局部性原理：CPU访问存储器时，无论是存取指令还是存取数据，所访问的存储单元都趋于聚集在一个较小的连续区域中。如果某个数据被访问，那么它以及它相邻的数据很可能被再次在近期被访问。

## 乱序执行优化
在硬件架构上，处理器为提高运算速度而做的违背代码顺序的优化。执行的方式是将多条指令不按程序顺序发送给不同的多个电路单元，达到更大的CPU利用率。

在单CPU上不会出现问题，在多CPU访问同一块内存的时候可能会出现访问顺序的问题，如下。

### 例子

```
public class SingletonDemo {
    private volatile static SingletonDemo instance;

    private SingletonDemo() {
        System.out.println("Singleton has loaded");
    }

    public static SingletonDemo getInstance() {
        if (instance == null) {
            synchronized (SingletonDemo.class) {
                if (instance == null) {
                    instance = new SingletonDemo();
                }
            }
        }
        return instance;
    }
}
```

熟悉单例模式的同学应该比较熟悉，这里如果不把instance变量设置成为volatile的话就会出现BUG，原因是因为指令重排序导致的，当执行`instance = new SingletonDemo();`这行时，一共有三个步骤：

1. 给SingletonDemo的实例分配内存
2. 执行SingletonDemo的构造器
3. 将实例的引用复制给instance变量

由于指令重排序，可能会导致将步骤3与2颠倒，导致另外一个线程得到的一个还没有初始化的单例。

### 内存屏障
那么解决以上问题的方式就是加上内存屏障，内存屏障能禁止重排序的时候将后面的指令排到前面去，单个CPU访问内存时不需要。在汇编中是加入了`lock xxx`代码完成。

## Java内存模型
主内存：所有变量都保存在主内存中  
工作内存：每个线程的独立内存，保存了该线程使用到的变量的主内存副本拷贝，线程对变量的操作必须在工作内存中进行。

{% img /images/blog/2018-04-28_2.jpg 'image' %}

每个线程都有自己的本地内存共享副本，如果A线程要更新主内存还要让B线程获取更新后的变量，那么需要：

1. 将本地内存A中更新共享变量
2. 将更新的共享变量刷新到主内存中
3. 线程B从主内存更新最新的共享变量

如果A、B线程同时处理某共享变量，会导致重复计数或者数据冲突。

## 优缺点
1. 速度：同时处理多个请求响应更快
2. 设计：程序设计有更多的选择，可能更简单，比如对文件集的读取与处理，单线程需要写个循环去做，多线程可以只写一个文件的操作但用到并发去限制，同时也提高了CPU利用率。
3. 资源利用：如2

----------

1. 安全性：多个线程共享变量会存在问题
2. 活跃性：死锁
3. 性能：多线程导致CPU切换开销太大、消耗过多内存

## 并发模拟工具
### JMeter、PostMan
待补充

### 代码模拟
我们将使用JUC的工具类来完成代码模拟并发的场景
#### CountDownLatch
{% img /images/blog/2018-04-28_3.png 'image' %}

计数器闭锁是一个能阻塞主线程，让其他线程满足特定条件下再继续执行的工具。比如倒计时5000，每当一个线程完成一次操作就让它执行countDown一次，直到count为0之后输出结果，这样就保证了其他线程一定是满足了特定条件（执行某操作5000次），模拟了并发执行次数。

#### Semaphore
信号量是一个能阻塞线程且能控制统一时间请求的并发量的工具。比如能保证同时执行的线程最多200个，模拟出稳定的并发量。

```
public class ConcurrencyTest {
    private static final int THREAD_COUNT = 5000;
    private static final int CONCURRENT_COUNT = 200;
    private static int count = 0;
    public static void main(String[] args) throws InterruptedException {
        ExecutorService executorService = Executors.newCachedThreadPool();
        Semaphore semaphore = new Semaphore(CONCURRENT_COUNT);
        CountDownLatch countDownLatch = new CountDownLatch(THREAD_COUNT);
        for (int i = 0; i < THREAD_COUNT; i++) {
            executorService.execute(() -> {
                try {
                    semaphore.acquire();
                    add();
                    semaphore.release();
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
                countDownLatch.countDown();
            });
        }
        countDownLatch.await();
        executorService.shutdown();
        System.out.println(count);
    }

    private static void add(){
        count++;
    }
}
```

执行结果可能是5000可能小于5000。从而证明add方法的写法是线程不安全的写法。