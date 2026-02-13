#!/bin/bash

# ==========================================
# Claude 全自动开发循环脚本 (MECE Production版)
# 版本: 2.1
# 职责: 基础设施保障 + 流程编排 + 异常兜底
# ==========================================

# 清理可能干扰的环境变量
unset CLAUDECODE 2>/dev/null || true

# 带时间戳的日志（提前定义，以便后续使用）
LIVE_LOG="${LIVE_LOG:-.ai/live.log}"
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" | tee -a "$LIVE_LOG"
}

# -----------------------------------------
# 权限模式检测（root vs 普通用户）
# -----------------------------------------
SKIP_PERMISSIONS_FLAG=""

if [ "$(id -u)" -eq 0 ]; then
    # root 用户
    echo "⚠️ 检测到 root 用户，Claude Code 不支持 --dangerously-skip-permissions 参数"
    echo "⚠️ 请确保在提示词中已包含自动授权指令，否则可能会卡住等待用户输入"
    SKIP_PERMISSIONS_FLAG=""
else
    # 普通用户，询问是否启用
    echo ""
    echo "========================================"
    echo "Claude 自动开发循环脚本"
    echo "========================================"
    echo ""
    echo "检测到当前为普通用户 ($(whoami))"
    echo ""
    echo "是否启用 --dangerously-skip-permissions 模式？"
    echo "  [Y] 是 - 自动跳过所有权限确认（推荐用于自动化）"
    echo "  [N] 否 - 每次文件操作都需人工确认（更安全）"
    echo ""
    read -rp "请选择 [Y/N，默认 Y]: " choice
    choice=${choice:-Y}

    if [[ "$choice" =~ ^[Yy]$ ]]; then
        SKIP_PERMISSIONS_FLAG="--dangerously-skip-permissions"
        echo "✅ 已启用自动权限跳过模式"
    else
        SKIP_PERMISSIONS_FLAG=""
        echo "ℹ️ 使用人工确认模式"
    fi
    echo ""
fi

set -euo pipefail  # 严格模式

# -----------------------------------------
# 配置区 (可环境变量覆盖)
# -----------------------------------------
MAX_ITERATIONS=${MAX_ITERATIONS:-50}          # 安全上限
PROMPT_FILE="${PROMPT_FILE:-.ai/cloud.md}"    # 提示词文件路径
TASK_FILE="${TASK_FILE:-.ai/task.json}"       # 任务清单路径
PROGRESS_FILE="${PROGRESS_FILE:-.ai/progress.txt}"
BLOCKED_FLAG="${BLOCKED_FLAG:-.ai/.blocked}"  # 阻塞标记文件(隐藏文件)
SINGLE_TASK_TIMEOUT=${SINGLE_TASK_TIMEOUT:-300} # 5分钟超时

# Git 兜底配置
GIT_FALLBACK_MSG="chore: Auto-fallback by script"
GIT_MAX_RETRY=3

# -----------------------------------------
# 工具函数
# -----------------------------------------

# 错误日志
error() {
    log "❌ ERROR: $1" >&2
}

# 致命错误：立即退出并标记阻塞
fatal() {
    error "$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] BLOCKED: NEED HUMAN HELP - $1" >> "$PROGRESS_FILE"
    touch "$BLOCKED_FLAG"
    exit 1
}

# 检查命令存在
check_cmd() {
    if ! command -v "$1" &> /dev/null; then
        fatal "缺少必要命令: $1"
    fi
}

# -----------------------------------------
# 初始化与检查
# -----------------------------------------

init_environment() {
    log "🚀 初始化 Claude 自动开发系统..."

    # 1. 检查核心依赖
    check_cmd claude
    check_cmd git
    check_cmd python3  # 用于 JSON 验证

    # 2. 检查 Git 仓库
    if [ ! -d ".git" ]; then
        fatal "当前目录不是 Git 仓库 (缺少 .git 目录)"
    fi

    # 3. 检查远程仓库关联
    if ! git remote get-url origin &>/dev/null; then
        fatal "Git 未关联远程仓库 (origin)"
    fi

    # 4. 检查提示词文件
    if [ ! -f "$PROMPT_FILE" ]; then
        fatal "提示词文件不存在: $PROMPT_FILE"
    fi

    # 5. 创建 .ai 目录结构
    mkdir -p .ai

    # 6. 验证 task.json 格式
    if ! python3 -m json.tool "$TASK_FILE" > /dev/null 2>&1; then
        fatal "task.json JSON 格式损坏，请手动修复"
    fi

    # 7. 初始化日志文件
    touch "$PROGRESS_FILE" "$LIVE_LOG"

    # 8. 清理历史阻塞标记 (如果存在)
    if [ -f "$BLOCKED_FLAG" ]; then
        log "⚠️ 检测到历史阻塞标记，已清理"
        rm -f "$BLOCKED_FLAG"
    fi

    # 9. 清理 progress.txt 中的历史 BLOCKED 记录 (允许从失败恢复)
    if [ -f "$PROGRESS_FILE" ] && grep -q "BLOCKED: NEED HUMAN HELP" "$PROGRESS_FILE"; then
        log "⚠️ 检测到历史 BLOCKED 记录，已清理 (脚本将尝试继续执行)"
        grep -v "BLOCKED: NEED HUMAN HELP" "$PROGRESS_FILE" > "$PROGRESS_FILE.tmp" && mv "$PROGRESS_FILE.tmp" "$PROGRESS_FILE"
    fi

    log "✅ 环境检查通过，准备进入主循环"
}

# -----------------------------------------
# 终止条件检测 (MECE: 穷尽所有退出场景)
# -----------------------------------------

check_termination() {
    # 返回码: 0=正常终止, 1=继续执行, 2=异常终止(BLOCKED)

    # 1. 检查硬阻塞标记文件
    if [ -f "$BLOCKED_FLAG" ]; then
        log "🛑 检测到阻塞标记文件 ($BLOCKED_FLAG)"
        return 2
    fi

    # 2. 检查 progress.txt 中的 BLOCKED 状态
    if [ -f "$PROGRESS_FILE" ] && grep -q "BLOCKED: NEED HUMAN HELP" "$PROGRESS_FILE"; then
        log "🛑 检测到阻塞日志记录"
        return 2
    fi

    # 3. 检查任务完成信号
    if [ -f "$PROGRESS_FILE" ] && grep -q "ALL TASKS COMPLETED" "$PROGRESS_FILE"; then
        log "✅ 检测到任务完成信号"
        return 0
    fi

    # 4. 检查 task.json 中是否还有未完成任务 (辅助判断)
    if [ -f "$TASK_FILE" ]; then
        local pending_tasks=$(python3 -c "
import json,sys
try:
    with open('$TASK_FILE','r') as f:
        data=json.load(f)
        # 支持两种格式: 直接数组 或 对象包含tasks键
        if isinstance(data, list):
            tasks = data
        else:
            tasks = data.get('tasks', [])
        pending = [t for t in tasks if not t.get('completed', False)]
        print(len(pending))
except Exception as e:
    print('error')
" 2>/dev/null)

        if [ "$pending_tasks" = "0" ]; then
            log "✅ task.json 中无待办任务"
            return 0
        elif [ "$pending_tasks" = "error" ]; then
            fatal "无法解析 task.json 统计待办任务数"
        fi
    fi

    # 5. 默认继续执行
    return 1
}

# -----------------------------------------
# Git 兜底机制 (幂等设计)
# -----------------------------------------

git_fallback() {
    log "🔍 检查 Git 状态..."

    # 检查工作区是否干净
    if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
        log "✅ 工作区干净，无需兜底提交"
        return 0
    fi

    log "⚠️ 检测到未提交更改，执行兜底提交..."

    # 提取最后一次完成的任务 ID (用于提交信息)
    local last_task=""
    if [ -f "$PROGRESS_FILE" ]; then
        last_task=$(grep -oE "任务T[0-9]+" "$PROGRESS_FILE" | tail -n 1 || true)
    fi

    local commit_msg="$GIT_FALLBACK_MSG"
    [ -n "$last_task" ] && commit_msg="feat: ${last_task} - ${GIT_FALLBACK_MSG}"

    # 添加文件 (排除日志和标记文件)
    git add . -- ':!.ai/live.log' ':!.ai/.blocked' 2>&1 | log_stream

    # 检查是否有实质内容可提交
    if git diff --cached --quiet; then
        log "ℹ️ 无实质变更可提交 (可能是权限变更或空文件)"
        return 0
    fi

    # 执行提交
    if ! git commit -m "$commit_msg" 2>&1 | log_stream; then
        fatal "Git commit 失败"
    fi

    # 推送重试逻辑
    local retry=0
    while [ $retry -lt $GIT_MAX_RETRY ]; do
        if git push 2>&1 | log_stream; then
            log "✅ Git 推送成功"
            return 0
        fi

        retry=$((retry + 1))
        if [ $retry -lt $GIT_MAX_RETRY ]; then
            log "⏳ 推送失败，${retry}/${GIT_MAX_RETRY} 秒后重试..."
            sleep $((retry * 2))  # 指数退避
        fi
    done

    # 尝试 fallback 分支推送
    log "⚠️ 标准推送失败，尝试设置上游分支..."
    if git push -u origin HEAD 2>&1 | log_stream; then
        log "✅ Git 推送成功 (使用 -u origin HEAD)"
        return 0
    fi

    fatal "Git push 连续 ${GIT_MAX_RETRY} 次失败"
}

# 辅助：将标准输出同时传给 log 函数
log_stream() {
    while IFS= read -r line; do
        log "$line"
    done
}

# -----------------------------------------
# 主循环
# -----------------------------------------

main_loop() {
    init_environment

    local iteration=0
    local claude_exit_code=0

    while [ $iteration -lt $MAX_ITERATIONS ]; do
        iteration=$((iteration + 1))

        log "========================================"
        log "🔄 第 ${iteration}/${MAX_ITERATIONS} 轮迭代开始"
        log "========================================"

        # --- 前置终止检查 ---
        local term_status=0
        check_termination || term_status=$?

        if [ "$term_status" -eq 0 ]; then
            log "🎉 所有任务已完成，正常退出"
            exit 0
        elif [ "$term_status" -eq 2 ]; then
            fatal "系统处于阻塞状态，停止执行"
        else
            log "📋 仍有待办任务，继续执行..."
        fi

        # --- 执行 Claude ---
        log "🤖 启动 Claude 执行单任务闭环..."

        # 执行 Claude（后台运行，手动超时控制）
        set +e  # 临时关闭 errexit
        PROMPT_CONTENT=$(cat "$PROMPT_FILE")

        # 后台启动 claude（使用干净环境避免嵌套会话检测）
        # shellcheck disable=SC2086
        env -i PATH="$PATH" HOME="$HOME" CLAUDE_CODE_DISABLE_TELEMETRY=1 claude $SKIP_PERMISSIONS_FLAG -p "$PROMPT_CONTENT" >> "$LIVE_LOG" 2>&1 &
        local claude_pid=$!

        # 等待最多 SINGLE_TASK_TIMEOUT 秒
        local wait_count=0
        while kill -0 $claude_pid 2>/dev/null; do
            if [ $wait_count -ge $SINGLE_TASK_TIMEOUT ]; then
                log "⏱️ Claude 执行超时，终止进程..."
                kill -9 $claude_pid 2>/dev/null
                wait $claude_pid 2>/dev/null
                claude_exit_code=124
                break
            fi
            sleep 1
            wait_count=$((wait_count + 1))
        done

        # 如果正常结束，获取退出码
        if [ -z "${claude_exit_code:-}" ]; then
            wait $claude_pid
            claude_exit_code=$?
        fi

        set -e  # 恢复 errexit

        # 分析 Claude 执行结果
        case $claude_exit_code in
            0)
                log "✅ Claude 正常退出 (Exit Code: 0)"
                ;;
            124)
                fatal "Claude 执行超时 (${SINGLE_TASK_TIMEOUT}秒)，任务可能死锁"
                ;;
            130)
                log "⚠️ Claude 被用户中断 (Ctrl+C)"
                exit 130
                ;;
            *)
                log "⚠️ Claude 异常退出 (Exit Code: ${claude_exit_code})"
                # 不立即退出，检查 progress 文件状态
                ;;
        esac

        # --- Git 兜底 (无论 Claude 成功与否都检查) ---
        if ! git_fallback; then
            fatal "Git 兜底机制失败"
        fi

        # --- 后置终止检查 ---
        check_termination
        term_status=$?

        case $term_status in
            0)
                log "🎉 本轮后检测到任务完成，正常退出"
                exit 0
                ;;
            2)
                fatal "本轮后检测到阻塞状态"
                ;;
            1)
                log "📋 仍有待办任务，准备下一轮..."
                ;;
        esac

        # --- 防过载休眠 ---
        if [ $iteration -lt $MAX_ITERATIONS ]; then
            log "😴 休眠 3 秒后继续..."
            sleep 3
        fi

    done

    # 达到最大迭代次数
    fatal "达到最大迭代次数 (${MAX_ITERATIONS})，强制停止"
}

# -----------------------------------------
# 信号处理 (优雅退出)
# -----------------------------------------
cleanup() {
    log "🛑 接收到中断信号，正在清理..."
    # 可选: 在这里执行紧急提交
    exit 130
}

trap cleanup INT TERM

# -----------------------------------------
# 执行入口
# -----------------------------------------
main_loop
