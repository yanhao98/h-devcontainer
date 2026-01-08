#!/usr/bin/env bats

setup() {
    # 定义被测试脚本的路径
    # 假设测试运行在项目根目录
    export NODE_SHIM_PATH="$BATS_TEST_DIRNAME/../.devcontainer/_build-context/rootfs/usr/local/bin-priority/node"
    
    # 创建模拟环境
    export MOCK_DIR="$BATS_TMPDIR/mocks"
    mkdir -p "$MOCK_DIR"
    
    # 将 mock 目录添加到 PATH 最前面
    export PATH="$MOCK_DIR:$PATH"
    
    # 模拟 shim-utils.sh
    # mkdir -p "/devcontainer" (removed to avoid permission denied)
    echo '_print_caller_info() { echo "mock caller info" >&2; }' > "$MOCK_DIR/shim-utils.sh"
    # 为了让 source /devcontainer/shim-utils.sh 工作，我们需要拦截它或者确保文件存在
    # 由于脚本中使用绝对路径 source，我们可能需要创建一个临时的 shim-utils.sh 在测试环境中
    # 或者我们可以 mock source 命令（比较复杂），或者修改 PATH 查找逻辑
    # 这里我们假设测试环境允许写入 /devcontainer 或者我们通过 sed 修改脚本来测试
    
    # 更好的方法：创建一个临时的测试脚本副本，修改 source 路径
    export TEST_SCRIPT="$BATS_TMPDIR/test_node_shim"
    cp "$NODE_SHIM_PATH" "$TEST_SCRIPT"
    chmod +x "$TEST_SCRIPT"
    
    # 创建一个假的 shim-utils.sh
    echo '_print_caller_info() { echo "mock caller info" >&2; }' > "$BATS_TMPDIR/shim-utils.sh"
    
    # 修改测试脚本中的 source 路径
    sed -i "s|source /devcontainer/shim-utils.sh|source $BATS_TMPDIR/shim-utils.sh|g" "$TEST_SCRIPT"
}

teardown() {
    rm -rf "$BATS_TMPDIR/mocks"
    rm -f "$TEST_SCRIPT"
    rm -f "$BATS_TMPDIR/shim-utils.sh"
}

@test "验证 stdout 纯净性：不应包含调试信息" {
    # Mock _get-real-bin
    cat <<EOF > "$MOCK_DIR/_get-real-bin"
#!/bin/bash
echo "$MOCK_DIR/real-node"
EOF
    chmod +x "$MOCK_DIR/_get-real-bin"
    
    # Mock real node
    cat <<EOF > "$MOCK_DIR/real-node"
#!/bin/bash
echo "v1.0.0"
EOF
    chmod +x "$MOCK_DIR/real-node"
    
    # 我们需要分别捕获 stdout 和 stderr
    # run 命令合并了它们，所以我们手动运行
    
    # 创建临时文件保存输出
    STDOUT_FILE="$BATS_TMPDIR/stdout"
    STDERR_FILE="$BATS_TMPDIR/stderr"
    
    "$TEST_SCRIPT" > "$STDOUT_FILE" 2> "$STDERR_FILE"
    
    # 验证 stdout 只包含版本号
    run cat "$STDOUT_FILE"
    [ "$output" = "v1.0.0" ]
    
    # 验证 stderr 包含调试信息
    run cat "$STDERR_FILE"
    [[ "$output" == *"exec"* ]]
}
