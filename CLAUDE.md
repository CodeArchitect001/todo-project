# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

这是一个基于 React + Express + SQLite 的全栈待办事项 Web 应用。项目采用任务驱动开发模式，通过 `.ai/task.json` 管理开发任务。

## Project Structure

```
.
├── frontend/          # React 前端 (Vite)
│   ├── package.json   # 前端依赖和脚本
│   └── ...
├── backend/           # Express 后端
│   ├── package.json   # 后端依赖和脚本
│   ├── index.js       # 服务入口
│   ├── database.js    # SQLite 数据库连接和工具函数
│   ├── migrate.js     # 数据库迁移脚本
│   ├── seed.js        # 测试数据种子
│   └── todos.db       # SQLite 数据库文件
├── .ai/               # AI 任务管理
│   ├── task.json      # 任务列表 (开发蓝图)
│   ├── cloud.md       # Claude 自动开发提示词
│   └── live.log       # 运行日志
└── run_loop.sh        # 自动化开发脚本
```

## Common Commands

### Frontend Development

```bash
cd frontend
npm install        # 安装依赖
npm run dev        # 启动开发服务器 (http://localhost:5173)
npm run build      # 生产构建
npm run lint       # ESLint 检查
```

### Backend Development

```bash
cd backend
npm install        # 安装依赖
npm start          # 启动服务 (http://localhost:3000)
node migrate.js    # 运行数据库迁移
node seed.js       # 填充测试数据
```

### Automated Development

```bash
# 交互式运行（推荐用于开发）
bash run_loop.sh

# 非 root 用户可选择启用 --dangerously-skip-permissions 模式
# root 用户无法使用自动权限跳过模式
```

## Architecture

### Frontend

- **Framework**: React 19 + Vite
- **Module System**: ES Modules (`"type": "module"`)
- **Dev Server**: Vite dev server on port 5173
- **Linting**: ESLint with react-hooks and react-refresh plugins

### Backend

- **Framework**: Express 5
- **Module System**: CommonJS (`"type": "commonjs"`)
- **Database**: SQLite3 with Promise 包装器
- **CORS**: 已启用，支持跨域请求
- **Port**: 3000 (可通过 `PORT` 环境变量覆盖)

### Database Layer (`backend/database.js`)

提供了 Promise 化的 SQLite 操作工具：

- `db` - SQLite 数据库连接实例
- `initDatabase()` - 初始化 todos 表
- `runQuery(sql, params)` - 执行 INSERT/UPDATE/DELETE，返回 `{id, changes}`
- `allQuery(sql, params)` - 执行 SELECT，返回所有行
- `getQuery(sql, params)` - 执行 SELECT，返回单行

### API Endpoints (已规划)

- `GET /api/health` - 健康检查
- `GET /api/todos` - 获取所有待办事项
- `POST /api/todos` - 创建待办事项
- `PATCH /api/todos/:id` - 更新待办事项
- `DELETE /api/todos/:id` - 删除待办事项

## Task-Driven Development Workflow

本项目使用 `.ai/task.json` 作为开发蓝图：

1. **任务格式**: 每个任务包含 `id`, `title`, `description`, `acceptance_criteria`, `priority`, `completed`
2. **优先级**: `priority` 数值越小优先级越高
3. **工作流程**:
   - 读取 `.ai/task.json`
   - 选择 `completed: false` 且 `priority` 最小的任务
   - 实现功能
   - 标记 `completed: true`
   - Git commit: `feat: 完成任务T#[ID] - [描述]`

### Claude Settings

项目配置了 `.claude/settings.local.json`，预授权了常用命令：
- npm 相关命令 (create, install, init)
- Git 操作 (add, commit)
- Node 脚本执行

### Automated Loop (`run_loop.sh`)

全自动开发脚本特性：
- 迭代执行任务直到全部完成或达到最大次数 (默认 50)
- 每个任务 5 分钟超时
- 自动 Git 提交和推送
- 阻塞检测和恢复机制
- **root 用户限制**: 不支持 `--dangerously-skip-permissions`

## Important Files

| File | Purpose |
|------|---------|
| `.ai/task.json` | 开发任务列表，按 priority 排序 |
| `.ai/cloud.md` | Claude 自动开发提示词，包含阶段指令 |
| `.ai/progress.txt` | 任务完成日志 |
| `.ai/.blocked` | 阻塞标记文件 |
| `backend/todos.db` | SQLite 数据库，已包含测试数据 |
