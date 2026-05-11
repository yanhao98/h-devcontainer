# sdkman-lazyload.sh: expose sdk as a lightweight lazy-loaded shell function.

if [ -n "${__SDKMAN_LAZYLOAD_SH:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
__SDKMAN_LAZYLOAD_SH=1

_sdkman_lazyload_init() {
    export SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"

    if [ ! -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]; then
        echo "⚠️  SDKMAN 未安装，正在自动安装..." >&2
        sdkman_setup_bin="${SDKMAN_SETUP_BIN:-/usr/local/bin/h-setup-sdkman-bin}"
        if ! "$sdkman_setup_bin" >&2; then
            return 1
        fi
    fi

    if [ ! -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]; then
        echo "❌ SDKMAN 初始化脚本不存在: $SDKMAN_DIR/bin/sdkman-init.sh" >&2
        return 1
    fi

    unset -f sdk 2>/dev/null || unfunction sdk 2>/dev/null || true
    case "$-" in
        *u*) sdkman_had_nounset=1 ;;
        *) sdkman_had_nounset=0 ;;
    esac
    # shellcheck disable=SC1091
    set +u
    if ! source "$SDKMAN_DIR/bin/sdkman-init.sh"; then
        if [ "$sdkman_had_nounset" = "1" ]; then
            set -u
        fi
        return 1
    fi
    if [ "$sdkman_had_nounset" = "1" ]; then
        set -u
    fi
}

sdk() {
    _sdkman_lazyload_init || return $?
    case "$-" in
        *u*) sdkman_had_nounset=1 ;;
        *) sdkman_had_nounset=0 ;;
    esac
    set +u
    sdk "$@"
    sdkman_status=$?
    if [ "$sdkman_had_nounset" = "1" ]; then
        set -u
    fi
    return "$sdkman_status"
}
