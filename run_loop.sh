#!/bin/bash

# ==========================================
# Claude 自动开发循环脚本
# ==========================================

# 最大循环次数（防止死循环）
MAX_ITERATIONS=20
TASK_FILE=".ai/task.json"
PROGRESS_FILE=".ai/progress.txt"
PROMPT_FILE=".ai/cloud.md"

echo "🚀 启动 Claude 自动开发系统..."

# 检查文件是否存在
if [ ! -f "$PROMPT_FILE" ]; then
    echo "❌ 错误：找不到提示词文件 $PROMPT_FILE"
    exit 1
fi

for ((i=1; i<=$MAX_ITERATIONS; i++)); do
    echo "=== 🔄 第 $i 轮迭代开始 ==="
    
    # 核心命令：通过管道将提示词传给 Claude
    # claude 会读取指令，执行操作（读写文件、运行测试），然后退出
    # 这里假设你已经安装并配置好了 claude CLI
    cat "$PROMPT_FILE" | claude

    # 检查是否所有任务已完成
    # 如果 progress.txt 中出现了我们约定的结束信号
    if grep -q "ALL TASKS COMPLETED" "$PROGRESS_FILE"; then
        echo ""
        echo "✅ ✅ ✅  检测到完成信号！项目开发结束。 ✅ ✅ ✅"
        exit 0
    fi
    
    # 检查是否遇到无法处理的错误（可选）
    if grep -q "BLOCKED: NEED HUMAN HELP" "$PROGRESS_FILE"; then
        echo "⚠️ AI 遇到阻碍，请求人工介入。请查看 $PROGRESS_FILE 详情。"
        exit 1
    fi

    echo "⏳ 等待 3 秒后进入下一轮..."
    sleep 3
done

echo "⚠️ 达到最大迭代次数 ($MAX_ITERATIONS)，任务可能未全部完成。"
