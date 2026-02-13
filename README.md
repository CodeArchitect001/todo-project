# 个人待办事项 Web 应用

一个基于 React + Express 的全栈待办事项应用。

## 项目结构

```
.
├── frontend/    # React 前端项目 (Vite)
├── backend/     # Express 后端项目
└── .ai/         # 任务管理
```

## 启动命令

### 后端

```bash
cd backend
npm start
```

后端服务将在 http://localhost:3000 启动

### 前端

```bash
cd frontend
npm run dev
```

前端开发服务器将在 http://localhost:5173 启动

## API 接口

- `GET /api/health` - 健康检查
- `GET /api/todos` - 获取所有待办事项
- `POST /api/todos` - 创建待办事项
- `PATCH /api/todos/:id` - 更新待办事项
- `DELETE /api/todos/:id` - 删除待办事项
