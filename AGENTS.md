# AI Agent 编码规范

## Shell 脚本规范

### 输出重定向规则

1. **不要丢弃子脚本或命令的输出**：保留输出可见性，同时不污染 stdout——将输出重定向到 stderr (`>&2`)，而不是丢弃到 `/dev/null`。

   ```bash
   # ❌ 错误：丢弃输出（调试信息完全丢失）
   _verify_checksum "$file" "$checksum" 2>/dev/null
   some_command &>/dev/null

   # ✅ 正确：重定向到 stderr（保持 stdout 干净，同时输出仍可见）
   _verify_checksum "$file" "$checksum" >&2
   some_command >&2
   ```

2. **允许丢弃输出的例外情况**：
   - `grep -q` 检查文件内容时（文件可能不存在）：`grep -q 'pattern' file 2>/dev/null`
   - `dpkg --status` 检查包是否安装时（只关心退出码）
   - `nohup ... &` 后台进程
   - `tee > /dev/null` 避免重复输出到终端

3. **脚本中的所有用户提示信息都应输出到 stderr**：
   ```bash
   echo "🔍 正在获取版本信息..." >&2
   echo "✅ 安装成功" >&2
   ```

## bin-priority 目录

`/usr/local/bin-priority` 目录用于存放**按需自动安装**的脚本，优先级高于系统 PATH。

### 目的

当用户第一次运行某个命令时，如果该工具未安装，脚本会自动安装它，然后转发执行真正的二进制文件。用户无需手动安装，直接使用命令即可触发自动安装。

### 脚本类型

1. **纯 shim 垫片**：只做安装 + 转发
   - 示例：`bun`、`pnpm`、`node`、`uv`、`uvx`
   - 使用 `_exec-real-bin` 查找并执行真实二进制文件
   - 使用 `h-setup-*-bin` 脚本安装

2. **包装器/启动器**：安装 npm 包 + 额外配置/参数处理 + 执行
   - 示例：`claude`、`gemini`、`codex`、`qwen`、`iflow`、`opencode`
   - 使用 `add-bun-priority-bin-pkg` 安装 npm 包到 `/vscode/bun-priority-bin/`
   - 使用 `bun --bun run` 执行
   - 可能包含配置初始化、环境变量设置等额外逻辑

### 分组边框机制

`_print_caller_info` 会打印顶部边框 `╭──╮`，`_print_group_end` 打印底部边框 `╰──╯`，使每次 shim 调用的输出形成一个视觉整体。

- **纯 shim 垫片**：`_exec-real-bin` 会自动调用 `_print_group_end`，无需手动处理
- **包装器/启动器**：如果使用了 `_print_caller_info` 但不通过 `_exec-real-bin` 执行，需在 `exec` 前手动调用 `_print_group_end`
- **异常退出**：`_print_caller_info` 设置了 EXIT trap，脚本错误退出时会自动关闭边框
- **嵌套调用**：当 shim 在另一个 shim 内部被触发时，自动使用 `┄┄┄` 虚线分隔（而非新开盒子），子 shim 的输出合并在父级盒子内

### 编写新的 shim 脚本

参考模板（仅适用于**纯 shim 垫片**，不适用于包装器/启动器）：
```bash
#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

# <tool> shim: 自动检测并安装 <tool>，然后执行

source /devcontainer/shim-utils.sh
_print_caller_info

<tool>_bin="$(_get-real-bin --silent <tool>)"

if [ -z "$<tool>_bin" ]; then
    echo "⚠️  <tool> 未安装，正在自动安装..." >&2
    h-setup-<tool>-bin >&2
fi

exec _exec-real-bin <tool> "$@"
```
