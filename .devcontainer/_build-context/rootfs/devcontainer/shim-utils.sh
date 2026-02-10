#!/bin/bash
# shim 脚本共享工具函数

# 输出调用者信息（用于调试 shim 调用链）
# 用法: _print_caller_info
_print_caller_info() {
    # 在函数内部关闭 errexit，避免 ps/test 等非零退出导致整体脚本中断
    local _errexit_state
    _errexit_state=$(set -o | awk '/errexit/ {print $2}')
    set +o errexit

    local pid=$PPID
    local chain=""
    local cmd args
    local max_depth=5
    local depth=0

    while [ $depth -lt $max_depth ] && [ "$pid" != "1" ] && [ -n "$pid" ]; do
        cmd="$(ps -o comm= -p $pid 2>/dev/null)" || break
        [ -z "$cmd" ] && break
        
        if [ -z "$chain" ]; then
            args="$(ps -o args= -p $pid 2>/dev/null | head -c 100)" || args=""
            chain="$cmd(pid=$pid)"
            [ -n "$args" ] && chain="$chain\n\e[90m  args: $args\e[0m"
        else
            chain="$cmd($pid) → $chain"
        fi
        
        pid="$(ps -o ppid= -p $pid 2>/dev/null | tr -d ' ')" || break
        ((depth++))
    done

    echo -e "\e[90m────────────────────────────────────────────────────────────\e[0m" >&2
    echo -e "\e[90m← $chain\e[0m" >&2

    # 恢复之前的 errexit 状态
    [ "$_errexit_state" = "on" ] && set -o errexit
}
