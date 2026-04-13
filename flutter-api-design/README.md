# flutter-api-design 使用说明

> 把接口需求转成标准接口契约文档。

## 什么时候用

当你需要为某个模块定义接口契约时，对 Claude 说：

- "设计公告模块的接口"
- "接口契约"
- "这是后端给的接口文档，帮我生成契约"
- "把这个 JSON 转成接口契约"
- "帮我根据这个 URL 生成接口文档"
- "这个 curl 命令转成接口契约"

**不该用这个 skill 的场景：**
- "生成接口请求代码" / "生成 repository" → 用 `flutter-api-gen`
- "JSON 转 model" / "生成 freezed 实体" → 用 `flutter-model-gen`

## 支持的输入方式

| 方式 | 示例 |
|---|---|
| 口头描述 | "公告模块需要列表、详情、标记已读三个接口" |
| 贴 JSON | 直接贴后端返回的 JSON 响应样本 |
| 贴接口文档 | 从 Apifox/Swagger/飞书复制的文字 |
| curl 命令 | 贴 curl 命令，自动提取方法、路径、请求头、请求体 |
| URL 链接 | 给 Swagger/Apifox 在线文档链接 |
| 本地文件 | 给 `.json` 或 `.md` 文件路径 |

## 输出

`docs/api/{module}.md`（默认路径，可自定义）— 标准接口契约文档，包含：

- 每个接口的路径、Mock Key、认证、加密、请求字段、响应结构
- 错误码表（自动分配段位，不与已有模块冲突）
- 自检清单

## 使用示例

### 示例 1：口头描述

```
你: 设计公告模块的接口，需要列表、详情、标记已读

Claude: [读取 context → 全局规则确认 → 补全字段 → dry-run → 生成]
  → 输出 docs/api/announce.md
  → 包含 3 个接口，错误码段位 201001-201999
```

### 示例 2：贴 JSON

```
你: 把这个 JSON 转成接口契约，模块名 announce

{
  "status": "y",
  "data": {
    "list": [{"id": "xxx", "title": "公告标题", "isRead": false}],
    "total": 100, "page": 1, "pageSize": 20
  }
}

Claude: [解析 JSON → 推断字段类型 → 补全缺失信息 → 生成]
  → 输出 docs/api/announce.md
```

### 示例 3：curl 命令

```
你: 这个 curl 命令转成接口契约，模块名 order

curl -X POST 'https://api.example.com/api/order/list' \
  -H 'Authorization: Bearer xxx' \
  -H 'Content-Type: application/json' \
  -d '{"page": 1, "pageSize": 20, "status": "pending"}'

Claude: [提取方法 POST、路径 /api/order/list、请求字段 page/pageSize/status → 补全响应结构 → 生成]
  → 输出 docs/api/order.md
```

### 示例 4：给 URL

```
你: 帮我根据这个 URL 生成接口文档 https://apifox.com/xxx，模块名 announce

Claude: [抓取 URL → 解析文档 → 归一化 → 生成]
  → 输出 docs/api/announce.md
```

### 示例 5：自定义存储路径

```
你: 设计公告模块的接口，保存到 /path/to/custom/announce-api.md

Claude: [正常流程 → 生成到指定路径]
  → 输出 /path/to/custom/announce-api.md
```

## 下一步

契约文档生成后，按流水线顺序：

1. `flutter-model-gen` — 根据契约生成 freezed 实体类
2. `flutter-api-gen` — 根据契约生成 Repository

## 注意事项

- 不会生成 mock JSON 文件、不会生成 Dart 代码
- 不会覆盖已有契约文档（除非你明确要求）
- 缺失的关键信息（接口名、路径、字段）会问你确认
- 认证默认 JWT、加密默认开启，可在确认时修改
