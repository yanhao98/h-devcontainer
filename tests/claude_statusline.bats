#!/usr/bin/env bats

# 被测试脚本路径
SCRIPT_PATH="$BATS_TEST_DIRNAME/../.devcontainer/_build-context/rootfs/usr/local/bin-priority/claude-statusline"

# 构造模拟 JSON 输入
make_input() {
    local total_ms=${1:-0}
    local api_ms=${2:-0}
    local cost_usd=${3:-0}
    local lines_added=${4:-0}
    local lines_removed=${5:-0}
    local input_tokens=${6:-5000}
    local output_tokens=${7:-2000}
    local window_size=${8:-200000}
    local current_input=${9:-8000}
    local cache_read=${10:-3000}
    cat <<EOF
{
  "model": {"display_name": "Opus 4.6"},
  "workspace": {"current_dir": "/home/user/project/src", "project_dir": "/home/user/project"},
  "cost": {
    "total_cost_usd": $cost_usd,
    "total_duration_ms": $total_ms,
    "total_api_duration_ms": $api_ms,
    "total_lines_added": $lines_added,
    "total_lines_removed": $lines_removed
  },
  "context_window": {
    "total_input_tokens": $input_tokens,
    "total_output_tokens": $output_tokens,
    "context_window_size": $window_size,
    "current_usage": {
      "input_tokens": $current_input,
      "output_tokens": 1000,
      "cache_creation_input_tokens": 0,
      "cache_read_input_tokens": $cache_read
    }
  }
}
EOF
}

# 去除 ANSI 转义序列，便于断言
strip_ansi() {
    sed 's/\x1b\[[0-9;]*m//g'
}

# ============================================================
# format_duration 单元测试
# ============================================================

# 提取 format_duration 函数用于独立测试
setup() {
    # 从脚本中提取 format_duration 函数到临时文件
    export FORMAT_DURATION_SRC="$BATS_TMPDIR/format_duration.sh"
    sed -n '/^format_duration()/,/^}/p' "$SCRIPT_PATH" > "$FORMAT_DURATION_SRC"
}

teardown() {
    rm -f "$FORMAT_DURATION_SRC"
}

@test "format_duration: 0ms -> 0ms" {
    source "$FORMAT_DURATION_SRC"
    run format_duration 0
    [ "$output" = "0ms" ]
}

@test "format_duration: 500ms -> 500ms" {
    source "$FORMAT_DURATION_SRC"
    run format_duration 500
    [ "$output" = "500ms" ]
}

@test "format_duration: 999ms -> 999ms" {
    source "$FORMAT_DURATION_SRC"
    run format_duration 999
    [ "$output" = "999ms" ]
}

@test "format_duration: 1000ms -> 1.0s" {
    source "$FORMAT_DURATION_SRC"
    run format_duration 1000
    [ "$output" = "1.0s" ]
}

@test "format_duration: 1500ms -> 1.5s" {
    source "$FORMAT_DURATION_SRC"
    run format_duration 1500
    [ "$output" = "1.5s" ]
}

@test "format_duration: 12300ms -> 12.3s" {
    source "$FORMAT_DURATION_SRC"
    run format_duration 12300
    [ "$output" = "12.3s" ]
}

@test "format_duration: 59999ms -> 60.0s (秒级上界)" {
    source "$FORMAT_DURATION_SRC"
    run format_duration 59999
    [ "$output" = "60.0s" ]
}

@test "format_duration: 60000ms -> 1m0s" {
    source "$FORMAT_DURATION_SRC"
    run format_duration 60000
    [ "$output" = "1m0s" ]
}

@test "format_duration: 77200ms -> 1m17s" {
    source "$FORMAT_DURATION_SRC"
    run format_duration 77200
    [ "$output" = "1m17s" ]
}

@test "format_duration: 214200ms -> 3m34s" {
    source "$FORMAT_DURATION_SRC"
    run format_duration 214200
    [ "$output" = "3m34s" ]
}

@test "format_duration: 3600000ms -> 60m0s" {
    source "$FORMAT_DURATION_SRC"
    run format_duration 3600000
    [ "$output" = "60m0s" ]
}

@test "format_duration: 带小数的毫秒值应截断取整" {
    source "$FORMAT_DURATION_SRC"
    run format_duration 1500.7
    [ "$output" = "1.5s" ]
}

# ============================================================
# 端到端集成测试
# ============================================================

@test "端到端: 模型名称正确显示" {
    result=$(make_input 1000 500 | bash "$SCRIPT_PATH" | strip_ansi)
    [[ "$result" == *"[Opus 4.6]"* ]]
}

@test "端到端: 目录显示为相对路径" {
    result=$(make_input 1000 500 | bash "$SCRIPT_PATH" | strip_ansi)
    [[ "$result" == *"project/src"* ]]
}

@test "端到端: 毫秒级耗时显示" {
    result=$(make_input 500 200 | bash "$SCRIPT_PATH" | strip_ansi)
    [[ "$result" == *"500ms (API:200ms)"* ]]
}

@test "端到端: 秒级耗时显示" {
    result=$(make_input 12300 5600 | bash "$SCRIPT_PATH" | strip_ansi)
    [[ "$result" == *"12.3s (API:5.6s)"* ]]
}

@test "端到端: 分钟级耗时显示" {
    result=$(make_input 214200 77200 | bash "$SCRIPT_PATH" | strip_ansi)
    [[ "$result" == *"3m34s (API:1m17s)"* ]]
}

@test "端到端: 成本显示" {
    result=$(make_input 1000 500 0.123456 | bash "$SCRIPT_PATH" | strip_ansi)
    [[ "$result" == *'$0.123456'* ]]
}

@test "端到端: 代码变更行数显示" {
    result=$(make_input 1000 500 0 42 7 | bash "$SCRIPT_PATH" | strip_ansi)
    [[ "$result" == *"+42"* ]]
    [[ "$result" == *"-7"* ]]
}

@test "端到端: Token 使用量和上下文百分比" {
    result=$(make_input 1000 500 0 0 0 5000 2000 200000 8000 3000 | bash "$SCRIPT_PATH" | strip_ansi)
    [[ "$result" == *"8000/200000 (4%)"* ]]
    [[ "$result" == *"Σin:5000"* ]]
    [[ "$result" == *"out:2000"* ]]
}

@test "端到端: 缓存读取显示" {
    result=$(make_input 1000 500 0 0 0 5000 2000 200000 8000 3000 | bash "$SCRIPT_PATH" | strip_ansi)
    [[ "$result" == *"read:3000"* ]]
}

@test "端到端: context_window_size 为 0 时不崩溃" {
    result=$(make_input 1000 500 0 0 0 5000 2000 0 0 0 | bash "$SCRIPT_PATH" | strip_ansi)
    [ $? -eq 0 ]
    [[ "$result" == *"Opus 4.6"* ]]
}

@test "端到端: 输出为两行" {
    line_count=$(make_input 1000 500 | bash "$SCRIPT_PATH" | wc -l)
    [ "$line_count" -eq 2 ]
}

@test "端到端: 字段缺失时不崩溃且无输出（数据量过小被过滤）" {
    result=$(echo '{}' | bash "$SCRIPT_PATH" 2>/dev/null | strip_ansi)
    [ $? -eq 0 ]
    [ -z "$result" ]
}

@test "端到端: TOTAL_API_DURATION_MS < 10 时无输出" {
    result=$(make_input 1000 9 0 0 0 5000 2000 | bash "$SCRIPT_PATH" | strip_ansi)
    [ $? -eq 0 ]
    [ -z "$result" ]
}

@test "端到端: TOTAL_INPUT_TOKENS < 100 时无输出" {
    result=$(make_input 1000 500 0 0 0 99 2000 | bash "$SCRIPT_PATH" | strip_ansi)
    [ $? -eq 0 ]
    [ -z "$result" ]
}

@test "端到端: TOTAL_OUTPUT_TOKENS < 100 时无输出" {
    result=$(make_input 1000 500 0 0 0 5000 99 | bash "$SCRIPT_PATH" | strip_ansi)
    [ $? -eq 0 ]
    [ -z "$result" ]
}
