#!/bin/bash

# ==========================================
# Claude 全自动开发循环脚本 (最终修复版)
# ==========================================

# 配置项
MAX_ITERATIONS=20           # 最大循环次数
PROMPT_FILE=".ai/cloud.md"  # 提示词文件
PROGRESS_FILE=".ai/progress.txt" # 进度日志
LIVE_LOG=".ai/live.log"     # 实时详细日志
SINGLE_TASK_TIMEOUT=300     # 单个任务超时时间(秒)，防止卡死

echo "🚀 启动 Claude 自动开发系统..."
echo "👀 监控模式：请使用 tail -f .ai/live.log 查看实时详情"

# 初始化日志文件
touch "$LIVE_LOG"
touch "$PROGRESS_FILE"

# 检查提示词文件
if [ ! -f "$PROMPT_FILE" ]; then
    echo "❌ 错误：找不到提示词文件 $PROMPT_FILE"
    exit 1
fi

for ((i=1; i<=$MAX_ITERATIONS; i++)); do
    echo "=== 🔄 第 $i 轮迭代开始 ===" | tee -a "$LIVE_LOG"
    
    # 核心执行命令
    # 1. < "$PROMPT_FILE": 解决"不退出"问题，强制输入结束符
    # 2. --dangerously-skip-permissions: 解决"要权限"问题，全自动运行
    # 3. timeout 300: 解决"卡死"问题，超时强制进入下一轮
    # 4. 2>&1 | tee -a: 解决"看不了日志"问题，实时记录所有输出
    timeout $SINGLE_TASK_TIMEOUT claude --dangerously-skip-permissions < "$PROMPT_FILE" 2>&1 | tee -a "$LIVE_LOG"
    
    # 捕获退出状态
    EXIT_CODE=${PIPESTATUS[0]}

    # 如果是超时退出 (Exit Code 124)
    if [ $EXIT_CODE -eq 124 ]; then
        echo "⚠️ 任务执行超时，强制进入下一轮..." | tee -a "$LIVE_LOG"
    fi

    # 检查是否所有任务已完成
    if grep -q "ALL TASKS COMPLETED" "$PROGRESS_FILE"; then
        echo "" | tee -a "$LIVE_LOG"
        echo "✅ ✅ ✅  检测到完成信号！项目开发结束。 ✅ ✅ ✅" | tee -a "$LIVE_LOG"
        exit 0
    fi
    
    # 检查是否遇到阻塞
    if grep -q "BLOCKED: NEED HUMAN HELP" "$PROGRESS_FILE"; then
        echo "⚠️ AI 遇到阻碍，请求人工介入。请查看 $PROGRESS_FILE 详情。" | tee -a "$LIVE_LOG"
        exit 1
    fi

    echo "⏳ 等待 2 秒后进入下一轮..." | tee -a "$LIVE_LOG"
    sleep 2
done

echo "⚠️ 达到最大迭代次数 ($MAX_ITERATIONS)，任务可能未全部完成。" | tee -a "$LIVE_LOG"
