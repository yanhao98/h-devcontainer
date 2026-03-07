builtin source /devcontainer/command-not-found-handler.zsh

# 以下内容仅交互式 shell 需要（本文件通过 zshenv 加载，对所有 zsh 实例生效）
if [[ -o interactive ]]; then

# >>>>> VS Code Shell Integration
[[ "$TERM_PROGRAM" == "vscode" ]] && . "$(code --locate-shell-integration-path zsh)"
# <<<<< VS Code Shell Integration

# >>>>> 自定义别名
alias clean-node-modules='setopt rm_star_silent; rm -rf node_modules/.*; rm -rf node_modules/*; unsetopt rm_star_silent'
# <<<<< 自定义别名

fi
