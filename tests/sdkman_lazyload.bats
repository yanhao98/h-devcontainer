#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
    export SDKMAN_LAZYLOAD_PATH="$BATS_TEST_DIRNAME/../.devcontainer/_build-context/rootfs/devcontainer/sdkman-lazyload.sh"
    export SDKMAN_BIN_SHIM="$BATS_TEST_DIRNAME/../.devcontainer/_build-context/rootfs/usr/local/bin-priority/sdk"
    export SDKMAN_DIR="$BATS_TMPDIR/sdkman"
    export MOCK_BIN="$BATS_TMPDIR/bin"
    rm -rf "$SDKMAN_DIR" "$MOCK_BIN"
    mkdir -p "$SDKMAN_DIR/bin" "$MOCK_BIN"
    export SDKMAN_SETUP_BIN="$MOCK_BIN/h-setup-sdkman-bin"
    export PATH="$MOCK_BIN:$PATH"
}

write_fake_sdkman_init() {
    cat > "$SDKMAN_DIR/bin/sdkman-init.sh" <<'EOF'
count_file="$SDKMAN_DIR/source-count"
: "${SDKMAN_CANDIDATES_API}"
count=0
if [ -f "$count_file" ]; then
    count="$(cat "$count_file")"
fi
printf '%s\n' "$((count + 1))" > "$count_file"

sdk() {
    if [ -n "$2" ]; then
        :
    fi
    printf 'real sdk:%s\n' "$*"
}
EOF
}

@test "sdkman lazyload does not source SDKMAN during shell startup" {
    write_fake_sdkman_init

    source "$SDKMAN_LAZYLOAD_PATH"

    [ ! -f "$SDKMAN_DIR/source-count" ]
    run sdk version

    [ "$status" -eq 0 ]
    [ "$output" = "real sdk:version" ]
    [ "$(cat "$SDKMAN_DIR/source-count")" = "1" ]
}

@test "sdkman lazyload installs SDKMAN on first sdk call when missing" {
    cat > "$SDKMAN_SETUP_BIN" <<'EOF'
#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

echo "installer stdout"
echo "installer stderr" >&2
mkdir -p "$SDKMAN_DIR/bin"
cat > "$SDKMAN_DIR/bin/sdkman-init.sh" <<'INITEOF'
sdk() {
    printf 'installed sdk:%s\n' "$*"
}
INITEOF
EOF
    chmod +x "$SDKMAN_SETUP_BIN"

    source "$SDKMAN_LAZYLOAD_PATH"

    run --separate-stderr sdk list java

    [ "$status" -eq 0 ]
    [ "$output" = "installed sdk:list java" ]
    [[ "$stderr" == *"installer stdout"* ]]
    [[ "$stderr" == *"installer stderr"* ]]
}

@test "sdk executable fallback works from plain sh command lookup" {
    write_fake_sdkman_init

    run sh -c 'PATH="$1:$PATH" sdk version' sh "$(dirname "$SDKMAN_BIN_SHIM")"

    [ "$status" -eq 0 ]
    [ "$output" = "real sdk:version" ]
}

@test "sdkman installer does not precreate SDKMAN_DIR before upstream script" {
    installer_path="$BATS_TEST_DIRNAME/../.devcontainer/_build-context/rootfs/usr/local/bin/h-setup-sdkman-bin"
    rm -rf "$SDKMAN_DIR"

    cat > "$MOCK_BIN/_curl-fsSL--compressed" <<'EOF'
#!/usr/bin/env bash
cat <<'INSTALLER'
if [ -d "$SDKMAN_DIR" ]; then
    echo "SDKMAN found without init" >&2
    exit 42
fi
mkdir -p "$SDKMAN_DIR/bin"
cat > "$SDKMAN_DIR/bin/sdkman-init.sh" <<'INITEOF'
sdk() { printf 'sdk:%s\n' "$*"; }
INITEOF
INSTALLER
EOF
    chmod +x "$MOCK_BIN/_curl-fsSL--compressed"

    run --separate-stderr "$installer_path"

    [ "$status" -eq 0 ]
    [ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]
    [[ "$stderr" != *"SDKMAN found without init"* ]]
}
