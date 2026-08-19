#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
    export TEST_ROOT="$BATS_TMPDIR/rustup-shim-$BATS_TEST_NUMBER"
    export MOCK_DIR="$TEST_ROOT/mocks"
    export SCRIPTS_DIR="$TEST_ROOT/scripts"
    export CARGO_HOME="$TEST_ROOT/cargo"
    export MOCK_LOG="$TEST_ROOT/mock.log"
    export TARGET_LOG="$TEST_ROOT/target.log"
    export RUSTUP_LOG="$TEST_ROOT/rustup.log"
    mkdir -p "$MOCK_DIR" "$SCRIPTS_DIR" "$CARGO_HOME/bin"
    : > "$RUSTUP_LOG"

    cat > "$TEST_ROOT/shim-utils.sh" <<'SHIMEOF'
_print_caller_info() { printf 'caller info\n' >&2; }
_print_group_end() { :; }
SHIMEOF

    cat > "$MOCK_DIR/_get-real-bin" <<'MOCKEOF'
#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail
printf 'get-real-bin:%s\n' "$*" >> "$MOCK_LOG"
if [[ "${MOCK_MODE:-existing}" == missing ]]; then
    exit 0
fi
printf '%s/bin/%s\n' "$CARGO_HOME" "$2"
MOCKEOF

    cat > "$MOCK_DIR/_exec-real-bin" <<'MOCKEOF'
#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail
command_name="$1"
cargo_home="${CARGO_HOME:-$HOME/.cargo}"
shift
printf 'exec-real-bin:%s:%s\n' "$command_name" "$*" >> "$MOCK_LOG"
resolved="$(command -v "$command_name" || true)"
[[ "$resolved" == "$cargo_home/bin/$command_name" ]] || {
    printf 'target not visible through PATH: %s\n' "$command_name" >&2
    exit 127
}
exec "$resolved" "$@"
MOCKEOF

    cat > "$MOCK_DIR/h-setup-rustup-bin" <<'MOCKEOF'
#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail
if [[ "${INSTALLER_MODE:-success}" == fail ]]; then
    printf 'rustup installer failed\n' >&2
    exit 23
fi
bin_dir="${CARGO_HOME:-$HOME/.cargo}/bin"
mkdir -p "$bin_dir"
    for command_name in rustc cargo rustfmt cargo-clippy rust-analyzer clippy-driver cargo-fmt; do
    cat > "$bin_dir/$command_name" <<TARGETEOF
#!/bin/bash
printf 'target:%s\\n' "$command_name"
printf 'target:%s\\n' "$command_name" >> "$TARGET_LOG"
printf '%s\\n' "\$@"
TARGETEOF
    chmod +x "$bin_dir/$command_name"
done
    cat > "$bin_dir/rustup" <<'RUSTUPEOF'
#!/bin/bash
printf 'rustup argv:' >> "$RUSTUP_LOG"
printf '<%s>' "$@" >> "$RUSTUP_LOG"
printf '\n' >> "$RUSTUP_LOG"
if [[ "${RUSTUP_COMPONENT_MODE:-success}" == fail && "$1" == component ]]; then
    printf 'rustup component add failed\n' >&2
    exit 37
fi
if [[ "$1" == component && "$2" == add && "$3" == --toolchain && "$4" == stable ]]; then
    case "$5" in
        rust-analyzer) command_name=rust-analyzer ;;
        clippy) command_name=clippy-driver ;;
        rustfmt) command_name=cargo-fmt ;;
        *) exit 0 ;;
    esac
    cat > "${CARGO_HOME:-$HOME/.cargo}/bin/$command_name" <<TARGETEOF
#!/bin/bash
printf 'target:%s\n' "$command_name"
printf 'target:%s\n' "$command_name" >> "$TARGET_LOG"
printf '%s\n' "\$@"
TARGETEOF
    chmod +x "${CARGO_HOME:-$HOME/.cargo}/bin/$command_name"
    exit 0
fi
if [[ "$1" == --version ]]; then
    printf 'rustup 1.0.0\n'
else
    printf 'target:rustup\n'
    printf 'target:rustup\n' >> "$TARGET_LOG"
    printf '%s\n' "$@"
fi
RUSTUPEOF
    chmod +x "$bin_dir/rustup"
    for component in rust-analyzer clippy rustfmt; do
        "$bin_dir/rustup" component add --toolchain stable "$component"
    done
printf 'rustup installer output\n' >&2
MOCKEOF

    chmod +x "$MOCK_DIR"/*
    export PATH="$MOCK_DIR:$CARGO_HOME/bin:/usr/bin:/bin"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

prepare_shim() {
    local command_name="$1"
    export TEST_SCRIPT="$SCRIPTS_DIR/$command_name"
    local source="$BATS_TEST_DIRNAME/../.devcontainer/_build-context/rootfs/usr/local/bin-priority/$command_name"
    if [[ -f "$source" ]]; then
        cp "$source" "$TEST_SCRIPT"
        sed -i "s|source /devcontainer/shim-utils.sh|source $TEST_ROOT/shim-utils.sh|g" "$TEST_SCRIPT"
        chmod +x "$TEST_SCRIPT"
    fi
}

create_existing_targets() {
    local command_name
    for command_name in rustc cargo rustfmt cargo-clippy rust-analyzer clippy-driver cargo-fmt; do
    cat > "$CARGO_HOME/bin/$command_name" <<TARGETEOF
#!/bin/bash
printf 'target:%s\\n' "${command_name}"
printf 'target:%s\\n' "${command_name}" >> "${TARGET_LOG}"
printf '%s\\n' "\$@"
TARGETEOF
        chmod +x "$CARGO_HOME/bin/$command_name"
    done
}

@test "existing rustup tools preserve arguments and keep stdout clean" {
    create_existing_targets
    cat > "$CARGO_HOME/bin/rustup" <<'RUSTUPEOF'
#!/bin/bash
if [[ "$1" == component && "$2" == list && "$3" == --toolchain && "$4" == stable && "$5" == --installed ]]; then
    printf 'rust-analyzer-x86_64-unknown-linux-gnu (installed)\n'
    printf 'clippy-x86_64-unknown-linux-gnu (installed)\n'
    printf 'rustfmt-x86_64-unknown-linux-gnu (installed)\n'
elif [[ "$1" == show && "$2" == active-toolchain ]]; then
    printf 'stable\n'
else
    printf 'target:rustup\n'
    printf '%s\n' "$@"
fi
RUSTUPEOF
    chmod +x "$CARGO_HOME/bin/rustup"
    local command_name
    for command_name in rustc cargo rustfmt cargo-clippy rust-analyzer clippy-driver cargo-fmt rustup; do
        prepare_shim "$command_name"
        run --separate-stderr "$TEST_SCRIPT" "value with spaces" '--cfg=feature="a b"'
        [ "$status" -eq 0 ]
        [ "$output" = $'target:'"$command_name"$'\nvalue with spaces\n--cfg=feature="a b"' ]
        [[ "$stderr" == *"caller info"* ]]
        [[ "$stderr" != *"rustup installer"* ]]
        [[ "$(<"$MOCK_LOG")" == *"get-real-bin:--silent $command_name"* ]]
    done
}

@test "present rust-analyzer rustup proxy installs when stable component is absent" {
    cat > "$CARGO_HOME/bin/rustup" <<'RUSTUPEOF'
#!/bin/bash
printf 'rustup argv:' >> "$RUSTUP_LOG"
printf '<%s>' "$@" >> "$RUSTUP_LOG"
printf '\n' >> "$RUSTUP_LOG"
if [[ "$1" == show && "$2" == active-toolchain ]]; then
    printf 'stable\n'
    exit 0
fi
if [[ "$1" == component && "$2" == list && "$3" == --toolchain && "$4" == stable && "$5" == --installed ]]; then
    printf 'rustfmt-x86_64-unknown-linux-gnu (installed)\n'
    exit 0
fi
if [[ "$1" == component && "$2" == add && "$3" == --toolchain && "$4" == stable && "$5" == rust-analyzer ]]; then
    cat > "$CARGO_HOME/bin/rust-analyzer" <<'TARGETEOF'
#!/bin/bash
printf 'target:rust-analyzer\n'
printf 'target:rust-analyzer\n' >> "$TARGET_LOG"
printf '%s\n' "$@"
TARGETEOF
    chmod +x "$CARGO_HOME/bin/rust-analyzer"
    exit 0
fi
if [[ "$1" == rust-analyzer ]]; then
    printf 'proxy reached without component repair\n' >&2
    exit 91
fi
RUSTUPEOF
    chmod +x "$CARGO_HOME/bin/rustup"
    cat > "$CARGO_HOME/bin/rust-analyzer" <<'PROXYEOF'
#!/bin/bash
exec rustup rust-analyzer "$@"
PROXYEOF
    chmod +x "$CARGO_HOME/bin/rust-analyzer"

    prepare_shim rust-analyzer
    run --separate-stderr "$TEST_SCRIPT" "proxy argument"
    [ "$status" -eq 0 ]
    [ "$output" = $'target:rust-analyzer\nproxy argument' ]
    rustup_log="$(<"$RUSTUP_LOG")"
    [[ "$rustup_log" == *"rustup argv:<show><active-toolchain>"* ]]
    [[ "$rustup_log" == *"rustup argv:<component><list><--toolchain><stable><--installed>"* ]]
    [[ "$rustup_log" == *"rustup argv:<component><add><--toolchain><stable><rust-analyzer>"* ]]
    [[ "$stderr" != *"rustup installer output"* ]]
    [[ "$(<"$MOCK_LOG")" == *"get-real-bin:--silent rust-analyzer"* ]]
}

@test "component rustup proxies install missing mapped components" {
    cat > "$CARGO_HOME/bin/rustup" <<'RUSTUPEOF'
#!/bin/bash
printf 'rustup argv:' >> "$RUSTUP_LOG"
printf '<%s>' "$@" >> "$RUSTUP_LOG"
printf '\n' >> "$RUSTUP_LOG"
if [[ "$1" == component && "$2" == list && "$3" == --toolchain && "$4" == stable && "$5" == --installed ]]; then
    exit 0
fi
if [[ "$1" == show && "$2" == active-toolchain ]]; then
    printf 'stable\n'
    exit 0
fi
if [[ "$1" == component && "$2" == add && "$3" == --toolchain && "$4" == stable ]]; then
    case "$5" in
        rust-analyzer) command_name=rust-analyzer ;;
        clippy) command_name=clippy-driver ;;
        rustfmt) command_name=cargo-fmt ;;
        *) exit 1 ;;
    esac
    cat > "$CARGO_HOME/bin/$command_name" <<TARGETEOF
#!/bin/bash
printf 'target:%s\\n' "$command_name"
printf 'target:%s\\n' "$command_name" >> "$TARGET_LOG"
printf '%s\\n' "\$@"
TARGETEOF
    chmod +x "$CARGO_HOME/bin/$command_name"
    exit 0
fi
case "$1" in
    rust-analyzer) command_name=rust-analyzer ;;
    clippy-driver) command_name=clippy-driver ;;
    cargo-fmt) command_name=cargo-fmt ;;
    *) exit 1 ;;
esac
exec "$CARGO_HOME/bin/$command_name" "${@:2}"
RUSTUPEOF
    chmod +x "$CARGO_HOME/bin/rustup"

    local command_name component
    for command_name in rust-analyzer clippy-driver cargo-fmt; do
        case "$command_name" in
            rust-analyzer) component=rust-analyzer ;;
            clippy-driver) component=clippy ;;
            cargo-fmt) component=rustfmt ;;
        esac
        cat > "$CARGO_HOME/bin/$command_name" <<PROXYEOF
#!/bin/bash
exec rustup $command_name "\$@"
PROXYEOF
        chmod +x "$CARGO_HOME/bin/$command_name"
        prepare_shim "$command_name"
        run --separate-stderr "$TEST_SCRIPT" "proxy argument"
        [ "$status" -eq 0 ]
        [ "$output" = $'target:'"$command_name"$'\nproxy argument' ]
        [[ "$(<"$RUSTUP_LOG")" == *"rustup argv:<component><list><--toolchain><stable><--installed>"* ]]
        [[ "$(<"$RUSTUP_LOG")" == *"rustup argv:<component><add><--toolchain><stable><$component>"* ]]
    done
}

@test "component proxies repair the overridden active toolchain" {
    local active_toolchain=1.97.1-aarch64-unknown-linux-gnu
    cat > "$CARGO_HOME/bin/rustup" <<'RUSTUPEOF'
#!/bin/bash
printf 'rustup argv:' >> "$RUSTUP_LOG"
printf '<%s>' "$@" >> "$RUSTUP_LOG"
printf '\n' >> "$RUSTUP_LOG"
if [[ "$1" == show && "$2" == active-toolchain ]]; then
    printf '1.97.1-aarch64-unknown-linux-gnu (overridden by /workspace/rust-toolchain.toml)\n'
    exit 0
fi
if [[ "$1" == component && "$2" == list && "$3" == --toolchain && "$4" == stable && "$5" == --installed ]]; then
    printf 'rust-analyzer-x86_64-unknown-linux-gnu (installed)\n'
    printf 'clippy-x86_64-unknown-linux-gnu (installed)\n'
    printf 'rustfmt-x86_64-unknown-linux-gnu (installed)\n'
    exit 0
fi
if [[ "$1" == component && "$2" == list && "$3" == --toolchain && "$4" == 1.97.1-aarch64-unknown-linux-gnu && "$5" == --installed ]]; then
    exit 0
fi
if [[ "$1" == component && "$2" == add && "$3" == --toolchain && "$4" == 1.97.1-aarch64-unknown-linux-gnu ]]; then
    case "$5" in
        rust-analyzer) command_name=rust-analyzer ;;
        clippy) command_name=clippy-driver ;;
        rustfmt) command_name=cargo-fmt ;;
        *) exit 1 ;;
    esac
    cat > "$CARGO_HOME/bin/$command_name" <<TARGETEOF
#!/bin/bash
printf 'target:%s\\n' "$command_name"
printf 'target:%s\\n' "$command_name" >> "$TARGET_LOG"
printf '%s\\n' "\$@"
TARGETEOF
    chmod +x "$CARGO_HOME/bin/$command_name"
    exit 0
fi
case "$1" in
    rust-analyzer|clippy-driver|cargo-fmt)
        printf 'proxy reached without active component repair\n' >&2
        exit 91
        ;;
    default)
        printf 'rustup default must not be invoked\n' >&2
        exit 92
        ;;
esac
exit 0
RUSTUPEOF
    chmod +x "$CARGO_HOME/bin/rustup"

    local command_name component
    for command_name in rust-analyzer clippy-driver cargo-fmt; do
        case "$command_name" in
            rust-analyzer) component=rust-analyzer ;;
            clippy-driver) component=clippy ;;
            cargo-fmt) component=rustfmt ;;
        esac
        cat > "$CARGO_HOME/bin/$command_name" <<PROXYEOF
#!/bin/bash
exec rustup $command_name "\$@"
PROXYEOF
        chmod +x "$CARGO_HOME/bin/$command_name"
        prepare_shim "$command_name"
        run --separate-stderr "$TEST_SCRIPT" "override argument" "second  argument"
        [ "$status" -eq 0 ]
        [ "$output" = $'target:'"$command_name"$'\noverride argument\nsecond  argument' ]
        rustup_log="$(<"$RUSTUP_LOG")"
        [[ "$rustup_log" == *"rustup argv:<show><active-toolchain>"* ]]
        [[ "$rustup_log" == *"rustup argv:<component><list><--toolchain><$active_toolchain><--installed>"* ]]
        [[ "$rustup_log" == *"rustup argv:<component><add><--toolchain><$active_toolchain><$component>"* ]]
        [[ "$rustup_log" != *"rustup argv:<component><list><--toolchain><stable><--installed>"* ]]
        [[ "$rustup_log" != *"rustup argv:<component><add><--toolchain><stable>"* ]]
        [[ "$rustup_log" != *"rustup argv:<default>"* ]]
        [[ "$output" != *"caller info"* ]]
    done
}

@test "missing rustup tools install before execution for every shim" {
    export MOCK_MODE=missing
    local command_name
    for command_name in rustc cargo rustfmt cargo-clippy rust-analyzer clippy-driver cargo-fmt rustup; do
        prepare_shim "$command_name"
        run --separate-stderr "$TEST_SCRIPT" "missing $command_name"
        [ "$status" -eq 0 ]
        [ "$output" = $'target:'"$command_name"$'\nmissing '"$command_name" ]
        [[ "$stderr" == *"rustup installer output"* ]]
        [[ "$(<"$MOCK_LOG")" == *"get-real-bin:--silent $command_name"* ]]
    done
}

@test "rustup shim preserves whitespace-sensitive arguments for every tool" {
    create_existing_targets
    local command_name
    for command_name in rustc cargo rustfmt cargo-clippy rust-analyzer clippy-driver cargo-fmt rustup; do
        prepare_shim "$command_name"
        run --separate-stderr "$TEST_SCRIPT" "first argument" "second  argument" $'line\nbreak'
        [ "$status" -eq 0 ]
        [ "$output" = $'target:'"$command_name"$'\nfirst argument\nsecond  argument\nline\nbreak' ]
    done
}

@test "installer output is stderr-only and installer failure prevents execution" {
    export MOCK_MODE=missing
    prepare_shim rustc
    run --separate-stderr "$TEST_SCRIPT" --version
    [ "$status" -eq 0 ]
    [ "$output" = $'target:rustc\n--version' ]
    [[ "$output" != *"installer"* ]]
    [[ "$output" != *"caller"* ]]
    [[ "$stderr" == *"rustup installer output"* ]]

    rm -f "$TARGET_LOG"
    export INSTALLER_MODE=fail
    run --separate-stderr "$TEST_SCRIPT" --version
    [ "$status" -eq 23 ]
    [ -z "$output" ]
    [[ "$stderr" == *"rustup installer failed"* ]]
    [ ! -e "$TARGET_LOG" ]
}

@test "default CARGO_HOME bin is visible to child lookup" {
    unset CARGO_HOME
    export HOME="$TEST_ROOT/home"
    mkdir -p "$HOME"
    export MOCK_MODE=missing
    export PATH="$MOCK_DIR:$HOME/.cargo/bin:/usr/bin:/bin"
    prepare_shim cargo
    run --separate-stderr "$TEST_SCRIPT" "cargo arg"
    [ "$status" -eq 0 ]
    [ "$output" = $'target:cargo\ncargo arg' ]
    [[ "$stderr" == *"rustup installer output"* ]]
}

@test "h-setup-rustup-bin uses the official installer without network access" {
    export MOCK_MODE=missing
    export SETUP_SCRIPT="$BATS_TEST_DIRNAME/../.devcontainer/_build-context/rootfs/usr/local/bin/h-setup-rustup-bin"
    export RUSTUP_HOME="$TEST_ROOT/rustup home"
    export CURL_LOG="$TEST_ROOT/curl.log"
    export INSTALLER_LOG="$TEST_ROOT/installer.log"
    export FAKE_INSTALLER="$TEST_ROOT/fake-rustup.sh"
    mkdir -p "$RUSTUP_HOME"

    cat > "$FAKE_INSTALLER" <<'INSTALLEREOF'
#!/bin/bash
printf 'fake installer stdout\n'
printf 'fake installer stderr\n' >&2
printf 'args:%s\n' "$*" >> "$INSTALLER_LOG"
printf 'CARGO_HOME=%s\n' "$CARGO_HOME" >> "$INSTALLER_LOG"
printf 'RUSTUP_HOME=%s\n' "$RUSTUP_HOME" >> "$INSTALLER_LOG"
mkdir -p "$CARGO_HOME/bin"
cat > "$CARGO_HOME/bin/rustup" <<'RUSTUPEOF'
#!/bin/bash
printf 'rustup argv:' >> "$RUSTUP_LOG"
printf '<%s>' "$@" >> "$RUSTUP_LOG"
printf '\n' >> "$RUSTUP_LOG"
if [[ "${RUSTUP_COMPONENT_MODE:-success}" == fail && "$1" == component ]]; then
    printf 'rustup component add failed\n' >&2
    exit 37
fi
if [[ "$1" == --version ]]; then
    printf 'rustup 1.0.0\n'
fi
RUSTUPEOF
chmod +x "$CARGO_HOME/bin/rustup"
for component in rust-analyzer clippy rustfmt; do
    "$CARGO_HOME/bin/rustup" component add --toolchain stable "$component"
done
INSTALLEREOF
    chmod +x "$FAKE_INSTALLER"

    cat > "$MOCK_DIR/_curl-fsSL--compressed" <<'CURLEOF'
#!/bin/bash
printf '%s\n' "$*" > "$CURL_LOG"
cat "$FAKE_INSTALLER"
CURLEOF
    chmod +x "$MOCK_DIR/_curl-fsSL--compressed"

    run --separate-stderr "$SETUP_SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [[ "$stderr" == *"fake installer stderr"* ]]
    curl_args="$(<"$CURL_LOG")"
    [ "$curl_args" = "https://sh.rustup.rs" ]
    installer_log="$(<"$INSTALLER_LOG")"
    [[ "$installer_log" == *"args:-y --no-modify-path --profile default --default-toolchain stable"* ]]
    [[ "$installer_log" == *"CARGO_HOME=$CARGO_HOME"* ]]
    [[ "$installer_log" == *"RUSTUP_HOME=$RUSTUP_HOME"* ]]
    rustup_log="$(<"$RUSTUP_LOG")"
    [[ "$rustup_log" == *"rustup argv:<component><add><--toolchain><stable><rust-analyzer>"* ]]
    [[ "$rustup_log" == *"rustup argv:<component><add><--toolchain><stable><clippy>"* ]]
    [[ "$rustup_log" == *"rustup argv:<component><add><--toolchain><stable><rustfmt>"* ]]
    [[ "$rustup_log" != *"rustup argv:<default>"* ]]

    rm -f "$CARGO_HOME/bin/rustup"
    export RUSTUP_COMPONENT_MODE=fail
    run --separate-stderr "$SETUP_SCRIPT"
    [ "$status" -eq 37 ]
    [ -z "$output" ]
    [[ "$stderr" == *"rustup component add failed"* ]]
}

@test "existing rustup installs rust-analyzer without changing the default toolchain" {
    export MOCK_MODE=missing
    export SETUP_SCRIPT="$BATS_TEST_DIRNAME/../.devcontainer/_build-context/rootfs/usr/local/bin/h-setup-rustup-bin"
    export RUSTUP_HOME="$TEST_ROOT/rustup home"
    mkdir -p "$RUSTUP_HOME"
    cat > "$CARGO_HOME/bin/rustup" <<'RUSTUPEOF'
#!/bin/bash
printf 'rustup argv:' >> "$RUSTUP_LOG"
printf '<%s>' "$@" >> "$RUSTUP_LOG"
printf '\n' >> "$RUSTUP_LOG"
if [[ "${RUSTUP_COMPONENT_MODE:-success}" == fail && "$1" == component ]]; then
    printf 'rustup component add failed\n' >&2
    exit 37
fi
if [[ "$1" == component && "$2" == add && "$3" == --toolchain && "$4" == stable && "$5" == rust-analyzer ]]; then
    : > "$CARGO_HOME/bin/rust-analyzer"
fi
if [[ "$1" == component && "$2" == add && "$3" == --toolchain && "$4" == stable && "$5" == clippy ]]; then
    : > "$CARGO_HOME/bin/clippy-driver"
fi
if [[ "$1" == component && "$2" == add && "$3" == --toolchain && "$4" == stable && "$5" == rustfmt ]]; then
    : > "$CARGO_HOME/bin/cargo-fmt"
fi
if [[ "$1" == --version ]]; then
    printf 'rustup 1.0.0\n'
fi
RUSTUPEOF
    chmod +x "$CARGO_HOME/bin/rustup"

    run --separate-stderr "$SETUP_SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [[ "$stderr" == *"已找到 rustup"* ]]
    rustup_log="$(<"$RUSTUP_LOG")"
    [[ "$rustup_log" == *"rustup argv:<component><add><--toolchain><stable><rust-analyzer>"* ]]
    [[ "$rustup_log" == *"rustup argv:<component><add><--toolchain><stable><clippy>"* ]]
    [[ "$rustup_log" == *"rustup argv:<component><add><--toolchain><stable><rustfmt>"* ]]
    [[ "$rustup_log" != *"rustup argv:<default>"* ]]

    export RUSTUP_COMPONENT_MODE=fail
    run --separate-stderr "$SETUP_SCRIPT"
    [ "$status" -eq 37 ]
    [ -z "$output" ]
    [[ "$stderr" == *"rustup component add failed"* ]]
}
