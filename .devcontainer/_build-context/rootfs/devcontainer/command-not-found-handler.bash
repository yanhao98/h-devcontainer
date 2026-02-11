#!/bin/bash
# command_not_found_handle: 记录所有尝试使用但未安装的命令 (bash 版本)
#
# bash 在找不到命令时会自动调用此函数。
# 通过 BASH_ENV 环境变量加载，非交互式 bash（如 agent tool 调用）也会生效。
# 日志文件: /vscode/logs/command-not-found.log

command_not_found_handle() {
    local cmd="$1"
    shift
    local args="$*"
    local log_file="/vscode/logs/command-not-found.log"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    # 确保日志目录存在
    mkdir -p "$(dirname "$log_file")" 2>/dev/null

    # 记录到日志文件: 时间戳 | 命令 | 参数 | 工作目录 | 调用者
    echo "${timestamp} | cmd=${cmd} | args=${args} | pwd=${PWD} | caller=${BASH_SOURCE[1]:-interactive}" >> "$log_file"

    # 向用户显示提示信息
    echo "bash: command not found: ${cmd}" >&2

    return 127
}
