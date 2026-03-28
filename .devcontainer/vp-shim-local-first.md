# `vp` shim 需要 local-first 的原因

## 问题现象

在某些项目中，直接运行：

```bash
vp test
```

会失败，但改成：

```bash
./node_modules/.bin/vp test
```

却可以通过。

这不是项目测试本身坏了，而是 `/usr/local/bin-priority/vp` 这个 shim 的执行策略有问题。

## 复现条件

满足下面几个条件时最容易触发：

1. 项目本地安装了 `vite-plus`
2. 项目测试依赖里用了 `jsdom` 或 `happy-dom`
3. `vp test` 通过 `vite-plus-test` 在运行时动态加载这些包
4. 全局 `/vscode/bun-priority-bin` 里只有 `vite-plus`，但没有项目本地那套 peer 依赖

典型报错是：

```text
Cannot find package 'jsdom' imported from /vscode/bun-priority-bin/node_modules/@voidzero-dev/vite-plus-test/...
```

## 根因

原来的 `vp` shim 逻辑是：

1. 调用 `add-bun-priority-bin-pkg vite-plus`
2. 强制执行 `/vscode/bun-priority-bin/node_modules/.bin/vp`

这样会把命令固定绑定到全局安装的 `vite-plus`。

问题在于 `vite-plus-test` 把 `jsdom` 和 `happy-dom` 声明成 optional peer dependencies，并且会在运行时动态 `import('jsdom')` / `import('happy-dom')`。  
当 `vp test` 由全局 `/vscode/bun-priority-bin` 下的 `vite-plus` 启动时，模块解析会优先从那套全局安装位置出发，而不是从当前项目的 `node_modules` 出发。

结果就是：

- 项目本地 `jsdom` 明明存在
- 但全局 `vite-plus-test` 仍然解析不到
- `vp test` 失败
- `./node_modules/.bin/vp test` 却正常

## 为什么只改 `vp`

不是所有 npm shim 都应该改成 local-first。

`vp` 是项目工具链入口，语义上本来就应该优先使用当前项目安装的版本。它和下面这些命令不一样：

- `codex`
- `claude`
- `gemini`
- `qwen`
- `cowsay`
- `skills`

这些命令更像全局 CLI，自带运行时，通常不依赖当前项目的 peer dependency 图。

`vp` 则明显属于项目级命令：

- 会读取项目里的 `vite.config.ts`
- 会使用项目里的 `node_modules`
- 会运行项目测试
- 会受到项目本地依赖版本影响

所以 `vp` 需要 local-first，其他 shim 不应该因为这个问题被一刀切修改。

## 修复策略

`vp` shim 现在改成：

1. 从当前目录开始，向上查找最近的 `node_modules/.bin/vp`
2. 如果找到，优先执行项目本地 `vp`
3. 如果找不到，再回退到 `/vscode/bun-priority-bin` 的全局安装

这样可以同时满足两类场景：

- 在项目目录里运行 `vp` 时，走项目本地依赖图
- 在没有本地 `vite-plus` 的目录里运行 `vp` 时，仍然可以自动安装并使用全局版本

## 受影响文件

- 源码：`.devcontainer/_build-context/rootfs/usr/local/bin-priority/vp`
- 同步目标：`/usr/local/bin-priority/vp`

同步方式：

```bash
scripts/cp-bins
```

## 验证方式

在一个安装了本地 `vite-plus` 的项目里验证：

```bash
vp --version
vp check
vp test
```

期望行为：

- `vp` 输出里应优先显示执行的是项目本地 `node_modules/.bin/vp`
- `vp check` 正常通过
- `vp test` 不再因为 `jsdom` / `happy-dom` 缺失而失败

## 结论

这个问题本质上不是 `vite-plus` 配置错误，而是 shim 层把一个项目级命令错误地强制成了全局命令。

对于 `vp`，正确策略是：

- 优先项目本地
- 回退全局

这也是后续新增类似项目级 shim 时应该复用的判断标准。
