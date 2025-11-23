#!/bin/bash -eu

h-00-fix-permissions

LIFECYCLE_EVENT="$1"
if [ -z "$LIFECYCLE_EVENT" ]; then
    echo "错误: 请指定生命周期事件名称"
    exit 1
fi

# 支持带数字前缀的目录名（如 01-onCreateCommand.d）
USER_SCRIPTS_DIR=$(find /usr/local/etc/lifecycle-scripts.d -maxdepth 1 -type d -name "*-${LIFECYCLE_EVENT}.d" | head -n 1)

if [ -n "$USER_SCRIPTS_DIR" ] && [ -d "$USER_SCRIPTS_DIR" ]; then
    if [ -n "$(ls -A "$USER_SCRIPTS_DIR")" ]; then
        # echo "--- 赋予用户自定义脚本可执行权限 ---"
        chmod +x "$USER_SCRIPTS_DIR"/*
        echo "🚀 --- 开始执行 ${LIFECYCLE_EVENT} 用户自定义脚本: $USER_SCRIPTS_DIR ---"
        run-parts --verbose "$USER_SCRIPTS_DIR"
        echo "✔️ --- ${LIFECYCLE_EVENT} 用户自定义脚本执行完毕 ---"
    else
        echo "--- ${LIFECYCLE_EVENT} 用户自定义脚本目录 $USER_SCRIPTS_DIR 为空，跳过执行 ---"
    fi
else
    echo "--- ${LIFECYCLE_EVENT} 用户自定义脚本目录不存在，跳过执行 ---"
fi
