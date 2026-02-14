# CLAUDE.md

## Project Overview

**核心目的**：开发实现 Claude 全自动开发循环脚本 (`run_loop.sh`)，实现任务驱动的自动化开发流程。

待办事项应用 (React + Express + SQLite) 仅作为**演示/测试用例**，用于验证自动化脚本的功能。

---

## 核心组件

### 1. 自动化脚本 (`run_loop.sh`)

- **版本**：v2.1
- **职责**：基础设施保障 + 流程编排 + 异常兜底
- **核心流程**：
  ```
  环境检测 → 初始化检查 → 终止检查 → 执行 Claude → Git 兜底 → 终止检查 → 下一轮
  ```

### 2. 任务管理系统 (`.ai/`)

| 文件 | 用途 |
|------|------|
| `task.json` | 开发任务列表，按 `priority` 排序 |
| `cloud.md` | Claude 工作指令集（MECE 原则） |
| `progress.txt` | 任务完成进度日志 |
| `.blocked` | 阻塞标记文件（隐藏） |
| `live.log` | 实时运行日志 |

### 3. 终止检测机制 (MECE 原则)

- 检测 `.ai/.blocked` 文件
- 检测 `progress.txt` 中的 `BLOCKED: NEED HUMAN HELP`
- 检测 `ALL TASKS COMPLETED` 信号
- 检查 `task.json` 待办任务数量

---

## 脚本特性

### 环境适配

- **命令检测**：使用 `claude` 命令
- **权限模式**：
  - **root 用户**：不支持 `--dangerously-skip-permissions`
  - **普通用户**：可选择自动跳过或手动确认

### 安全保障

- `set -euo pipefail` 严格模式
- 单任务超时保护（默认 5 分钟）
- 最大迭代次数限制（默认 50）
- 阻塞状态立即停止

### Git 兜底机制

- 每轮迭代后自动提交未保存更改
- 推送失败重试 3 次（指数退避）
- 幂等设计（支持从失败恢复）

---

## 使用方式

### 交互式运行（推荐）

```bash
bash run_loop.sh
```

### 非交互式运行

```bash
# 普通用户自动跳过权限
MAX_ITERATIONS=100 SKIP_PERMISSIONS_FLAG="--dangerously-skip-permissions" bash run_loop.sh

# root 用户运行（无权限跳过）
sudo bash run_loop.sh
```

---

## 演示用例：待办事项应用

为验证脚本功能，项目中包含一个全栈待办事项应用作为测试目标：

### 前端 (React + Vite)

```bash
cd frontend
npm run dev    # http://localhost:5173
npm run build
```

### 后端 (Express + SQLite)

```bash
cd backend
npm start      # http://localhost:3000
node migrate.js
node seed.js
```

---

## 关键配置项

| 环境变量 | 默认值 | 说明 |
|----------|--------|------|
| `MAX_ITERATIONS` | 50 | 最大迭代次数 |
| `PROMPT_FILE` | `.ai/task.json` | 任务清单路径 |
| `SINGLE_TASK_TIMEOUT` | 300 | 单任务超时（秒） |
| `GIT_MAX_RETRY` | 3 | Git 推送重试次数 |

---

## 测试方法

### 单任务测试

用于快速验证脚本基本功能是否正常。

**task.json 配置**：
```json
[
  {
    "id": "T1",
    "title": "测试任务：创建hello.txt文件",
    "description": "在项目根目录创建一个hello.txt文件，内容为'Hello from Claude!'",
    "acceptance_criteria": ["hello.txt文件存在", "文件内容正确"],
    "priority": 1,
    "completed": false
  }
]
```

**验证点**：
- Claude 能否正确读取和执行任务
- Git 提交和推送是否成功
- task.json 状态是否正确更新
- progress.txt 日志是否正确记录

---

### 多任务测试（5个连续任务）

用于验证脚本循环执行能力和任务切换逻辑。

**task.json 配置**：
```json
[
  {"id": "T1", "title": "创建 file1.txt", "description": "创建 file1.txt，内容为 'Task 1'", "acceptance_criteria": ["file1.txt存在"], "priority": 1, "completed": false},
  {"id": "T2", "title": "创建 file2.txt", "description": "创建 file2.txt，内容为 'Task 2'", "acceptance_criteria": ["file2.txt存在"], "priority": 2, "completed": false},
  {"id": "T3", "title": "创建 file3.txt", "description": "创建 file3.txt，内容为 'Task 3'", "acceptance_criteria": ["file3.txt存在"], "priority": 3, "completed": false},
  {"id": "T4", "title": "创建 file4.txt", "description": "创建 file4.txt，内容为 'Task 4'", "acceptance_criteria": ["file4.txt存在"], "priority": 4, "completed": false},
  {"id": "T5", "title": "创建 file5.txt", "description": "创建 file5.txt，内容为 'Task 5'", "acceptance_criteria": ["file5.txt存在"], "priority": 5, "completed": false}
]
```

**验证点**：
- 任务是否按 priority 顺序执行
- 循环迭代是否正常工作
- 每个任务完成后状态是否正确更新
- 所有任务完成后是否正确触发终止条件

---

### 重置测试

重新测试前必须执行：

```bash
# 1. 清空 progress.txt
> .ai/progress.txt

# 2. 删除测试生成的文件
rm -f file*.txt hello.txt
```

---

## 故障排查

### 脚本阻塞

```bash
# 检查阻塞文件
cat .ai/.blocked
cat .ai/progress.txt | grep BLOCKED

# 清理阻塞标记（手动修复后）
rm .ai/.blocked
sed -i '/BLOCKED: NEED HUMAN HELP/d' .ai/progress.txt
```

### 重置任务（重新测试）

当需要重新测试某个任务时，**必须同时执行以下两步**：

```bash
# 1. 修改 task.json，将目标任务的 completed 改为 false

# 2. 清理 progress.txt 中的完成信号（重要！）
> .ai/progress.txt   # 清空整个文件
# 或者只删除完成信号
sed -i '/ALL TASKS COMPLETED/d' .ai/progress.txt
```

> **注意**：如果只修改 `task.json` 而不清理 `progress.txt`，脚本会检测到 `ALL TASKS COMPLETED` 信号并直接退出，不会重新执行任务。

### 查看日志

```bash
# 实时日志
tail -f .ai/live.log

# 任务进度
cat .ai/progress.txt
```
