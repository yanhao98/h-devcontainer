#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

is_truthy() {
    case "${1:-}" in
        1|true|TRUE|yes|YES|on|ON)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

prepare_supervisor_runtime() {
    echo "📁 准备 supervisord 运行目录..." >&2
    sudo install -d -o root -g usr_vscode -m 0775 /var/log/supervisor
    sudo install -d -o root -g root -m 0755 /etc/supervisor/conf.d.enabled
    sudo rm -f /var/run/supervisor.sock /var/run/supervisord.pid
    sudo find /etc/supervisor/conf.d.enabled -maxdepth 1 -type f -name '*.conf' -delete
    sudo find /etc/supervisor/conf.d.enabled -maxdepth 1 -type l -name '*.conf' -delete
}

configure_supervisor_http_panel() {
    local http_conf="/etc/supervisor/conf.d.enabled/00-inet-http-server.conf"
    local host="${SUPERVISOR_HTTP_HOST:-0.0.0.0}"
    local port="${SUPERVISOR_HTTP_PORT:-9001}"
    local username="${SUPERVISOR_HTTP_USERNAME:-usr_vscode}"
    local password="${SUPERVISOR_HTTP_PASSWORD:-devcontainer}"
    local tmp_conf

    sudo rm -f "$http_conf"

    if ! is_truthy "${SUPERVISOR_HTTP_ENABLED:-true}"; then
        echo "ℹ️  已禁用 Supervisord HTTP 控制面板。" >&2
        return
    fi

    tmp_conf="$(mktemp)"
    cat > "$tmp_conf" <<EOF
[inet_http_server]
port=${host}:${port}
username=${username}
password=${password}
EOF
    sudo install -o root -g root -m 0644 "$tmp_conf" "$http_conf"
    rm -f "$tmp_conf"

    echo "✅ 已启用 Supervisord HTTP 控制面板: http://${host}:${port}" >&2
}

enable_builtin_supervisor_services() {
    local available_dir="/etc/supervisor/conf.d.available"
    local enabled_dir="/etc/supervisor/conf.d.enabled"
    local service_name
    local service_list="${SUPERVISOR_ENABLED_SERVICES:-}"
    service_list="${service_list//,/ }"

    if [ -z "${service_list//[[:space:]]/}" ]; then
        echo "ℹ️  未启用任何内置 Supervisord 服务。" >&2
        return
    fi

    for service_name in $service_list; do
        if [ ! -f "${available_dir}/${service_name}.conf" ]; then
            echo "⚠️  未找到内置服务配置: ${service_name}" >&2
            continue
        fi

        sudo ln -sf "${available_dir}/${service_name}.conf" "${enabled_dir}/${service_name}.conf"
        echo "✅ 已启用内置服务: ${service_name}" >&2
    done
}

main() {
    echo "容器已启动" >&2

    if [ "$#" -gt 0 ]; then
        echo "➡️  检测到启动命令，直接执行: $*" >&2
        exec "$@"
    fi

    prepare_supervisor_runtime
    configure_supervisor_http_panel
    enable_builtin_supervisor_services

    echo "🚀 交由 supervisord 接管容器主进程..." >&2
    exec sudo /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
}

main "$@"
