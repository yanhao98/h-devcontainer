#!/bin/bash
#-------------------------------------------------------------------------------------------------------------
# desktop-init.sh: VNC 桌面环境启动脚本
# 由 ENTRYPOINT.sh 通过 h-setup-desktop-lite 以 nohup setsid 方式调用，作为守护进程运行
# 原始来源: https://github.com/devcontainers/features/blob/main/src/desktop-lite/install.sh
#-------------------------------------------------------------------------------------------------------------

user_name="usr_vscode"
group_name="usr_vscode"
LOG=/tmp/container-init.log

export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-"autolaunch:"}"
export DISPLAY="${DISPLAY:-:1}"
export VNC_RESOLUTION="${VNC_RESOLUTION:-1440x768}"
export LANG="${LANG:-"en_US.UTF-8"}"
export LANGUAGE="${LANGUAGE:-"en_US.UTF-8"}"

#=== 工具函数 ================================================================

# 如果进程未运行，则在后台启动并等待其就绪
startInBackgroundIfNotRunning()
{
    log "Starting $1."
    echo -e "\n** $(date) **" | sudoIf tee -a /tmp/$1.log > /dev/null
    if ! pgrep -x $1 > /dev/null; then
        keepRunningInBackground "$@"
        while ! pgrep -x $1 > /dev/null; do
            sleep 1
        done
        log "$1 started."
    else
        echo "$1 is already running." | sudoIf tee -a /tmp/$1.log > /dev/null
        log "$1 is already running."
    fi
}

# 在后台持续运行命令，退出后自动重启 (间隔 5 秒)
# 参数: $1=日志名, $2=提权方式(sudoIf/sudoUserIf), $3=实际命令
keepRunningInBackground()
{
    ($2 bash -c "while :; do echo [\$(date)] Process started.; $3; echo [\$(date)] Process exited!; sleep 5; done 2>&1" | sudoIf tee -a /tmp/$1.log > /dev/null & echo "$!" | sudoIf tee /tmp/$1.pid > /dev/null)
}

# 非 root 时自动加 sudo
sudoIf()
{
    if [ "$(id -u)" -ne 0 ]; then
        sudo "$@"
    else
        "$@"
    fi
}

# root 运行时降权到普通用户执行
sudoUserIf()
{
    if [ "$(id -u)" -eq 0 ] && [ "${user_name}" != "root" ]; then
        sudo -u ${user_name} "$@"
    else
        "$@"
    fi
}

log()
{
    echo -e "[$(date)] $@" | sudoIf tee -a $LOG > /dev/null
}

# 版本比较: $1 > $2 时返回 0
version_gt() {
    [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" != "$1" ]
}

#=== 启动流程 ================================================================

log "** SCRIPT START **"

# 1. 启动 D-Bus (桌面应用的进程间通信总线)
log 'Running "/etc/init.d/dbus start".'
if [ -f "/var/run/dbus/pid" ] && ! pgrep -x dbus-daemon  > /dev/null; then
    sudoIf rm -f /var/run/dbus/pid
fi
sudoIf /etc/init.d/dbus start 2>&1 | sudoIf tee -a /tmp/dbus-daemon-system.log > /dev/null
while ! pgrep -x dbus-daemon > /dev/null; do
    sleep 1
done

# 2. 启动 TigerVNC 服务器 (同时会拉起 fluxbox 窗口管理器)
sudoIf rm -rf /tmp/.X11-unix /tmp/.X*-lock
mkdir -p /tmp/.X11-unix
sudoIf chmod 1777 /tmp/.X11-unix
sudoIf chown root:${group_name} /tmp/.X11-unix
# VNC_RESOLUTION 格式: WxH 或 WxHxD，补全缺省色深为 24 位 (彩色 emoji 需要 24-bit)
if [ "$(echo "${VNC_RESOLUTION}" | tr -cd 'x' | wc -c)" = "1" ]; then VNC_RESOLUTION=${VNC_RESOLUTION}x24; fi
screen_geometry="${VNC_RESOLUTION%*x*}"
screen_depth="${VNC_RESOLUTION##*x}"
log "Resolved VNC settings: display=${DISPLAY}, geometry=${screen_geometry}, depth=${screen_depth}, dpi=${VNC_DPI:-96}"

# TigerVNC 出于安全考虑，拒绝在没有密码保护的情况下允许外部连接（非 localhost）。
# 允许非本地连接 VNC，并添加不安全连接确认标志
# 
# -localhost no: 允许非本地连接 (容器端口转发需要)
# --I-KNOW-THIS-IS-INSECURE: TigerVNC 要求显式确认非 localhost 连接的安全风险
common_options="tigervncserver ${DISPLAY} -geometry ${screen_geometry} -depth ${screen_depth} -rfbport 5901 -dpi ${VNC_DPI:-96} -localhost no --I-KNOW-THIS-IS-INSECURE -desktop fluxbox -fg"

if [ -n "${VNC_PASSWORD+x}" ]; then
    startInBackgroundIfNotRunning "Xtigervnc" sudoUserIf "${common_options} -passwd /usr/local/etc/vscode-dev-containers/vnc-passwd"
else
    startInBackgroundIfNotRunning "Xtigervnc" sudoUserIf "${common_options} -SecurityTypes None"
fi

# 3. 启动 dunst 通知守护进程 (notify-send 需要)
if command -v dunst > /dev/null 2>&1 && ! pgrep -x dunst > /dev/null; then
    sudoUserIf dunst &
    log "dunst started."
fi

# 5. 启动 noVNC (如果已安装): 提供浏览器 Web 端访问 VNC 的能力，监听 6080 端口
if [ -d "/usr/local/novnc" ]; then
    if [ "$(ps -ef | grep /usr/local/novnc/noVNC*/utils/launch.sh | grep -v grep)" = "" ] && [ "$(ps -ef | grep /usr/local/novnc/noVNC*/utils/novnc_proxy | grep -v grep)" = "" ]; then
        # noVNC >= 1.3.0 使用 novnc_proxy，旧版使用 launch.sh
        if version_gt "1.6.0" "1.2.0"; then
            keepRunningInBackground "noVNC" sudoIf "/usr/local/novnc/noVNC*/utils/novnc_proxy --listen 6080 --vnc localhost:5901"
            log "noVNC started with novnc_proxy."
        else
            keepRunningInBackground "noVNC" sudoIf "/usr/local/novnc/noVNC*/utils/launch.sh --listen 6080 --vnc localhost:5901"
            log "noVNC started with launch.sh."
        fi
    else
        log "noVNC is already running."
    fi
else
    log "noVNC is not installed."
fi

# 6. 如果传入了命令参数则执行
if [ -n "${1:-}" ]; then
    log "Executing \"$@\"."
    exec "$@"
else
    log "No command provided to execute."
fi
log "** SCRIPT EXIT **"
