---
name: flutter-api-doc
description: |
  接口规范 → Markdown 文档。将后端接口契约转化为前端友好的接口文档。
  触发场景：用户说"生成接口文档"、"这个接口怎么调"、"整理接口清单"。
type: skill
stage: 6
model: sonnet
priority: P2
version: 1.0.0
owner: @lead
category: transformer
---

# 接口文档生成 (flutter-api-doc)

## 1. 触发场景
- "生成接口文档"
- "从 Swagger 生成前端接口清单"
- "整理这些接口的用法"
- "给我一份接口 API 说明"
- "这个接口怎么调，参数是什么"

## 2. 前置必读
- `docs/_context/tech-stack.md`
- `docs/_context/conventions.md`
- `_knowledge/artifact-templates/review.template.md` (文档结构参考)

## 3. 输入

**必填:**
- 接口来源: Swagger URL / OpenAPI JSON / 手工描述

**自动识别:**
- 接口数量和复杂度
- 认证方式 (OAuth / Bearer Token / API Key)
- 请求/响应格式 (JSON / XML 等)

## 4. 工作流程

**Step 1 — 读取接口规范**

如果用户提供 Swagger 链接:
- 从 Swagger UI 或 OpenAPI JSON 提取接口信息
- 解析: path / method / 参数 / 响应

如果是手工描述:
- 要求用户补充必要信息

**Step 2 — 标准化接口信息**

提取每个接口的:
- 端点 (URL path)
- HTTP 方法 (GET/POST/DELETE 等)
- 简短描述 (一句话)
- 必填参数
- 可选参数
- 请求示例
- 响应示例
- 错误码

**Step 3 — 分类整理**

按业务模块分组 (用户/订单/公告 等)。

**Step 4 — 生成文档**

见下方段 6。

**Step 5 — 提醒创建 Model**

根据接口响应，建议创建对应的 Dart Model。

## 5. 输出产物

生成一份 Markdown 接口文档，通常存放在 `docs/api/{module}.md` 或 `docs/api/all_endpoints.md`。

**文件命名:** `api_{module}_doc.md` 或 `api_doc.md`。

## 6. 模板示例

```markdown
---
artifact_type: api_doc
created: 2026-04-10
created_by: flutter-api-doc
---

# 接口文档 · Announcement（公告）

## 0. 总览

| 端点 | 方法 | 描述 |
|------|------|------|
| `/api/v1/announcements` | GET | 获取公告列表 |
| `/api/v1/announcements/{id}` | GET | 获取公告详情 |
| `/api/v1/announcements/{id}/read` | PATCH | 标记为已读 |
| `/api/v1/announcements/categories` | GET | 获取分类列表 |

---

## 1. 认证 (Authentication)

所有请求需在 Header 中携带 Bearer Token:

```
Authorization: Bearer {access_token}
```

Token 获取方式见[登录接口文档](../auth/login.md)。

---

## 2. 获取公告列表

### 请求

**端点:** `GET /api/v1/announcements`

**参数:**

| 参数名 | 类型 | 必填 | 默认值 | 描述 |
|--------|------|------|--------|------|
| skip | int | ❌ | 0 | 跳过条数(分页) |
| limit | int | ❌ | 20 | 每页条数 |
| category | string | ❌ | 无 | 筛选分类 (system/update/activity) |
| search | string | ❌ | 无 | 按标题搜索(模糊匹配) |

**示例:**

```bash
curl -X GET "https://api.example.com/api/v1/announcements?skip=0&limit=20&category=system" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 响应

**Status: 200 OK**

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "items": [
      {
        "id": "ann_001",
        "title": "系统维护通知",
        "category": "system",
        "content": "今晚 22:00 - 23:00 系统维护...",
        "imageUrl": "https://cdn.example.com/ann_001.jpg",
        "createdAt": "2026-04-09T10:30:00Z",
        "isRead": false,
        "priority": 1
      },
      {
        "id": "ann_002",
        "title": "版本更新",
        "category": "update",
        "content": "V2.0 新增暗黑模式支持...",
        "imageUrl": null,
        "createdAt": "2026-04-08T15:20:00Z",
        "isRead": true,
        "priority": 2
      }
    ],
    "total": 120,
    "skip": 0,
    "limit": 20
  }
}
```

**字段说明:**

| 字段 | 类型 | 描述 |
|------|------|------|
| id | string | 公告唯一标识 |
| title | string | 标题 |
| category | string | 分类 (system/update/activity) |
| content | string | 正文内容 |
| imageUrl | string \| null | 封面图 URL (可选) |
| createdAt | timestamp | 发布时间 (ISO 8601 格式) |
| isRead | bool | 是否已读 (该用户视角) |
| priority | int | 优先级 (1-5，1 最高) |
| total | int | 符合条件的总条数 |

**错误响应 (400):**

```json
{
  "code": 400,
  "message": "Invalid category",
  "data": null
}
```

---

## 3. 获取公告详情

### 请求

**端点:** `GET /api/v1/announcements/{id}`

**路径参数:**

| 参数名 | 类型 | 必填 | 描述 |
|--------|------|------|------|
| id | string | ✅ | 公告 ID |

**示例:**

```bash
curl -X GET "https://api.example.com/api/v1/announcements/ann_001" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 响应

**Status: 200 OK**

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "id": "ann_001",
    "title": "系统维护通知",
    "category": "system",
    "content": "今晚 22:00 - 23:00 系统维护...",
    "imageUrl": "https://cdn.example.com/ann_001.jpg",
    "author": {
      "id": "user_admin",
      "name": "系统管理员",
      "avatarUrl": "https://cdn.example.com/avatar.jpg"
    },
    "createdAt": "2026-04-09T10:30:00Z",
    "updatedAt": "2026-04-09T10:30:00Z",
    "isRead": false
  }
}
```

**错误响应 (404):**

```json
{
  "code": 404,
  "message": "Announcement not found",
  "data": null
}
```

---

## 4. 标记公告为已读

### 请求

**端点:** `PATCH /api/v1/announcements/{id}/read`

**路径参数:**

| 参数名 | 类型 | 必填 | 描述 |
|--------|------|------|------|
| id | string | ✅ | 公告 ID |

**请求体:** 无

**示例:**

```bash
curl -X PATCH "https://api.example.com/api/v1/announcements/ann_001/read" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 响应

**Status: 200 OK**

```json
{
  "code": 0,
  "message": "Marked as read",
  "data": {
    "id": "ann_001",
    "isRead": true
  }
}
```

---

## 5. 获取分类列表

### 请求

**端点:** `GET /api/v1/announcements/categories`

**参数:** 无

**示例:**

```bash
curl -X GET "https://api.example.com/api/v1/announcements/categories" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 响应

**Status: 200 OK**

```json
{
  "code": 0,
  "message": "success",
  "data": [
    {
      "key": "system",
      "name": "系统通知",
      "color": "#1A73E8",
      "icon": "ic_system"
    },
    {
      "key": "update",
      "name": "版本更新",
      "color": "#EA8B00",
      "icon": "ic_update"
    },
    {
      "key": "activity",
      "name": "活动",
      "color": "#34A853",
      "icon": "ic_activity"
    }
  ]
}
```

---

## 6. 错误码速查

| Code | HTTP | 含义 | 处理方式 |
|------|------|------|---------|
| 0 | 200 | 成功 | — |
| 400 | 400 | 请求参数错误 | 检查参数 |
| 401 | 401 | Token 过期或无效 | 重新登录 |
| 403 | 403 | 无权限访问 | 检查用户权限 |
| 404 | 404 | 资源不存在 | 检查 ID 是否正确 |
| 500 | 500 | 服务端错误 | 联系后端 / 重试 |

---

## 7. 前端集成建议

### 创建对应的 Dart Model

```dart
// lib/features/announcement/models/announcement.dart
class Announcement {
  final String id;
  final String title;
  final String category;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;
  final bool isRead;
  final int priority;

  const Announcement({
    required this.id,
    required this.title,
    required this.category,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    required this.isRead,
    required this.priority,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'],
      title: json['title'],
      category: json['category'],
      content: json['content'],
      imageUrl: json['imageUrl'],
      createdAt: DateTime.parse(json['createdAt']),
      isRead: json['isRead'],
      priority: json['priority'],
    );
  }
}
```

### 创建 Repository

```dart
// lib/features/announcement/data/announcement_repository.dart
class AnnouncementRepository {
  final ApiClient _apiClient;

  Future<List<Announcement>> getList({
    int skip = 0,
    int limit = 20,
    String? category,
    String? search,
  }) async {
    final response = await _apiClient.get(
      '/api/v1/announcements',
      queryParameters: {
        'skip': skip,
        'limit': limit,
        if (category != null) 'category': category,
        if (search != null) 'search': search,
      },
    );
    return (response['data']['items'] as List)
        .map((e) => Announcement.fromJson(e))
        .toList();
  }

  Future<Announcement> getDetail(String id) async {
    final response = await _apiClient.get('/api/v1/announcements/$id');
    return Announcement.fromJson(response['data']);
  }

  Future<void> markAsRead(String id) async {
    await _apiClient.patch('/api/v1/announcements/$id/read');
  }
}
```

---

## 8. 调试

### 在线 API 测试工具

- Postman: https://www.postman.com/
- Swagger UI: {server}/api/swagger

### 常见问题

**Q: 无法获取列表，返回 401？**
A: Token 过期了。重新登录获取新 Token。

**Q: Category 参数怎么知道有哪些值？**
A: 调用 "获取分类列表" 接口拿到实时的分类列表。

**Q: 单次查询最多能要多少条记录？**
A: limit 最大 100，超过 100 需要分页查询。

```

## 7. 不做什么

- ❌ 不生成接口实现代码 (只生成文档)
- ❌ 不修改后端接口规范 (只转述)
- ❌ 不生成数据库设计 (后端的事)
- ❌ 不生成客户端代码 (只建议)
- ❌ 不自动 commit

## 8. 自检 Checklist

- [ ] 所有接口都列出了
- [ ] 每个接口都有请求和响应示例
- [ ] 参数说明清楚（必填/可选/默认值）
- [ ] 错误码有说明和处理建议
- [ ] 给出了前端集成示例 (Model + Repository)
- [ ] 附加了调试方式

## 9. 失败处理

**接口规范不清楚时:**
> ASK_USER "接口文档不完整，需要后端补充: ..."

**参数格式不确定时:**
> "这个参数的格式不清楚，建议: (选项 A) / (选项 B)，哪个对？"

## 10. 联动

**成功后:**
> "✅ 接口文档已生成。
> - 共 {N} 个接口，按 {分类} 分组
> - 建议后续: 用 `flutter-page-gen` 生成对应的 Repository
> - 需要调试: 用 Postman 验证一遍实际请求"

**上游:**
- flutter-spec (需求文档中列出的接口)
- 后端 API 规范 / Swagger

**下游:**
- flutter-page-gen (生成调用这些接口的页面代码)
- flutter-design-to-code (设计稿中可能涉及这些数据)
