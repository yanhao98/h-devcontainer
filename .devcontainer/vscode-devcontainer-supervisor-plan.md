# VS Code Dev Container 接管 Supervisord 方案

更新时间: 2026-03-26

## 背景

当前仓库已经完成了 `docker run` / `docker compose` 路径下的 `supervisord` 接管：

- 镜像内已安装 `supervisor`
- 镜像 `ENTRYPOINT` 会在无参数启动时拉起 `supervisord`
- `desktop-lite` 已经可以作为一个受管服务运行

但 VS Code Dev Container 这条路径还没有接过去。

## 现状

当前 `.devcontainer/devcontainer.json` 没有显式设置 `overrideCommand`。

在实际运行的 Dev Container 里，PID 1 不是镜像里的 `/devcontainer/ENTRYPOINT.sh`，而是 VS Code Dev Containers 注入的保活 shell。现场观察到的 `/proc/1/cmdline` 形态如下：

```sh
/bin/sh -c echo Container started
trap "exit 0" 15

exec "$@"
while sleep 1 & wait $!; do :; done - 
```

这意味着：

1. 镜像里的 `ENTRYPOINT` 被绕过了。
2. `supervisord` 不会自动成为容器主进程。
3. 目前桌面环境仍然靠 `postStartCommand` 里的 `h-setup-desktop-lite` 自己后台拉起。

当前相关文件：

- `.devcontainer/devcontainer.json`
- `.devcontainer/lifecycle-scripts.d/04-postStartCommand.d/-`
- `.devcontainer/_build-context/rootfs/devcontainer/ENTRYPOINT.sh`
- `.devcontainer/_build-context/rootfs/etc/supervisor/supervisord.conf`

## 目标

让 VS Code Dev Container 与 `docker run` 路径保持一致：

1. 容器启动时由镜像 `ENTRYPOINT` 接管。
2. `supervisord` 成为主进程。
3. `desktop-lite` 等内置服务改由 supervisor 管理。
4. VS Code 只负责 attach 和执行 lifecycle scripts，不再自己承担容器保活职责。

## 推荐改法

### 1. 在 `devcontainer.json` 里显式关闭命令覆盖

建议增加：

```json
"overrideCommand": false
```

这是最关键的一步。没有这一步，镜像 `ENTRYPOINT` 不会生效。

### 2. 保留镜像 `ENTRYPOINT`，不要再让 `postStartCommand` 启桌面

当前 `04-postStartCommand.d/-` 里有：

```sh
h-setup-desktop-lite
h-gen-wallpaper
```

接管后建议调整为：

- 删除 `h-setup-desktop-lite`
- `h-gen-wallpaper` 改为单独等待桌面就绪后执行，或者也改成 supervisor 服务

原因：

- `desktop-lite` 已经可以由 supervisor 托管
- 再在 `postStartCommand` 里手动启动一遍，会出现重复启动和竞争
- `h-gen-wallpaper` 依赖 X/VNC 已经可用，直接保留可能有时序问题

### 3. 转发 supervisor 面板端口

建议把 `9001` 加进 `.devcontainer/devcontainer.json` 的 `forwardPorts`：

```json
"forwardPorts": [1116, 5901, 9001]
```

如果需要端口标签，也可以在 `portsAttributes` 增加：

```json
"9001": { "label": "Supervisord 控制面板", "onAutoForward": "notify" }
```

### 4. 明确 Dev Container 下的服务启用策略

建议保留镜像里的默认值：

```sh
SUPERVISOR_ENABLED_SERVICES=desktop-lite
SUPERVISOR_HTTP_ENABLED=true
```

如需在 VS Code Dev Container 下单独覆盖，可放到 `containerEnv`：

```json
"containerEnv": {
  "TZ": "${localEnv:TZ:Asia/Shanghai}",
  "SUPERVISOR_ENABLED_SERVICES": "desktop-lite",
  "SUPERVISOR_HTTP_ENABLED": "true"
}
```

### 5. 评估是否需要保留 `postStartCommand`

接管后，`postStartCommand` 的职责应收缩到“非主服务型”的一次性动作，例如：

- 欢迎信息
- 非阻塞环境检查
- 用户态配置同步

不建议继续在 `postStartCommand` 里启动长期服务。

## 实施步骤

建议按下面顺序改，便于定位问题：

1. 在 `.devcontainer/devcontainer.json` 增加 `"overrideCommand": false`
2. 在 `forwardPorts` 里加入 `9001`
3. 从 `.devcontainer/lifecycle-scripts.d/04-postStartCommand.d/-` 删除 `h-setup-desktop-lite`
4. 先临时注释 `h-gen-wallpaper`，确认主链路稳定
5. Rebuild Dev Container
6. 进入容器后验证 `PID 1` 是否为 `supervisord`
7. 确认 `desktop-lite` 为 `RUNNING`
8. 再决定 `h-gen-wallpaper` 是保留为 postStart，还是改为 supervisor 服务

## 验收标准

Dev Container 重建后，至少满足以下条件：

1. `cat /proc/1/cmdline | tr '\0' ' '` 能看到 `supervisord -n -c /etc/supervisor/supervisord.conf`
2. `supervisorctl status` 能看到 `desktop-lite RUNNING`
3. `pgrep -af desktop-init.sh` 不应出现多份重复实例
4. `pgrep -af Xtigervnc` 能看到 VNC 进程
5. VS Code Ports 面板能看到并转发 `9001`
6. 不再依赖 `postStartCommand` 启动桌面

## 风险点

### 1. 首次启动会更慢

`desktop-lite` 首次启动仍然可能触发 apt 安装，Dev Container 首次 attach 会比现在慢。

缓解方式：

- 接受首次冷启动开销
- 或后续把桌面相关依赖前置到镜像构建阶段

### 2. `h-gen-wallpaper` 有时序风险

如果它在 X/VNC 还没完全起来前执行，可能失败。

缓解方式：

- 先暂时关闭
- 或改成等待 `DISPLAY` 可用后再执行
- 或做成 supervisor 的后置服务

### 3. 旧的“保活 shell”不再是 PID 1

这会改变 Dev Container 的进程模型，但这是预期变化，不是回归。

## 回滚方案

如果接管后发现 VS Code attach 或 lifecycle 有兼容问题，可以按下面方式回滚：

1. 删除 `.devcontainer/devcontainer.json` 里的 `"overrideCommand": false`
2. 恢复 `04-postStartCommand.d/-` 里的 `h-setup-desktop-lite`
3. 如有必要，移除 `9001` 端口转发

回滚后会恢复到当前模式：

- VS Code 注入 keep-alive shell 作为 PID 1
- `postStartCommand` 手动后台拉起桌面
- `supervisord` 仅在 `docker run` / `docker compose` 路径下生效

## 建议的下一步

真正开始接管时，先做一版最小改动：

1. 只改 `overrideCommand`
2. 只删 `postStartCommand` 里的 `h-setup-desktop-lite`
3. 暂时不处理壁纸

先把主链路跑通，再补体验层细节。
