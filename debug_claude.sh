#!/bin/bash
# Claude 启动诊断脚本

echo "=== Claude 启动诊断 ==="
echo ""

echo "1. 检查 claude 命令路径:"
which claude
echo ""

echo "2. 检查 CLAUDECODE 环境变量:"
if [ -n "$CLAUDECODE" ]; then
    echo "CLAUDECODE 已设置: ${CLAUDECODE:0:20}..."
else
    echo "CLAUDECODE 未设置（这是正常的，说明不在 Claude 会话中）"
fi
echo ""

echo "3. 测试直接启动 claude -p 模式:"
echo "命令: echo 'test' | claude -p '请回复hi'"
env -u CLAUDECODE claude -p "请回复hi" 2>&1 | head -5
echo ""

echo "4. 测试后台启动并等待:"
env -u CLAUDECODE claude -p "请回复hello" > /tmp/test_claude.log 2>&1 &
PID=$!
echo "子进程 PID: $PID"
sleep 3
if kill -0 $PID 2>/dev/null; then
    echo "子进程仍在运行"
else
    echo "子进程已退出"
    echo "日志内容:"
    cat /tmp/test_claude.log 2>/dev/null | head -20
fi
echo ""

echo "5. 检查 ~/.claude 目录权限:"
ls -la ~/.claude/ 2>/dev/null | head -5
