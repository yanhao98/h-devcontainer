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

escape_sed_replacement() {
    printf '%s' "${1:-}" | sed 's/[|&\\]/\\&/g'
}

exec_self_as_root_if_needed() {
    if [ "$(id -u)" -eq 0 ]; then
        return
    fi

    echo "🔐 ENTRYPOINT 初始用户: $(id -un) (uid=$(id -u), gid=$(id -g))，通过 sudo 切换到 root 启动 supervisord..." >&2
    exec sudo "$0" "$@"
}

prepare_supervisor_runtime() {
    echo "📁 准备 supervisord 运行目录..." >&2
    install -d -o root -g usr_vscode -m 0775 /var/log/supervisor
    install -d -o root -g root -m 0755 /etc/supervisor/conf.d.enabled
    rm -f /var/run/supervisor.sock /var/run/supervisord.pid
    find /etc/supervisor/conf.d.enabled -maxdepth 1 -type f -name '*.conf' -delete
    find /etc/supervisor/conf.d.enabled -maxdepth 1 -type l -name '*.conf' -delete
}

configure_supervisor_http_panel() {
    local http_conf="/etc/supervisor/conf.d.enabled/00-inet-http-server.conf"
    local template_conf="/etc/supervisor/conf.d.available/00-inet-http-server.conf.tpl"
    local host="${SUPERVISOR_HTTP_HOST:-0.0.0.0}"
    local port="${SUPERVISOR_HTTP_PORT:-9100}"
    local username="${SUPERVISOR_HTTP_USERNAME-}"
    local password="${SUPERVISOR_HTTP_PASSWORD-}"
    local rendered_username=""
    local rendered_password=""
    local tmp_conf

    rm -f "$http_conf"

    if ! is_truthy "${SUPERVISOR_HTTP_ENABLED:-true}"; then
        echo "ℹ️  已禁用 Supervisord HTTP 控制面板。" >&2
        return
    fi

    if [ ! -f "$template_conf" ]; then
        echo "❌ 未找到 Supervisord HTTP 面板模板: $template_conf" >&2
        return 1
    fi

    if [ -n "$username" ] && [ -n "$password" ]; then
        rendered_username="$username"
        rendered_password="$password"
    elif [ -n "$username" ] || [ -n "$password" ]; then
        echo "⚠️  SUPERVISOR_HTTP_USERNAME 和 SUPERVISOR_HTTP_PASSWORD 必须同时为非空；当前按无认证处理。" >&2
    fi

    tmp_conf="$(mktemp)"
    sed \
        -e "s|@SUPERVISOR_HTTP_HOST@|$(escape_sed_replacement "$host")|g" \
        -e "s|@SUPERVISOR_HTTP_PORT@|$(escape_sed_replacement "$port")|g" \
        -e "s|@SUPERVISOR_HTTP_USERNAME@|$(escape_sed_replacement "$rendered_username")|g" \
        -e "s|@SUPERVISOR_HTTP_PASSWORD@|$(escape_sed_replacement "$rendered_password")|g" \
        "$template_conf" > "$tmp_conf"
    install -o root -g root -m 0644 "$tmp_conf" "$http_conf"
    rm -f "$tmp_conf"

    if [ -n "$rendered_username" ]; then
        echo "✅ 已启用 Supervisord HTTP 控制面板: http://${host}:${port} (需要登录)" >&2
    else
        echo "✅ 已启用 Supervisord HTTP 控制面板: http://${host}:${port} (无需登录)" >&2
    fi
}

enable_builtin_supervisor_services() {
    local available_dir="/etc/supervisor/conf.d.available"
    local enabled_dir="/etc/supervisor/conf.d.enabled"
    local service_conf
    local service_name
    local service_list="${SUPERVISOR_ENABLED_SERVICES:-}"
    local service_user
    local conf_line
    service_list="${service_list//,/ }"

    if [ -z "${service_list//[[:space:]]/}" ]; then
        echo "ℹ️  未启用任何内置 Supervisord 服务。" >&2
        return
    fi

    for service_name in $service_list; do
        service_conf="${available_dir}/${service_name}.conf"
        if [ ! -f "$service_conf" ]; then
            echo "⚠️  未找到内置服务配置: ${service_name}" >&2
            continue
        fi

        service_user=""
        while IFS= read -r conf_line; do
            case "$conf_line" in
                user=*)
                    service_user="${conf_line#user=}"
                    service_user="${service_user%%[[:space:];#]*}"
                    break
                    ;;
            esac
        done < "$service_conf"

        ln -sf "$service_conf" "${enabled_dir}/${service_name}.conf"
        if [ -n "$service_user" ]; then
            echo "✅ 已启用内置服务: ${service_name} (运行用户: ${service_user})" >&2
        else
            echo "✅ 已启用内置服务: ${service_name}" >&2
        fi
    done
}

main() {
    if [ "$#" -gt 0 ]; then
        echo "容器已启动" >&2
        echo "👤 ENTRYPOINT 当前用户: $(id -un) (uid=$(id -u), gid=$(id -g))" >&2
        echo "➡️  检测到启动命令，直接执行: $*" >&2
        exec "$@"
    fi

    exec_self_as_root_if_needed "$@"

    echo "容器已启动" >&2
    echo "👤 ENTRYPOINT 当前用户: $(id -un) (uid=$(id -u), gid=$(id -g))" >&2

    prepare_supervisor_runtime
    configure_supervisor_http_panel
    enable_builtin_supervisor_services

    echo "🚀 交由 supervisord 接管容器主进程..." >&2
    exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
}

main "$@"
