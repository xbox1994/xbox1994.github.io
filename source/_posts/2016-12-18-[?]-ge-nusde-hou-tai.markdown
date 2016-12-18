---
layout: post
title: "一个NUS的后台"
date: 2016-12-18 16:12:24 +0800
comments: true
categories: 后台技术
---
Nginx Unicorn Sinatra  
研究一个后台架构,客户端发送的请求最开始是由是Nginx接收的,随后反向代理发送给Unicorn服务器的一个线程,接下来是Sinatra框架和Rack负责处理
<!--more-->
###Nginx
是一个高性能的HTTP和反向代理服务器

根据以下文件你可以发现在SF中我们是如何使用nginx的
infrastructure/ansible/roles.add_app_to_nginx/files/sales_refresh_app_nginx_config

    server {
        #监听端口号
        listen 80;
        #会根据收到的HOST来匹配哪一个server，这样随便写没有匹配到的，那么第一个就是默认的
        server_name _;
        #重定向http请求为https
        return 301 https://$http_host$request_uri;
    }
    
    upstream unicorn_server {
        #IPC方式与unicorn通信，unicorn.rb
        server unix:/usr/share/nginx/sales_refresh_app/tmp/sockets/unicorn.sock
        #0让nginx反复重试后端即使超时，配合下面的unicorn配置文件使用
        fail_timeout=0;
    }
    
    server {
        listen 443;
        server_name _;
        #可直接访问静态文件
        root /usr/share/nginx/sales_refresh_app/public;
        ssl on;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        ssl_certificate /etc/nginx/ssl/server.crt;
        ssl_certificate_key /etc/nginx/ssl/server.key;
        location / {
        #先查找是否有可以直接访问的文件，然后再去访问app
        try_files $uri @app;
        }
        location @app {
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Host $http_host;
        proxy_redirect off;
        # pass to the upstream unicorn server mentioned above
        proxy_pass http://unicorn_server;
        }
    }

总结：在本机上同时使用nginx和unicorn，所以用到了反向代理，没有用到负载均衡。只提供https协议访问。静态文件加速访问。配置与unicorn的关系。

###Unicorn
Unicorn 是一个为运行 Rack 应用的HTTP服务器。
Rack是为使用Ruby开发web应用提供了一个最小的模块化和可修改的接口。用可能最简单的方式来包装HTTP请求和响应
             
与上下的关联
1. read/parse HTTP request headers in full
2. call Rack application（Sinatra）
3. write HTTP response back to the client

/Users/tywang/WuhanWork/sales-funnel/config.ru是入口文件
/Users/tywang/WuhanWork/sales-funnel/unicorn.rb
参考：https://unicorn.bogomips.org/Unicorn/Configurator.html#method-i-worker_processes

unicorn.rb:
   
    #where do app live???
    @dir = "/usr/share/nginx/sales_refresh_app/"
    
    worker_processes 8
    working_directory @dir
    
    #设置worker_processes的超时时间（handling the request/app.call/response cycle）单位秒，如果超时将被sigkill
    timeout 300
    
    # Specify path to socket unicorn listens to,
    # used in  nginx.conf 
    listen "#{@dir}tmp/sockets/unicorn.sock" , :backlog => 64
    
    # Set process id path
    pid "#{@dir}tmp/pids/unicorn.pid"
    
    # Set log file paths
    stderr_path "#{@dir}log/unicorn.stderr.log"
    stdout_path "#{@dir}log/unicorn.stdout.log"
    
以前碰到过的一个问题：不启用nginx和unicorn时，当程序出错，代码中不处理错误而是抛出错误会导致服务器挂掉，似乎sinatra也没有管。
答：thin是单线程的，如果代码不够健壮导致thin挂了一次就无法恢复了，unicorn是多线程的，worker_processes默认有8个哦，如果超时会被kill掉再启动的，每个worker_process只能同时服务一个client，所以并发性能很差

那么问题又来了，单线程如何实现高性能并发处理？
https://github.com/eventmachine/eventmachine
###Sinatra
Sinatra is a DSL for quickly creating web applications in Ruby with minimal effort
对我们来说就是一个Ruby开发框架，用Sinatra的写法简化我们的开发，一个基于Rack的框架

总结：Request->Nginx->Unicorn->Rack(Sinatra)->App

其他：Nginx+Unicorn+Sinatra部署方案
http://recipes.sinatrarb.com/p/deployment/nginx_proxied_to_unicorn