---
layout: post
title: "Java多线程与高并发(四):java.util.concurrent包"
date: 2018-05-01 11:53:15 +0800
comments: true
categories: 后台
---

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
这几天有点异常高产，先回顾一下之前写的文章，不能一次写太多导致为了写而写。
