## Dev Container 执行顺序总结

| 序号 | 阶段/命令            | 说明                   |
| :--- | :------------------- | :--------------------- |
| 1    | initializeCommand    | 本地主机，容器创建前   |
| 2    | 容器创建             | -                      |
| 3    | onCreateCommand      | 容器首次创建时执行一次 |
| 4    | updateContentCommand | -                      |
| 5    | postCreateCommand    | 每次容器启动时执行     |
| 6    | 容器启动             | -                      |
| 7    | postStartCommand     | 容器内，每次启动       |
| 8    | VS Code 附加到容器   | -                      |
| 9    | postAttachCommand    | 容器内，每次附加       |

## Supervisord

镜像内已预装 `supervisor`，默认会在无启动命令时由 `ENTRYPOINT` 拉起，并按环境变量启用内置服务配置。

常用环境变量：

- `SUPERVISOR_ENABLED_SERVICES=desktop-lite`：启用内置服务，支持逗号分隔多个名字，例如 `desktop-lite,opencode`
- `SUPERVISOR_HTTP_ENABLED=true`：启用 Supervisord Web 控制面板
- `SUPERVISOR_HTTP_HOST=0.0.0.0`
- `SUPERVISOR_HTTP_PORT=9100`
- `SUPERVISOR_HTTP_USERNAME=`：可选；需要与 `SUPERVISOR_HTTP_PASSWORD` 同时设为非空才启用登录
- `SUPERVISOR_HTTP_PASSWORD=`：可选；默认空，表示无需登录

内置服务模板放在 `/etc/supervisor/conf.d.available/`，入口脚本会把启用项链接到 `/etc/supervisor/conf.d.enabled/`。当前内置服务包括 `desktop-lite` 和 `opencode`；`00-inet-http-server.conf.tpl` 会在启动时按环境变量渲染成最终的 HTTP 面板配置。

`desktop-lite` 现在可以作为一个受管服务启动，不再只能靠入口脚本直接后台拉起。

## Docker Mount Consistency 模式对比

| 模式              | 权威方 (Authority) | 性能特点               | 适用场景                             | 数据风险                                   |
| :---------------- | :----------------- | :--------------------- | :----------------------------------- | :----------------------------------------- |
| consistent (默认) | 双方实时同步       | I/O 性能最差，开销大   | 对数据一致性要求极高的数据库         | 无                                         |
| cached            | 主机 (Host)        | 读取速度极快，写入较慢 | Web 开发（代码在主机改，容器里运行） | 无                                         |
| delegated         | 容器 (Container)   | 写入速度极快，读取一般 | 构建任务、日志生成、大规模文件处理   | 容器崩溃时，未同步回主机的少量数据可能丢失 |

## 参考资料

- https://containers.dev/implementors/json_reference/
- https://code.visualstudio.com/docs/devcontainers/containers

- https://github.com/devcontainers/features
- https://github.com/devcontainers/feature-starter

- https://github.com/Kilo-Org/kilocode/blob/19fd3f45b4d4fed80824b0992129becf2d636961/cli/Dockerfile
- https://code.claude.com/docs/zh-CN/devcontainer
  - https://github.com/anthropics/claude-code/blob/d213a74fc8e3b6efded52729196e0c2d4c3abb3e/.devcontainer/Dockerfile
- https://github.com/google-gemini/gemini-cli/blob/dadd606c0de07de4e372304eb93839ae12ec3465/.gcp/Dockerfile.gemini-code-builder

## 已知问题与解决方案

### JavaScript 调试器的 autoAttachFilter 问题

在 Dev Container 中使用 JavaScript 调试器时，`autoAttachFilter` 设置存在以下问题：

<details>
<summary>问题详情与解决方案</summary>

**问题描述：**

- `autoAttachFilter` 会在 `NODE_OPTIONS` 中注入 `bootloader.js` 的 `--require` 参数
- 并错误地重复拼接 `--max-old-space-size`，形成类似：
  ```
  NODE_OPTIONS= --require /home/.../bootloader.js  --max-old-space-size=4096--max-old-space-size=4096
  ```
- 导致启动时报错：
  ```
  Error: illegal value for flag --max-old-space-size=4096--max-old-space-size=4096 of type size_t
  ```

**解决方案：**
在 `devcontainer.json` 中将 `debug.javascript.autoAttachFilter` 设置为 `"disabled"` 以规避该问题：

```jsonc
"debug.javascript.autoAttachFilter": "disabled"
```

</details>

**相关参考：**

- https://stackoverflow.com/questions/75708866/vscode-dev-container-fails-to-load-ms-vscode-js-debug-extension-correctly
- https://davidwesst.com/blog/missing-bootloader-in-vscode-devcontainer/

## macOS 主机配置

### synthetic.conf 创建合成固定链接

macOS 不允许直接在根目录 `/` 下创建文件夹，`/etc/synthetic.conf` 可以绕过这个限制，在 `/` 下创建指向实际目录的链接。这样容器内的路径（如 `/vscode`、`/workspaces`）在 Mac 主机上也能直接使用：

```shell
printf "vscode\tUsers/y25/OrbStack/docker/volumes/vscode\nworkspaces\t/Users/y25/Workspaces\n" | \
sudo tee -a /etc/synthetic.conf > /dev/null
```

- `-a`：追加模式，不覆盖已有内容
- 修改后需重启 macOS 生效
- 效果：
  - `/vscode` → `Users/y25/OrbStack/docker/volumes/vscode`
  - `/workspaces` → `/Users/y25/Workspaces`

## 一些资料

- https://github.com/agent-infra/sandbox
