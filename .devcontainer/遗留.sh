#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

# 从 PATH 中移除当前脚本所在的目录，防止无限递归
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 同时移除 /usr/local/bin-priority，因为这是安装后的位置
export PATH=$(echo "$PATH" | sed "s|$SCRIPT_DIR||g; s|/usr/local/bin-priority||g; s|::|:|g; s|^:||; s|:$||")

# -----

# https://github.com/devcontainers/features/blob/b0188f0a5ef98f1c3217b6c0fe14c3ee472fad68/src/common-utils/main.sh#L353
# Ensure that login shells get the correct path if the user updated the PATH using ENV.
rm -f /etc/profile.d/00-restore-env.sh
echo "export PATH=${PATH//$(sh -lc 'echo $PATH')/\$PATH}" > /etc/profile.d/00-restore-env.sh
chmod +x /etc/profile.d/00-restore-env.sh