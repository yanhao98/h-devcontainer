#!/bin/bash
set -euo pipefail

echo '↘️ 容器已创建！'

h-setup-zh-locale

h-setup-bun-bin
h-setup-pnpm-bin

h-setup-ai-claude-code --config
h-setup-ai-gemini-cli --config

# h-smart-install-node-modules

h-setup-desktop-lite

echo "✅ 容器初始化脚本执行完毕。"

# 保持容器运行
exec sleep infinity
