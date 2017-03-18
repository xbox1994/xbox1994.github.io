---
layout: post
title: "Linux进程后台启动总结"
date: 2017-02-21 16:44:21 +0800
comments: true
categories: Devops
---
& screen nohup service...进程的后台启动方式总结
<!--more-->
##&
这是一个最简单看起来是将进程作为后台启动的方式,让我们试试看
```
➜  ~ sleep 100 &
[1] 6564
```
这样就可以在当前终端运行其他命令,看起来启动了一个后台进程去运行sleep,但是在终端关闭之后进程会被杀死,使用disown可以将进程继续保持下去即使当前终端关闭
```
➜  ~ jobs
[1]  + running    sleep 100
➜  ~ disown
```
也可以在命令后面加上&>/dev/null &或>/dev/null 2>&1将输出重定向

##nohup
man: nohup -- invoke a utility immune to hangups

nohup绕过HUP信号(信号挂断)即使在终端关闭时也可以在后台运行命令,但是直接跟命令会在当前终端运行,所以结合&可以将命令在后台挂起运行并且始终保持
```
➜  ~ nohup sleep 10000 &>/dev/null &
[1] 7901
appending output to nohup.out
➜  ~
切换终端ps aux | grep sleep可以查看
```

##screen
man: Screen  is  a  full-screen window manager that multiplexes a physical terminal between several processes (typically interactive shells).

用srceen启动一个终端,直接运行前台程序,然后关闭终端且不退出screen创建的终端.这是一个可以重新连接到后台程序的非常好的方法,因为改命令支持screen -r返回到之前打开且没有关闭的终端
##forever
github: A simple CLI tool for ensuring that a given script runs continuously (i.e. forever).

npm install forever -g
```
➜  spider4yyh git:(master) forever start ./bin/www
warn:    --minUptime not set. Defaulting to: 1000ms
warn:    --spinSleepTime not set. Your script will exit if it does not stay up for at least 1000ms
info:    Forever processing file: ./bin/www
```
##system serivce
其实重点在这里,我们使用命令将程序运行在后台一般是手动测试的时候进行的,如果在真实服务器运行自己的应用,通常应该讲我们需要启动的进程做成系统级服务,使用service xxx start/restart/status/stop可以修改或查看服务的状态,这样非常方便我们使用脚本或者手动管理进程而不用了解其实现细节

下面是一个启动uncorn的例子,最后将文件命名为unicorn存储在/etc/init.d后即可运行service unicorn start

    #!/bin/sh
    ### BEGIN INIT INFO
    # Provides:          unicorn
    # Required-Start:    $remote_fs $syslog
    # Required-Stop:     $remote_fs $syslog
    # Default-Start:     2 3 4 5
    # Default-Stop:      0 1 6
    # Short-Description: Start unicorn at boot time
    # Description:       Run input app server
    ### END INIT INFO
    set -e
    # Example init script, this can be used with nginx, too,
    # since nginx and unicorn accept the same signals
    
    # Feel free to change any of the following variables for your app:
    TIMEOUT=${TIMEOUT-60}
    APP_ROOT=$(get_app_root.sh)
    PID=$APP_ROOT/tmp/pids/unicorn.pid
    ENVIRONMENT=$(get_env_from_hostname.sh)
    
    CMD="cd $APP_ROOT && ./bin/unicorn -D -c $APP_ROOT/unicorn.rb -E $ENVIRONMENT"
    
    action="$1"
    set -u
    
    old_pid="$PID.oldbin"
    
    cd $APP_ROOT || exit 1
    
    sig () {
      test -s "$PID" && kill -$1 `cat $PID`
    }
    
    oldsig () {
      test -s $old_pid && kill -$1 `cat $old_pid`
    }
    
    workersig () {
      workerpid="$APP_ROOT/tmp/unicorn.$2.pid"
      test -s "$workerpid" && kill -$1 `cat $workerpid`
    }
    
    case $action in
    status )
      sig 0 && echo >&2 "unicorn is running." && exit 0
      echo >&2 "unicorn is not running." && exit 1
      ;;
    start)
      sig 0 && echo >&2 "Already running" && exit 0
      su - unicorn -c "$CMD"
      ;;
    stop)
      sig QUIT && exit 0
      echo >&2 "Not running"
      ;;
    force-stop)
      sig TERM && exit 0
      echo >&2 "Not running"
      ;;
    restart|reload)
      sig HUP && echo reloaded OK && exit 0
      echo >&2 "Couldn't reload, starting '$CMD' instead"
      su - unicorn -c "$CMD"
      ;;
    upgrade)
      if sig USR2 && sleep 20 && sig 0 && oldsig QUIT
      then
        n=$TIMEOUT
        while test -s $old_pid && test $n -ge 0
        do
          printf '.' && sleep 1 && n=$(( $n - 1 ))
        done
        echo
    
        if test $n -lt 0 && test -s $old_pid
        then
          echo >&2 "$old_pid still exists after $TIMEOUT seconds"
          exit 1
        fi
        exit 0
      fi
      echo >&2 "Couldn't upgrade, starting '$CMD' instead"
      su - unicorn -c "$CMD"
      ;;
    kill_worker)
      workersig QUIT $2 && exit 0
      echo >&2 "Worker not running"
      ;;
    
    reopen-logs)
      sig USR1
      ;;
    *)
      echo >&2 "Usage: $0 <start|stop|restart|upgrade|force-stop|reopen-logs>"
      exit 1
      ;;
    esac

参考:
https://www.maketecheasier.com/run-bash-commands-background-linux/  
https://github.com/foreverjs/forever  
man