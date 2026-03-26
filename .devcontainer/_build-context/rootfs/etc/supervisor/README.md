# Supervisor Notes

## 目录说明

- `supervisord.conf`
  - Supervisor 主配置文件
  - 定义主日志、pid 文件、unix socket、include 规则

- `conf.d.available/*.conf`
  - 可启用的静态服务配置模板
  - 例如 `desktop-lite.conf`、`opencode.conf`

- `conf.d.available/*.conf.tpl`
  - 需要在容器启动时渲染的模板
  - 例如 `00-inet-http-server.conf.tpl`

- `conf.d.enabled/*.conf`
  - 容器启动时真正启用的配置
  - 由 `ENTRYPOINT.sh` 生成或链接

## 进程链路

当前容器里，Supervisor 的启动链路大致是：

```text
ENTRYPOINT.sh (usr_vscode)
  -> sudo
  -> supervisord (root)
  -> [program:desktop-lite] / [program:opencode]
  -> setuid 到 usr_vscode
  -> 执行 command=
```

重点：

- `supervisord` 主进程自己是 `root`
- 具体服务进程通常不是 `root`
- 当 `program` 里写了 `user=usr_vscode`，Supervisor 会在真正执行 `command=` 前把进程身份切到 `usr_vscode`

## 什么是 setuid

这里的 `setuid` 可以简单理解成：

- 把“这个进程现在是谁”切换成另一个 Unix 用户

例如：

- `supervisord` 当前是 `root`
- 读取到 `user=usr_vscode`
- 在执行 `command=` 前，把进程身份切成 `usr_vscode`

所以 `setuid` 改的是“进程身份”，不是环境变量字符串。

## 为什么 `user=` 之后还要写 `environment=`

`user=usr_vscode` 只会切换进程身份，不会自动把环境变量里的这些值一起改掉：

- `HOME`
- `USER`
- `LOGNAME`

所以如果不显式修正环境，可能出现：

```text
id -un -> usr_vscode
$USER  -> root
```

这会导致：

- 进程实际身份已经是 `usr_vscode`
- 但程序读取环境变量时，看到的仍然像是 `root`

所以在当前这些 `program` 配置里保留：

```ini
environment=HOME="/home/usr_vscode",USER="usr_vscode",LOGNAME="usr_vscode"
```

目的是让“进程真实身份”和“环境变量中的用户信息”保持一致。

## `desktop-lite.conf` 和 `opencode.conf` 常见字段说明

### `command=`

- Supervisor 实际执行的命令
- 这是服务入口
- 例如 `desktop-lite` 走 `/usr/local/bin/h-service-desktop-lite`
- `opencode` 走 `/usr/local/bin-priority/opencode serve`

### `directory=`

- 服务启动前切换到的工作目录
- 相当于先 `cd` 到这个目录再执行命令

### `user=`

- 指定这个服务最终以哪个用户身份运行
- 这不是“Supervisor 自己是谁”，而是“Supervisor 拉起的这个服务是谁”

### `autostart=true`

- `supervisord` 启动后自动启动这个服务

### `autorestart=true`

- 服务异常退出后自动重启

### `autorestart=unexpected`

- 这是 Supervisor 的另一种常见写法
- 含义是：只有当进程以“非预期退出码”退出时，才自动重启
- “是否预期”由 `exitcodes=` 决定
- 例如默认 `exitcodes=0` 时：
  - 退出码是 `0`，视为预期退出，不自动重启
  - 退出码不是 `0`，视为非预期退出，会自动重启

常见对比：

- `autorestart=true`
  - 只要进程进入 `EXITED`，就会重启
  - 不看退出码是不是 `0`

- `autorestart=unexpected`
  - 只有退出码不在 `exitcodes=` 里，才重启
  - 更适合“正常退出不该拉起，异常退出才拉起”的服务

- `autorestart=false`
  - 退出后不自动重启

如果你把它理解成一句话：

- `true` = 退出就重启
- `unexpected` = 异常退出才重启
- `false` = 不重启

### `exitcodes=0`

- 这是“哪些退出码算正常退出”的列表
- 主要和 `autorestart=unexpected` 一起看
- 默认值通常是 `0`
- 如果你写成 `exitcodes=0,2`，那退出码 `0` 和 `2` 都算预期退出

### `startsecs=5`

- 进程连续活过 5 秒，才算启动成功
- 如果很快就退出，会被视为启动失败

### `startretries=3`

- 启动失败时最多重试 3 次

### `stopsignal=TERM`

- 正常停止服务时，先发 `SIGTERM`

### `stopasgroup=true`

- 停止服务时，信号发给整个进程组
- 适合会再拉起子进程的服务，避免只停掉父进程、子进程残留

### `killasgroup=true`

- 如果优雅停止失败，需要强杀时，也杀整个进程组

### `redirect_stderr=true`

- 把标准错误合并到标准输出
- 这样大多数日志会集中到同一个输出流里

### `stdout_logfile=`

- 标准输出写到哪个日志文件

### `stderr_logfile=`

- 标准错误写到哪个日志文件
- 如果 `redirect_stderr=true`，通常不会单独用到

### `stdout_logfile_maxbytes=10MB`

- 单个日志文件最大大小
- 达到后会轮转

### `stdout_logfile_backups=3`

- 日志轮转时保留几个历史文件

### `environment=...`

- 为这个服务额外指定环境变量
- 当前主要用于把 `HOME/USER/LOGNAME` 修正成和 `user=` 一致

## `supervisorctl add` 是什么

`supervisorctl add` 不是：

- 临时添加一条随手写的命令
- 在不改配置文件的情况下动态创建一个任意服务

它真正做的是：

- 把“已经出现在配置文件里、并且已经被 Supervisor 重新读取到”的 process/group 激活进当前运行中的 active config

可以把它理解成：

1. 你先改了配置文件
2. 让 Supervisor 重新读取配置
3. 再用 `add` 把某个新 group 加进当前运行态

典型链路是：

```text
修改 *.conf
  -> supervisorctl reread
  -> supervisorctl add <group>
```

这里的 `add <name>`：

- `name` 指的是 process group 名
- 它激活的是“配置里已经存在的 group”
- 不是 shell 命令本身

## `add`、`reread`、`update` 的区别

### `supervisorctl reread`

- 重新读取配置文件
- 只告诉你有哪些新增、修改、删除
- 不会真正把这些变化应用到当前运行中的进程

### `supervisorctl add <group>`

- 把某个新读到的 group 激活进当前运行态
- 更适合精确控制单个新增 group

### `supervisorctl update`

- 这是更常用的整体命令
- 它会先重新读取配置，再自动对新增/修改/删除的 group 做 add/remove/restart
- 一般可以理解成“把配置变化真正应用下去”

如果只记一句话：

- `reread` = 看到了变化
- `add` = 激活某个新 group
- `update` = 一次性应用全部配置变化
