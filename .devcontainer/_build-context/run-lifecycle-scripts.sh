#!/bin/bash -eu

h-00-fix-permissions

LIFECYCLE_EVENT="$1"
if [ -z "$LIFECYCLE_EVENT" ]; then
    echo "错误: 请指定生命周期事件名称"
    exit 1
fi

# 支持带数字前缀的目录名（如 01-onCreateCommand.d）以及 .local 后缀的本地目录
USER_SCRIPTS_DIRS=$(find /usr/local/etc/lifecycle-scripts.d -maxdepth 1 -type d \( -name "*-${LIFECYCLE_EVENT}.d" -o -name "*-${LIFECYCLE_EVENT}.d.local" \) | sort)

if [ -n "$USER_SCRIPTS_DIRS" ]; then
    for DIR in $USER_SCRIPTS_DIRS; do
        if [ -d "$DIR" ] && [ -n "$(ls -A "$DIR")" ]; then
            # echo "--- 赋予用户自定义脚本可执行权限 ---"
            chmod +x "$DIR"/*
            echo "🚀 --- 开始执行 ${LIFECYCLE_EVENT} 用户自定义脚本: $DIR ---"
            run-parts --verbose "$DIR"
            echo "✔️ --- ${LIFECYCLE_EVENT} 用户自定义脚本执行完毕 ($DIR) ---"
            echo ""
        else
            echo "--- ${LIFECYCLE_EVENT} 用户自定义脚本目录 $DIR 为空或不存在，跳过执行 ---"
        fi
    done
else
    echo "--- ${LIFECYCLE_EVENT} 用户自定义脚本目录不存在，跳过执行 ---"
fi
