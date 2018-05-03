---
layout: post
title: "Java多线程与高并发(一):并发基础与模拟工具"
date: 2018-04-28 11:09:20 +0800
comments: true
categories: 后台
---

面试官：你知道Java的内存模型是什么吗？

<!-- more -->

# 基本概念
## 并发、并行

引用知乎上一个最高赞：

> 你吃饭吃到一半，电话来了，你一直到吃完了以后才去接，这就说明你不支持并发也不支持并行。

> 你吃饭吃到一半，电话来了，你停了下来接了电话，接完后继续吃饭，这说明你支持并发。

> 你吃饭吃到一半，电话来了，你一边打电话一边吃饭，这说明你支持并行。

> 并发的关键是你有处理多个任务的能力，不一定要同时。并行的关键是你有同时处理多个任务的能力。

**并发：系统能处理多个任务，但同时只能处理一个的任务处理机制**

**并行：系统能处理多个任务，且同时还能处理多个的任务处理机制**

**高并发：系统能同时并行处理很多请求的任务处理机制**

# 并发基础

这个PDF讲解的是Java线程基础，如果比较熟悉，可以跳过

<embed src="/pdf/2018-04-28_1.pdf" width="100%" height="300px">

## Java内存模型
主内存：所有变量都保存在主内存中  
工作内存：每个线程的独立内存，保存了该线程使用到的变量的主内存副本拷贝，线程对变量的操作必须在工作内存中进行。

{% img /images/blog/2018-04-28_2.jpg 'image' %}

每个线程都有自己的本地内存共享副本，如果A线程要更新主内存还要让B线程获取更新后的变量，那么需要：

1. 将本地内存A中更新共享变量
2. 将更新的共享变量刷新到主内存中
3. 线程B从主内存更新最新的共享变量

如果A、B线程同时处理某共享变量，会导致重复计数或者数据冲突。

## 乱序执行优化
在硬件架构上，处理器为提高运算速度而做的违背代码顺序的优化。执行的方式是将多条指令不按程序顺序发送给不同的多个电路单元，达到更大的CPU利用率。

在单CPU上不会出现问题，在多CPU访问同一块内存的时候可能会出现访问顺序的问题，如下。

### 例子

```
public class PossibleReordering {
    private static int x = 0, y = 0;
    private static int a = 0, b = 0;

    public static void main(String[] args) throws InterruptedException {
        int i = 0;
        for (; ; ) {
            i++;
            x = 0;
            y = 0;
            a = 0;
            b = 0;
            Thread one = new Thread(() -> {
                //由于线程one先启动，下面这句话让它等一等线程two. 读着可根据自己电脑的实际性能适当调整等待时间.
                shortWait(50000);
                a = 1;
                x = b;
            });

            Thread other = new Thread(() -> {
                b = 1;
                y = a;
            });
            one.start();
            other.start();
            one.join();
            other.join();
            String result = "第" + i + "次 (" + x + "," + y + "）";
            if (x == 0 && y == 0) {
                System.err.println(result);
                break;
            } else {
                System.out.println(result);
            }
        }
    }


    public static void shortWait(long interval) {
        long start = System.nanoTime();
        long end;
        do {
            end = System.nanoTime();
        } while (start + interval >= end);
    }
}
```

很容易想到这段代码的运行结果可能为(1,0)、(0,1)或(1,1)，因为线程one可以在线程two开始之前就执行完了，也有可能反之，甚至有可能二者的指令是同时或交替执行的。

然而，这段代码的执行结果也可能是(0,0)。代码指令可能并不是严格按照代码语句顺序执行的。a=1和x=b这两个语句的赋值操作的顺序可能被颠倒，或者说，发生了指令“重排序”(reordering)。（事实上，输出了这一结果，并不代表一定发生了指令重排序，内存可见性问题也会导致这样的输出）

除了处理器，常见的Java运行时环境的JIT编译器也会做指令重排序操作，即生成的机器指令与字节码指令顺序不一致。

### 内存屏障
那么解决以上问题的方式就是加上内存屏障，就是把所有共享的变量设置为`volatile`。

内存屏障能禁止重排序的时候将后面的指令排到前面去，且保证变量的可见性。强烈建议读者自己操作一遍加深理解。

## 并发的优缺点
优点：

1. 速度：同时处理多个请求响应更快
2. 设计：程序设计有更多的选择，可能更简单，比如对文件集的读取与处理，单线程需要写个循环去做，多线程可以只写一个文件的操作但用到并发去限制，同时也提高了CPU利用率。
3. 资源利用：如2

----------

缺点：

1. 安全性：多个线程共享变量会存在问题
2. 活跃性：死锁
3. 性能：多线程导致CPU切换开销太大、消耗过多内存

## 并发模拟工具
现在我们需要准备一个并发模拟工具，方便测试将来的代码是否线程安全
### JMeter、PostMan
待补充

### 代码模拟
我们将使用JUC的工具类来完成代码模拟并发的场景
#### CountDownLatch
{% img /images/blog/2018-04-28_3.png 'image' %}

计数器闭锁是一个能阻塞主线程，让其他线程满足特定条件下再继续执行的工具。比如倒计时5000，每当一个线程完成一次操作就让它执行countDown一次，直到count为0之后输出结果，这样就保证了其他线程一定是满足了特定条件（执行某操作5000次），模拟了并发执行次数。

#### Semaphore
信号量是一个能阻塞线程且能控制统一时间请求的并发量的工具。比如能保证同时执行的线程最多200个，模拟出稳定的并发量。深入了解请参看第四篇文章。

#### 模拟工具
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