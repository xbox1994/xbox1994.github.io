---
layout: post
title: "Java多线程与高并发(二):线程安全性"
date: 2018-04-28 23:59:31 +0800
comments: true
categories: 后台
---

面试官：你能说说什么是线程安全吗？

<!-- more -->

# 线程安全性
当多个线程访问某个类时，不管运行时环境采用**何种调度方式**或者**这些线程将如何交替执行**，并且在调用代码中**不需要任何额外的同步**，这个类都**能表现出正确的行为**，那么这个类就是线程安全的。

* 原子性：同一时刻只能有一个线程对它操作
* 可见性：一个线程对内存的修改能让其他线程观察到
* 有序性：指令执行顺序，杂乱无序

# 原子性
## Atomic包
### AtomicInteger
AtomicInteger中的incrementAndGet方法就是乐观锁的一个实现，使用自旋（循环检测更新）的方式来更新内存中的值并通过底层CPU执行来保证是更新操作是原子操作。方法如下：

```
public final int getAndAddInt(Object var1, long var2, int var4) {
    int var5;
    do {
        var5 = this.getIntVolatile(var1, var2);
    } while(!this.compareAndSwapInt(var1, var2, var5, var5 + var4)); 
    			//compareAndSwapInt(obj, offset, expect, update)

    return var5;
}
```

首先这个方法通过getIntVolatile方法，使用**对象的引用与值的偏移量得到当前值**，然后调用compareAndSwapInt检测如果obj内的value和expect相等，就证明没有其他线程改变过这个变量，那么就更新它为update，如果这一步的CAS没有成功，那就采用**自旋**的方式继续进行CAS操作。

在赋值的时候保证原子操作的原理是通过CPU的cmpxchgl与lock指令的支持来实现AtomicInteger的CAS操作的原子性，具体可参考这里，https://juejin.im/post/5a73cbbff265da4e807783f5

疑问：这个方法是先得到值，再更新值，所以必须保证更新的值是在原来的基础上更新的，所以采用CAS进行更新，那么为什么不使用直接更新值然后返回值的方式来做呢？因为更新值的前提是获取值，这是两部汇编级别的操作，仅仅更新值是无法获取到值的。

### ABA问题
如果一个值原来是A，变成了B，又变成了A，那么使用CAS进行检查时会发现它的值没有发生变化，但是实际上却变化了。这就是CAS的ABA问题。

常见的解决思路是使用版本号。在变量前面追加上版本号，每次变量更新的时候把版本号加一，那么A-B-A 就会变成1A-2B-3A。

AtomicStampedReference来解决ABA问题。这个类的compareAndSet方法作用是首先检查当前引用是否等于预期引用，并且当前标志是否等于预期标志，如果全部相等，则以原子方式将该引用和该标志的值设置为给定的更新值。

### 循环时间长开销大问题
上面我们说过如果CAS不成功，则会原地自旋，如果长时间自旋会给CPU带来非常大的执行开销。

##  synchronized
是线程并发控制的关键字，能通过锁来管理多个线程的同时执行该代码块时的执行方式。

*  修饰代码块、方法：作用于调用的对象
*  修饰静态方法、类：作用于类所有对象

可以用以下代码试试

```
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class Main {

    private void test(int test) {
        synchronized (this) {
            for (int i = 0; i < 100; i++) {
                System.out.println(test);
            }
        }
    }

    public static void main(String[] args) {
        Main m1 = new Main();
        Main m2 = new Main();

        ExecutorService executorService = Executors.newCachedThreadPool();
        executorService.execute(() -> m1.test(1));
        executorService.execute(() -> m2.test(2));
        executorService.shutdown();
    }
}
```

## 对比
### synchronized
不可中断  
同步不激烈时，synchronized是很合适的，因为编译程序通常会尽可能的进行优化synchronize  
同步激烈时，synchronized的性能会下降  
编码难度低，可读性非常好

### ReentrantLock
可中断  
同步不激烈时，性能稍微比synchronized差点  
同步激烈时，维持常态  
提供了多样化的同步，比如有时间限制的同步，可以被Interrupt的同步（synchronized的同步是不能Interrupt的）等

### Atomic
同步不激烈时，性能比synchronized差点  
激烈的时候，维持常态，且优于ReentrantLock  
只能同步一个值，一段代码中只能出现一个Atomic的变量，多于一个同步无效

所以，我们写同步的时候，**优先考虑synchronized，如果有特殊需要，再进一步优化**。ReentrantLock和Atomic如果用的不好，不仅不能提高性能，还可能带来灾难。
# 可见性

## 共享变量在线程间不可见的原因
**共享变量更新后的值没有在工作内存与主内存间及时更新**

下面就是解决同步更新的不同方式。

## synchronized

JMM的规范中提供了synchronized具备的**可见性**：

* 线程解锁前，必须把共享变量的最新值刷新到主内存
* 线程加锁时，将清空工作内存中共享变量的值，从主内存中读取最新的值

## volatile

volatile变量具有 synchronized 的**可见性**特性，但是**不具备原子性**

### 内存屏障
内存屏障指令为**CPU指令级别**的操作

* 对声明为volatile的变量进行写操作时，会在写操作后加入一条store屏障指令，将本地内存中的共享变量值刷新到主内存
* 读操作时，会在读操作前加一条load屏障指令，从主内存中读取共享变量

### 防止指令重排序

* 对声明为volatile的变量进行写操作时，会在写之前加上storestore屏障，禁止之前的写操作与本次写操作重排序，在写之后加上storeload屏障，禁止之后的操作与本次写或读操作重排序
* 读，会在读之前加上loadload屏障来禁止下面所有普通读操作和本次读操作重排序，再加上loadstore屏障来禁止下面所有的写操作与本次读操作重排序

### 适用场景
对变量的写操作不依赖当前值。如果依赖当前值，那么两个线程同时执行x++的操作时，因为x++有三步，先获得x的值，然后加一，最后赋值，如果同时获得了x的值，那么就重复累加了。

比如以下就是通过变量的值通知另一个线程要执行相关任务：

```
volatile boolean inited = false;

//线程1
context = new Context();
inited = true;

//线程2
while(!inited){
	sleep(1000);
}
start()
```

# 有序性
JMM中，允许编译器与CPU对指令进行重排序，重排序会影响多线程并发执行的正确性。

## volatile/synchronized/lock来保证

## Happends-Before

* 程序次序规则：一个线程内，按照代码顺序，书写在前面的操作先行发生于书写在后面的操作；
* 锁定规则：一个unLock操作先行发生于后面对同一个锁lock操作；
* volatile变量规则：对一个变量的写操作先行发生于后面对这个变量的读操作；
* 传递规则：如果操作A先行发生于操作B，而操作B又先行发生于操作C，则可以得出操作A先行发生于操作C；
* 线程启动规则：Thread对象的start()方法先行发生于此线程的每个一个动作；
* 线程中断规则：对线程interrupt()方法的调用先行发生于被中断线程的代码检测到中断事件的发生；
* 线程终结规则：线程中所有的操作都先行发生于线程的终止检测，我们可以通过Thread.join()方法结束、Thread.isAlive()的返回值手段检测到线程已经终止执行；
* 对象终结规则：一个对象的初始化完成先行发生于他的finalize()方法的开始；

讲真，这些不要死记，但一定都要理解，并且在看到相关的代码的时候要反映到。