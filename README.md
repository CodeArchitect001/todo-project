# Claude 全自动开发循环脚本

一个任务驱动的自动化开发流程脚本 (`run_loop.sh`)，实现 Claude 自动执行开发任务的闭环系统。

## 核心功能

- **自动化循环**：持续执行 `task.json` 中的开发任务
- **终止检测**：自动检测任务完成、阻塞状态
- **Git 兜底**：每轮迭代后自动提交和推送代码
- **安全保护**：超时控制、最大迭代限制

## 快速开始

```bash
# 交互式运行（推荐）
bash run_loop.sh

# 非交互式运行
MAX_ITERATIONS=100 bash run_loop.sh
```

## 项目结构

```
.
├── run_loop.sh      # 主脚本
├── CLAUDE.md        # 项目说明和记忆
└── .ai/
    ├── task.json    # 任务清单
    ├── cloud.md     # Claude 工作指令
    ├── progress.txt # 进度日志
    └── live.log     # 实时日志
```

## 任务配置

在 `.ai/task.json` 中定义任务：

```json
[
  {
    "id": "T1",
    "title": "任务标题",
    "description": "任务描述",
    "acceptance_criteria": ["验收条件"],
    "priority": 1,
    "completed": false
  }
]
```

## 关键配置

| 环境变量 | 默认值 | 说明 |
|----------|--------|------|
| `MAX_ITERATIONS` | 50 | 最大迭代次数 |
| `SINGLE_TASK_TIMEOUT` | 300 | 单任务超时（秒） |

## 故障排查

```bash
# 查看实时日志
tail -f .ai/live.log

# 查看进度
cat .ai/progress.txt

# 清理阻塞标记
rm .ai/.blocked
```

## 演示项目

待办事项应用 (React + Express + SQLite) 作为**演示/测试用例**：

```bash
# 后端
cd backend && npm start    # http://localhost:3000

# 前端
cd frontend && npm run dev # http://localhost:5173
```

## 详细文档

参见 [CLAUDE.md](./CLAUDE.md)
