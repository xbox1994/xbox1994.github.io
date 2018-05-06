---
layout: post
title: "Java多线程与高并发(四):java.util.concurrent包"
date: 2018-05-01 11:53:15 +0800
comments: true
categories: 后台
---

面试官：你用过JUC的哪些工具类？

前面从基础开始，到线程安全的实现、对象的发布与共享，涉及到很多线程安全的类与工具，JDK1.5开始，提供了更加方便强大的线程同步管理工具包JUC让我们使用，这个也是面试与实践中的重点，本文结合源代码作一些比较落地的讲解。

<!-- more -->

# AQS
AbstractQueuedSynchronizer，即队列同步器。它是构建锁或者其他同步组件的基础框架，它是JUC并发包中的核心基础组件。

**JUC大大提高了Java的并发能力，AQS是JUC的核心。**

## 原理

{% img /images/blog/2018-05-01_1.png 'image' %}

* **同步队列**：AQS通过内置的FIFO同步队列来完成资源获取线程的排队工作，如果当前线程获取同步状态失败（锁）时，AQS则会将当前线程以及等待状态等信息构造成一个节点（Node）并将其加入同步队列，同时会阻塞当前线程，当同步状态释放时，则会把节点中的线程唤醒，使其再次尝试获取同步状态。
* **继承实现**：AQS的主要使用方式是继承，子类通过继承同步器并实现它的抽象方法acquire/release来管理同步状态。
* **同步状态维护**：AQS使用一个int类型的成员变量state来表示同步状态，当state > 0时表示已经获取了锁，当state = 0时表示释放了锁。它提供了三个方法（getState()、setState(int newState)、compareAndSetState(int expect,int update)）来对同步状态state进行操作，当然AQS可以确保对state的操作是安全的。

# CountDownLatch

计数器闭锁是一个能阻塞主线程，让其他线程满足特定条件下主线程再继续执行的线程同步工具。

## 使用

```
public class CountDownLatchTest {

    private static final int COUNT = 1000;

    public static void main(String[] args) throws InterruptedException {
        ExecutorService executorService = Executors.newCachedThreadPool();
        CountDownLatch countDownLatch = new CountDownLatch(COUNT);
        for (int i = 0; i < COUNT; i++) { //countDown方法的执行次数一定要与countDownLatch的计数器数量一致，否则无法将计数器清空导致主线程无法继续执行
            int finalI = i;
            executorService.execute(() -> {
                try {
                    Thread.sleep(3000);
                    System.out.println(finalI);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                } finally {
                    countDownLatch.countDown();
                }
            });
        }
        countDownLatch.await(1, TimeUnit.SECONDS); //主线程只等1秒，超过之后继续执行主线程
        executorService.shutdown(); //当正在执行的线程执行完成之后再关闭而不是立即停止线程
        System.out.println("done!");
    }
}
```

这段程序先设置CountDownLatch为100，然后在其他线程中调用100次countDown方法，随后主程序在等待100次被执行完成之后，继续执行主线程代码

## 原理

{% img /images/blog/2018-04-28_3.png 'image' %}

图中，A为主线程，A首先设置计数器的数到AQS的state中，当调用await方法之后，A线程阻塞，随后每次其他线程调用countDown的时候，将state减1，直到计数器为0的时候，A线程继续执行。

## 使用场景
1. 并行计算：把任务分配给不同线程之后需要等待所有线程计算完成之后主线程才能汇总得到最终结果
2. 模拟并发：可以作为并发次数的统计变量，当任意多个线程执行完成并发任务之后统计一次即可

# Semaphore
信号量是一个能阻塞线程且能控制统一时间请求的并发量的工具。比如能保证同时执行的线程最多200个，模拟出稳定的并发量。

## 使用

```
public class CountDownLatchTest {

    public static void main(String[] args) {
        ExecutorService executorService = Executors.newCachedThreadPool();
        Semaphore semaphore = new Semaphore(3); //配置只能发布3个运行许可证
        for (int i = 0; i < 100; i++) {
            int finalI = i;
            executorService.execute(() -> {
                try {
                    semaphore.acquire(3); //获取3个运行许可，如果获取不到会一直等待，使用tryAcquire则不会等待
                    Thread.sleep(1000);
                    System.out.println(finalI);
                    semaphore.release(3);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            });
        }
        executorService.shutdown();
    }
}
```

由于同时获取3个许可，所以有即使开启了100个线程，但是每秒只能执行一个任务

## 原理
new Semaphore(3)传入的3就是AQS中state的值，也是许可数的总数，在调用acquire时，检测此时许可数如果小于0，就将被阻塞，然后将线程构建Node进入AQS队列

```
//AQS的骨架，其中tryAcquireShared将调用到Semaphore中的nonfairTryAcquireShared
//一般常用非公平的信号量，非公平信号量是指在获取许可时直接循环获取，如果获取失败，才会入列
//公平的信号量在获取许可时首先要查看等待队列中是否已有线程，如果有则将线程入列等待
private void doAcquireSharedInterruptibly(int arg)
    throws InterruptedException {
    final Node node = addWaiter(Node.SHARED);
    boolean failed = true;
    try {
        for (;;) {
            final Node p = node.predecessor();
            if (p == head) {
                int r = tryAcquireShared(arg);
                if (r >= 0) {
                    setHeadAndPropagate(node, r);
                    p.next = null; // help GC
                    failed = false;
                    return;
                }
            }
            if (shouldParkAfterFailedAcquire(p, node) &&
                parkAndCheckInterrupt())
                throw new InterruptedException();
        }
    } finally {
        if (failed)
            cancelAcquire(node);
    }
}

// 如果remaining小于0，许可获取失败，执行shouldParkAfterFailedAcquire方法入列然后等待
// 如果remaining大于0，许可获取成功，且更新state成功，那么则setHeadAndPropagate并且立即返回
final int nonfairTryAcquireShared(int acquires) {
    for (;;) {
        int available = getState();
        int remaining = available - acquires;
        if (remaining < 0 ||
            compareAndSetState(available, remaining))
            return remaining;
    }
}
    
```

## 使用场景
数据库连接并发数，如果超过并发数，等待（acqiure）或者抛出异常（tryAcquire）

# CyclicBarrier
可以让一组线程相互等待，当每个线程都准备好之后，所有线程才继续执行的工具类

## 使用
```
import java.util.concurrent.*;

public class CyclicBarrierTest {
    private static CyclicBarrier cyclicBarrier = new CyclicBarrier(5, () -> {
        System.out.println("ready done callback!");
    });

    public static void main(String[] args) throws InterruptedException {
        ExecutorService executorService = Executors.newCachedThreadPool();
        for (int i = 0; i < 100; i++) {
            int finalI = i;
            Thread.sleep(1000);
            executorService.execute(() -> {
                try {
                    System.out.println(finalI + "ready!");
                    cyclicBarrier.await();
//                    cyclicBarrier.await(2000, TimeUnit.MILLISECONDS); // 如果某个线程等待超过2秒就报错
                    System.out.println(finalI + "go!");
                } catch (Exception e) {
                    e.printStackTrace();
                }
            });

        }
    }
}
```

## 原理

{% img /images/blog/2018-05-01_2.png 'image' %}

与CountDownLatch类似，都是通过计数器实现的，当某个线程调用await之后，计数器减1，当计数器大于0时将等待的线程包装成AQS的Node放入等待队列中，当计数器为0时将等待队列中的Node拿出来执行。

与CountDownLatch的区别：  

1. CDL是一个线程等其他线程，CB是多个线程相互等待
2. CB的计数器能重复使用，调用多次

## 使用场景
1. CyclicBarrier可以用于多线程计算数据，最后合并计算结果的应用场景。比如我们用一个Excel保存了用户所有银行流水，每个Sheet保存一个帐户近一年的每笔银行流水，现在需要统计用户的日均银行流水，先用多线程处理每个sheet里的银行流水，都执行完之后，得到每个sheet的日均银行流水，最后，再用barrierAction用这些线程的计算结果，计算出整个Excel的日均银行流水。
2. 有四个游戏玩家玩游戏，游戏有三个关卡，每个关卡必须要所有玩家都到达后才能允许通过。其实这个场景里的玩家中如果有玩家A先到了关卡1，他必须等到其他所有玩家都到达关卡1时才能通过，也就是说线程之间需要相互等待。

# ReentrantLock
名为可重入锁，其实synchronized也可重入，是JDK层级上的一个并发控制工具

## 使用
```
public class ConcurrencyTest {
    private static final int THREAD_COUNT = 5000;
    private static final int CONCURRENT_COUNT = 200;
    private static int count = 0;
    private static Lock lock = new ReentrantLock();

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


    private static void add() {
        lock.lock();
        try {
            count++;
        } finally {
            lock.unlock();
        }
    }
}
```

## 原理
参考：[https://www.jianshu.com/p/fe027772e156](https://www.jianshu.com/p/fe027772e156)

```
// 以公平锁为例，从lock.lock()开始研究
final void lock() { acquire(1);}

public final void acquire(int arg) {
    if (!tryAcquire(arg) && // 首先通过公平或者非公平方式尝试获取锁
        acquireQueued(addWaiter(Node.EXCLUSIVE), arg)) // 然后构建一个Node放入队列中并等待执行的时机
        selfInterrupt();
}

// 公平锁设置锁执行状态的逻辑
protected final boolean tryAcquire(int acquires) {
    final Thread current = Thread.currentThread();
    int c = getState();
    if (c == 0) { //如果state是0，就是当前的锁没有人占有
        if (!hasQueuedPredecessors() && // 公平锁的核心逻辑，判断队列是否有排在前面的线程在等待锁，非公平锁就没这个条件判断
            compareAndSetState(0, acquires)) { // 如果队列没有前面的线程，使用CAS的方式修改state
            setExclusiveOwnerThread(current); // 将线程记录为独占锁的线程
            return true;
        }
    }
    else if (current == getExclusiveOwnerThread()) { // 因为ReentrantLock是可重入的，线程可以不停地lock来增加state的值，对应地需要unlock来解锁，直到state为零
        int nextc = c + acquires;
        if (nextc < 0)
            throw new Error("Maximum lock count exceeded");
        setState(nextc);
        return true;
    }
    return false;
}

// 接下来要执行的acquireQueued如下
final boolean acquireQueued(final Node node, int arg) {
    boolean failed = true;
    try {
        boolean interrupted = false;
        for (;;) {
            final Node p = node.predecessor();
            if (p == head && tryAcquire(arg)) { // 再次使用公平锁逻辑判断是否将Node作为头结点立即执行
                setHead(node);
                p.next = null; // help GC
                failed = false;
                return interrupted;
            }
            if (shouldParkAfterFailedAcquire(p, node) &&
                parkAndCheckInterrupt())
                interrupted = true;
        }
    } finally {
        if (failed)
            cancelAcquire(node);
    }
}

```

## 与synchronized的区别
1. 用法。synchronized既可以很方便的加在方法上，也可以加载特定代码块上，而lock需要显示地指定起始位置和终止位置。
2. 实现。synchronized是依赖于JVM实现的，而ReentrantLock是JDK实现的
3. 性能。synchronized和lock其实已经相差无几，其底层实现已经差不多了。但是如果你是Android开发者，使用synchronized还是需要考虑其性能差距的。
4. 功能。ReentrantLock功能更强大。  
4.1 ReentrantLock可以指定是公平锁还是非公平锁，而synchronized只能是非公平锁，所谓的公平锁就是先等待的线程先获得锁  
4.2 ReentrantLock提供了一个Condition（条件）类，用来实现分组唤醒需要唤醒的线程们，而不是像synchronized要么随机唤醒一个线程要么唤醒全部线程  
4.3 ReentrantLock提供了一种能够中断等待锁的线程的机制，通过lock.lockInterruptibly()来实现这个机制
                                                                                             
我们控制线程同步的时候，**优先考虑synchronized，如果有特殊需要，再进一步优化**。ReentrantLock如果用的不好，不仅不能提高性能，还可能带来灾难。

# Condition
条件对象的意义在于对于一个已经获取锁的线程，如果还需要等待其他条件才能继续执行的情况下，才会使用Condition条件对象。

与ReentrantLock结合使用，类似wait与notify。

## 使用
```
import java.util.concurrent.locks.Condition;
import java.util.concurrent.locks.ReentrantLock;

public class ConditionTest {

    public static void main(String[] args) {
        ReentrantLock lock = new ReentrantLock();
        Condition condition = lock.newCondition();
        Thread thread1 = new Thread(() -> {
            lock.lock();
            try {
                System.out.println(Thread.currentThread().getName() + " run");
                System.out.println(Thread.currentThread().getName() + " wait for condition");
                try {
                    condition.await(); // 1.将线程1放入到Condition队列中等待被唤醒，且立即释放锁
                    System.out.println(Thread.currentThread().getName() + " continue"); // 3.线程2执行完毕释放锁，此时线程1已经在AQS等待队列中，则立即执行
                } catch (InterruptedException e) {
                    System.err.println(Thread.currentThread().getName() + " interrupted");
                    Thread.currentThread().interrupt();
                }
            } finally {
                lock.unlock();
            }
        });
        Thread thread2 = new Thread(() -> {
            lock.lock();
            try {
                System.out.println(Thread.currentThread().getName() + " run");
                System.out.println(Thread.currentThread().getName() + " sleep 1 secs");
                try {
                    Thread.sleep(1000);
                } catch (InterruptedException e) {
                    System.err.println(Thread.currentThread().getName() + " interrupted");
                    Thread.currentThread().interrupt();
                }
                condition.signalAll(); // 2.线程2获得锁，signalAll将Condition中的等待队列全部取出并加入到AQS中
            } finally {
                lock.unlock();
            }
        });
        thread1.start();
        thread2.start();
    }

}
```

输出结果为
```
Thread-0 run
Thread-0 wait for condition
Thread-1 run
Thread-1 sleep 1 secs
Thread-0 continue
```

## 使用场景
可参看第一篇中PDF资料中《线程间通信》一节

# Future、FutureTask
不是AQS的子类，但是能拿到线程执行的结果非常有用。

## Callable与Runnable
### java.lang.Runnable
```
public interface Runnable {
    public abstract void run();
}
```

由于run()方法返回值为void类型，所以在执行完任务之后无法返回任何结果

要使用的话直接实现就可以了

### java.util.concurrent.Callable

```
@FunctionalInterface
public interface Callable<V> {
    V call() throws Exception;
}
```

泛型接口，call()函数返回的类型就是传递进来的V类型，同时能结合lambda使用

要使用的话要结合ExecutorService的如下方法使用

```
<T> Future<T> submit(Callable<T> task);
<T> Future<T> submit(Runnable task, T result);
Future<?> submit(Runnable task);
```

## Future接口
`FutureTask<V> implements RunnableFuture<V>`  
`RunnableFuture<V> extends Runnable, Future<V>`

Future是Java 5添加的类，用来描述一个异步计算的结果。你可以使用isDone方法检查计算是否完成，或者使用get阻塞住调用线程，直到计算完成返回结果，你也可以使用cancel方法停止任务的执行。  

```
public class FutureTest {

    public static void main(String[] args) throws ExecutionException, InterruptedException {
        ExecutorService executorService = Executors.newCachedThreadPool();
        Future<String> future = executorService.submit(() -> {
            try {
                System.out.println("doing");
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            return "done";
        });
        System.out.println(future.get());
    }
}
```

接口毕竟是接口，只能被赋值，不能直接new出来，所以可以new FutureTask直接来创建Future任务
## FutureTask类
```
public class FutureTaskTest {


    public static void main(String[] args) throws ExecutionException, InterruptedException {
        ExecutorService executorService = Executors.newCachedThreadPool();
        FutureTask<String> futureTask = new FutureTask<>(() -> {
            System.out.println("doing");
            Thread.sleep(1000);
            return "down";
        });
        executorService.submit(futureTask);

//        new Thread(futureTask).start();
        System.out.println(futureTask.get());
        executorService.shutdown();
    }
}
```

## CompletableFuture类
但其实在项目中使用到最多的Future类是1.8提供的这个类，因为[虽然Future以及相关使用方法提供了异步执行任务的能力，但是对于结果的获取却是很不方便，只能通过阻塞方式得到任务的结果，阻塞的方式显然和我们的异步编程的初衷相违背。](http://colobu.com/2016/02/29/Java-CompletableFuture/#)

其实简单来说，原理就是通过自己维护一套线程同步与等待的机制与线程池去实现这样的异步任务处理机制，下面的例子是开发中最经常用到的，等待所有任务完成，继续处理数据的例子。还有异步任务依赖的例子请参看上文连接。

```
public class CompletableFutureTest {
    public static void main(String[] args) throws ExecutionException, InterruptedException {
        CompletableFuture<String> string1Future = CompletableFuture.supplyAsync(() -> {
            System.out.println("doing string1");
            try {
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            System.out.println("done string1");
            return "string1";
        });
        CompletableFuture<String> string2Future = CompletableFuture.supplyAsync(() -> {
            System.out.println("doing string2");
            try {
                Thread.sleep(2000);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            System.out.println("done string2");
            return "string2";
        });

        CompletableFuture.allOf(string1Future, string2Future).join();
        System.out.println(string1Future.get() + "and" + string2Future.get());
    }
}
```

# BlockingQueue
假设我们有若干生产者线程，另外又有若干个消费者线程。如果生产者线程需要把准备好的数据共享给消费者线程，利用队列的方式来传递数据，就可以很方便地解决他们之间的数据共享问题。  
但如果生产者和消费者在某个时间段内，万一发生数据处理速度不匹配的情况呢？理想情况下，如果生产者产出数据的速度大于消费者消费的速度，并且当生产出来的数据累积到一定程度的时候，那么生产者暂停等待一下（阻塞生产者线程）或者继续将产品放入队列中。    
然而，在concurrent包发布以前，在多线程环境下，我们每个程序员都必须去自己控制这些细节，尤其还要兼顾效率和线程安全，而这会给我们的程序带来不小的复杂度

在后文的线程池相关内容中会提到，线程池也使用到了这个工具完成不同需求。

使用方式、子类的详细介绍参看[这里](http://wsmajunfeng.iteye.com/blog/1629354)
