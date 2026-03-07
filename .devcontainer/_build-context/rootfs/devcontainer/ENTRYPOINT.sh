#!/bin/zsh

echo "容器已启动"

h-setup-desktop-lite

# 收到 SIGTERM 时优雅退出
trap "exit 0" TERM

# 有参数时执行传入的命令
if (( $# > 0 )); then
    exec "$@"
fi

echo "✅ 入口脚本执行完毕，保持容器运行中..."

# 无参数时保持容器存活，同时响应信号
while sleep 1 & wait $!; do :; done
