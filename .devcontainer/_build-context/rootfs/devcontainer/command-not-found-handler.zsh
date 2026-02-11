#!/bin/zsh
# command_not_found_handler: 记录所有尝试使用但未安装的命令
#
# zsh 在找不到命令时会自动调用此函数。
# 日志文件: /vscode/logs/command-not-found.log

# 去重列表
# sort /vscode/logs/command-not-found.log | uniq

# 使用频率
# sort /vscode/logs/command-not-found.log | uniq -c | sort -rn

command_not_found_handler() {
    local cmd="$1"
    shift
    local args="$*"
    local log_file="/vscode/logs/command-not-found.log"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    # 确保日志目录存在
    mkdir -p "$(dirname "$log_file")" 2>/dev/null

    # 记录到日志文件: 时间戳 | 命令 | 参数 | 工作目录 | 调用者
    echo "${timestamp} | cmd=${cmd} | args=${args} | pwd=${PWD} | caller=${funcfiletrace[1]:-interactive}" >> "$log_file"

    # 向用户显示提示信息
    echo "zsh: command not found: ${cmd}" >&2
    echo "  💡 已记录到 ${log_file}" >&2

    return 127
}
