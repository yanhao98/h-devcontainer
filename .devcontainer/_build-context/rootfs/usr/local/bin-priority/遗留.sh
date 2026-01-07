#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

# 从 PATH 中移除当前脚本所在的目录，防止无限递归
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 同时移除 /usr/local/bin-priority，因为这是安装后的位置
export PATH=$(echo "$PATH" | sed "s|$SCRIPT_DIR||g; s|/usr/local/bin-priority||g; s|::|:|g; s|^:||; s|:$||")
