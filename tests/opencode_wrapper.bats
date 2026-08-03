#!/usr/bin/env bats

setup() {
    export WRAPPER_SOURCE="$BATS_TEST_DIRNAME/../.devcontainer/_build-context/rootfs/usr/local/bin-priority/opencode"
    export PACKAGE_ROOT="$BATS_TEST_TMPDIR/package-root"
    export MOCK_BIN="$BATS_TEST_TMPDIR/mock-bin"
    export HOME="$BATS_TEST_TMPDIR/home"
    export OPENCODE_TEST_UPDATE_LOG="$BATS_TEST_TMPDIR/update.log"
    export OPENCODE_TEST_META_VERSION="9.8.7"
    export PATH="$MOCK_BIN:$PATH"

    mkdir -p "$PACKAGE_ROOT/node_modules/.bin" "$MOCK_BIN" "$HOME"
    cp "$WRAPPER_SOURCE" "$BATS_TEST_TMPDIR/opencode"
    sed -i "s|/vscode/bun-priority-bin|$PACKAGE_ROOT|g" "$BATS_TEST_TMPDIR/opencode"
    chmod +x "$BATS_TEST_TMPDIR/opencode"
    export TEST_WRAPPER="$BATS_TEST_TMPDIR/opencode"

    cat > "$PACKAGE_ROOT/package.json" <<EOF
{"dependencies":{"opencode-ai":"$OPENCODE_TEST_META_VERSION","opencode-linux-arm64":"stale","unrelated":"keep"}}
EOF

    cat > "$PACKAGE_ROOT/node_modules/.bin/opencode" <<'EOF'
#!/usr/bin/env bash
for argument in "$@"; do
    printf 'arg:<%s>\n' "$argument"
done
EOF
    chmod +x "$PACKAGE_ROOT/node_modules/.bin/opencode"

    cat > "$MOCK_BIN/add-bun-priority-bin-pkg" <<'UPDATEEOF'
#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

printf '%s\n' "$*" >> "$OPENCODE_TEST_UPDATE_LOG"
if [[ "${OPENCODE_TEST_UPDATE_FAIL:-0}" == "1" ]]; then
    echo "update failed" >&2
    exit 73
fi
if [ ! -f "$PACKAGE_ROOT/package.json" ]; then
    cat > "$PACKAGE_ROOT/package.json" <<EOF
{"dependencies":{"opencode-ai":"$OPENCODE_TEST_META_VERSION"}}
EOF
fi
if [ -n "${OPENCODE_TEST_ACTIVE_UPDATE_DIR:-}" ]; then
    if ! mkdir "$OPENCODE_TEST_ACTIVE_UPDATE_DIR"; then
        echo "concurrent update detected" >&2
        exit 91
    fi
    sleep "${OPENCODE_TEST_UPDATE_DELAY:-0}"
    rmdir "$OPENCODE_TEST_ACTIVE_UPDATE_DIR"
fi
UPDATEEOF
    chmod +x "$MOCK_BIN/add-bun-priority-bin-pkg"

    cat > "$MOCK_BIN/uname" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    -m) printf '%s\n' "${OPENCODE_TEST_ARCH:-aarch64}" ;;
    -s) printf 'Linux\n' ;;
esac
EOF
    chmod +x "$MOCK_BIN/uname"

    cat > "$MOCK_BIN/grep" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == "-qw avx2 /proc/cpuinfo" ]]; then
    exit "${OPENCODE_TEST_AVX2:-1}"
fi
exec /usr/bin/grep "$@"
EOF
    chmod +x "$MOCK_BIN/grep"

    cat > "$MOCK_BIN/_ensure-vscode-symlink" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$MOCK_BIN/_ensure-vscode-symlink"
}

@test "every ARM invocation updates main and platform packages together" {
    run "$TEST_WRAPPER" first
    [ "$status" -eq 0 ]
    run "$TEST_WRAPPER" second
    [ "$status" -eq 0 ]

    [ "$(wc -l < "$OPENCODE_TEST_UPDATE_LOG")" -eq 2 ]
    [ "$(cat "$OPENCODE_TEST_UPDATE_LOG")" = $'opencode-ai@latest opencode-linux-arm64@latest --no-cache --trust\nopencode-ai@latest opencode-linux-arm64@latest --no-cache --trust' ]
}

@test "legacy ARM dependency remains owned and is updated with the main package" {
    run "$TEST_WRAPPER" migrate

    [ "$status" -eq 0 ]
    grep -q '"unrelated":"keep"' "$PACKAGE_ROOT/package.json"
    grep -q 'opencode-linux-arm64@latest' "$OPENCODE_TEST_UPDATE_LOG"
}

@test "x64 with AVX2 updates the optimized platform package" {
    export OPENCODE_TEST_ARCH="x86_64"
    export OPENCODE_TEST_AVX2="0"

    run "$TEST_WRAPPER" x64

    [ "$status" -eq 0 ]
    [ "$(cat "$OPENCODE_TEST_UPDATE_LOG")" = "opencode-ai@latest opencode-linux-x64@latest --no-cache --trust" ]
}

@test "x64 without AVX2 updates the baseline platform package" {
    export OPENCODE_TEST_ARCH="x86_64"
    export OPENCODE_TEST_AVX2="1"

    run "$TEST_WRAPPER" x64-baseline

    [ "$status" -eq 0 ]
    [ "$(cat "$OPENCODE_TEST_UPDATE_LOG")" = "opencode-ai@latest opencode-linux-x64-baseline@latest --no-cache --trust" ]
}

@test "fresh package root skips migration and still updates" {
    rm -f "$PACKAGE_ROOT/package.json"

    run "$TEST_WRAPPER" fresh

    [ "$status" -eq 0 ]
    [ -f "$PACKAGE_ROOT/package.json" ]
    [ "$(cat "$OPENCODE_TEST_UPDATE_LOG")" = "opencode-ai@latest opencode-linux-arm64@latest --no-cache --trust" ]
    [[ "$output" == *"arg:<fresh>"* ]]
}

@test "updater failure prevents CLI execution" {
    export OPENCODE_TEST_UPDATE_FAIL="1"

    run "$TEST_WRAPPER" should-not-run

    [ "$status" -eq 73 ]
    [[ "$output" == *"update failed"* ]]
    [[ "$output" != *"arg:<should-not-run>"* ]]
}

@test "arguments reach the installed bin executable unchanged" {
    run "$TEST_WRAPPER" serve --port "8080 with spaces"

    [ "$status" -eq 0 ]
    [[ "$output" == *"arg:<serve>"* ]]
    [[ "$output" == *"arg:<--port>"* ]]
    [[ "$output" == *"arg:<8080 with spaces>"* ]]
}

@test "concurrent invocations serialize updates and both request latest" {
    export OPENCODE_TEST_ACTIVE_UPDATE_DIR="$BATS_TEST_TMPDIR/active-update"
    export OPENCODE_TEST_UPDATE_DELAY="0.1"

    "$TEST_WRAPPER" one > "$BATS_TEST_TMPDIR/one.out" 2>&1 &
    first_pid=$!
    "$TEST_WRAPPER" two > "$BATS_TEST_TMPDIR/two.out" 2>&1 &
    second_pid=$!
    wait "$first_pid"
    wait "$second_pid"

    [ "$(wc -l < "$OPENCODE_TEST_UPDATE_LOG")" -eq 2 ]
    ! grep -q 'concurrent update detected' "$BATS_TEST_TMPDIR/one.out"
    ! grep -q 'concurrent update detected' "$BATS_TEST_TMPDIR/two.out"
}
