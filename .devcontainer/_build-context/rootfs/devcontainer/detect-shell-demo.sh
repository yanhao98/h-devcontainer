#!/bin/zsh

echo "=== 判断 shell 的不同方式 ==="

echo ""
echo "1) \$SHELL = $SHELL"
echo "   → /etc/passwd 中的 login shell（用户偏好，不是当前 shell）"

echo ""
echo "2) \$0 = $0"
echo "   → 当前脚本名或 shell 名（交互式时是 shell，脚本中是脚本路径）"

echo ""
echo "3) \$\$ = $$, /proc/\$\$/exe → $(readlink /proc/$$/exe 2>/dev/null || echo 'N/A (非 Linux)')"
echo "   → 当前进程实际执行的二进制"

echo ""
echo "4) \$BASH_VERSION = ${BASH_VERSION:-未设置}"
echo "   \$ZSH_VERSION  = ${ZSH_VERSION:-未设置}"
echo "   → 各 shell 的专属变量，只在对应 shell 中有值"

echo ""
parent_cmd=$(ps -o comm= -p $PPID 2>/dev/null || echo 'N/A')
echo "5) 父进程 (PPID=$PPID) = $parent_cmd"
echo "   → docker exec 直接执行时父进程不是 shell"
