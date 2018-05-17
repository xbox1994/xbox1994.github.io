---
layout: post
title: "Java多线程与高并发(三):对象的安全发布与共享策略"
date: 2018-04-30 21:10:40 +0800
comments: true
categories: 后台 
---

面试官：你知道如何发布或共享一个对象吗？

<!-- more -->

**发布对象：使一个对象能够被其他线程、其他作用域的代码所使用。** 

## 变量逸出原有作用域
```
import java.util.Arrays;

public class Main {
    private String[] strs = {"1", "2", "3"};

    public String[] getStrs() {
        return strs;
    }

    public static void main(String[] args) {
        Main m1 = new Main();
        System.out.println(Arrays.toString(m1.getStrs()));
        m1.getStrs()[0] = "4";
        System.out.println(Arrays.toString(m1.getStrs()));
    }
}
```

通过访问对象中的共有方法获取私有变量的值，然后更改内部数据，则导致变量逸出作用域。但是我们有时候就是想暴露私有成员变量出来让我们去修改，所以提供getter是没毛病的，不过要注意的是我们在编码的时候需要对仅仅需要发布的对象进行发布。

## 对象逸出
**对象逸出：当一个对象还没构造完成，就使它被其他线程所见。**

以下代码发布了一个未完成构造的对象到另一个对象中：

```
public class Main {

    public Main() {
        System.out.println(Main.this);
        System.out.println(Thread.currentThread());
        Thread t = new Thread(InnerClass::new);
        t.start();
    }

    class InnerClass {
        public InnerClass() {
            System.out.println(Main.this);
            System.out.println(Thread.currentThread());
        }
    }

    public static void main(String[] args) {
        new Main();
    }
}
```

this引用被线程t共享，故线程t的发布将导致Main对象的发布，由于Main对象被发布时可能还未构造完成，这将导致Main对象逸出（在构造函数中创建线程是可以的，但是不要在构造函数执行完之前启动线程）。

```
public class Main {
    private Thread t;

    private Main() {
        System.out.println(Main.this);
        System.out.println(Thread.currentThread());
        this.t = new Thread(InnerClass::new);
    }

    class InnerClass {
        public InnerClass() {
            System.out.println(Main.this);
            System.out.println(Thread.currentThread());
        }
    }

    public static Main getMainInstance() {
        Main main = new Main();
        main.t.start();
        return main;
    }

    public static void main(String[] args) {
        getMainInstance();
    }
}
```
通过**私有构造函数 + 工厂模式**解决。

# 安全发布策略
安全地发布对象是保证对象在其他线程可见之前一定是完成初始化的。那么我们要做的就是控制初始化过程，首先就需要将构造器私有化，接下来就通过不同的方式来完成对象初始化。

## 将对象的引用在静态初始化函数中初始化
```
public class Singleton {
    private static Singleton instance = new Singleton();

    private Singleton() {
    }
    
    public static Singleton getInstance() {
        return instance;
    }
}
```

直接在静态变量后new出来或者在static代码块中初始化，通过JVM的单线程类加载机制来保证该对象在其他对象访问之前被初始化

## 将对象的初始化手动同步处理

```
public class Singleton {
    private static Singleton instance;

    private Singleton() {
    }
    
    public static synchronized Singleton getInstance() {
        if (instance == null) {
            instance = new Singleton();
        }
        return instance;
    }
}
```

## 使用volidate修饰变量

```
public class Singleton {
    private static volatile Singleton instance;

    private Singleton() {
    }

    public static Singleton getInstance() {
        if (instance == null) {
            synchronized (Singleton.class) {
                if (instance == null) {
                    instance = new Singleton();
                }
            }
        }
        return instance;
    }
}
```

为了实现懒汉式+线程安全，可能需要使用DCL双重检验锁来完成，那么`                    instance = new Singleton();`就涉及到同步问题，最终会导致另一个线程拿到了尚未初始化完成的对象。所以使用volidate来修饰。详细解释可参看上篇文章。

# 安全共享策略
安全共享是在多线程访问共享对象时，让对象的行为保持逻辑正常。

## 线程封闭
将对象封闭在一个线程内部，那么其他线程当然无法访问，则这些对象不可能涉及到共享问题，有以下方式：

* Ad-hoc线程封闭：维护线程封闭完全由编程承担，不推荐
* 局部变量封闭：局部变量的固有属性之一就是封闭在执行线程内，无法被外界引用，所以尽量使用局部变量可以减少逸出的发生
* ThreadLocal：是一个能提供线程私有变量的工具类。基于每个Thread对象中保存了ThreadLocalMap对象，ThreadLocal类就在get和set方法中通过<ThreadLocal, value>键值对操作ThreadLocalMap，推荐。通常使用在传递每个线程（请求）的上下文。

```
public class ThreadLocalTest {
    private ThreadLocal<String> localString = new ThreadLocal<>();

    public static void main(String[] args) {
        ThreadLocalTest t = new ThreadLocalTest();
        Runnable runnable = () -> {
            t.localString.set("localString in thread: " + Thread.currentThread());
            System.out.println(t.localString.get());
        };
        new Thread(runnable).start();
        new Thread(runnable).start();
    }
}
```

以上代码表现，尽管是从在同一个对象中的同一个成员变量取值，也会因为线程不同的原因取到不同的值，因为set的时候ThreadLocal会根据线程来设置进对应的map中。

## final
final的对象的状态只有一种状态，并且该状态由其构造器控制。如果一定要将发布对象，那么不可变的对象是首选，因为其一定是多线程安全的，可以放心地被用来数据共享。

但引用的变量的内容还是能被修改，仅仅保证了引用不能被修改，如下：

```
public class ImmutableExample1 {

    private final static Integer a = 1;
    private final static String b = "2";
    private final static Map<Integer, Integer> map = Maps.newHashMap();

    static {
        map.put(1, 2);
        map.put(3, 4);
        map.put(5, 6);
    }

    public static void main(String[] args) {
//        a = 2;
//        b = "3";
//        map = Maps.newHashMap();
        map.put(1, 3);
        log.info("{}", map.get(1));
    }
}
```

Collections.unmodifiableMap(map)则可以将可修改的map转换为不可修改的map，或者使用使用com.google.guava中的ImmutableXXX集合类可以的禁止对集合修改的操作：

```
public class ImmutableExample3 {

    private final static ImmutableList<Integer> list = ImmutableList.of(1, 2, 3);

    private final static ImmutableSet set = ImmutableSet.copyOf(list);

    private final static ImmutableMap<Integer, Integer> map = ImmutableMap.of(1, 2, 3, 4);

    private final static ImmutableMap<Integer, Integer> map2 = ImmutableMap.<Integer, Integer>builder()
            .put(1, 2).put(3, 4).put(5, 6).build();


    public static void main(String[] args) {
        System.out.println(map2.get(3));
    }
}
```

## 使用线程安全的类
* StringBuilder -> StringBuffer  
* SimpleDateFormat -> JodaTime  
* ArrayList -> Vector, Stack, [CopyOnWriteArrayList](https://www.cnblogs.com/dolphin0520/p/3938914.html)
* HashSet -> Collections.synchronizedSet(new HashSet()), CopyOnWriteArraySet
* TreeSet -> Collections.synchronizedSortedSet(new TreeSet()), [ConcurrentSkipListSet](https://blog.csdn.net/guangcigeyun/article/details/8278349)
* HashMap -> HashTable, ConcurrentHashMap, Collections.synchronizedMap(new HashMap())
* TreeMap -> ConcurrentSkipListMap, Collections.synchronizedSortedMap(new TreeMap())

## 参考
http://coding.imooc.com/class/195.html    
以及其他超连接引用

## 号外号外
最近在总结一些针对**Java**面试相关的知识点，感兴趣的朋友可以一起维护~  
地址：[https://github.com/xbox1994/2018-Java-Interview](https://github.com/xbox1994/2018-Java-Interview)
