#!/bin/bash
# bash-env.sh: BASH_ENV 入口文件
# 非交互式 bash 启动时自动 source 此文件

# zsh 没有 ZSH_ENV 这个概念。                                                                    
#   zsh 的启动文件加载顺序是固定的：                                                                     
#   1. /etc/zshenv → 全局，所有 zsh 实例都会加载（包括非交互式）                                         
#   2. ~/.zshenv → 用户级，同上                  
#   3. /etc/zshprofile → 登录 shell                                                             
#   4. ~/.zshprofile → 登录 shell                
#   5. /etc/zshrc → 交互式 shell
#   6. ~/.zshrc → 交互式 shell
# 现问题 — Debian 的 zsh 读的是 /etc/zsh/zshenv，不是 /etc/zshenv


source /devcontainer/command-not-found-handler.bash
