---
artifact_type: api
module: {{module_name}}
version: 1
created: {{YYYY-MM-DD}}
created_by: flutter-api-design
parent_artifact: docs/plans/{{module_name}}.md
status: draft
owner: @{{owner}}
---

# {{module_chinese_name}} - 接口契约

> 本文档定义模块的接口契约。`flutter-model-gen` 和 `flutter-api-gen` 据此生成代码。
>
> 错误码段位: {{module_code_range}} (例: 21001-21999)

---

## 全局规则

- **认证:** 所有接口需 JWT Bearer Token (除标注 公开)
- **加密:** 默认走 AES-CBC 动态密钥(EncryptInterceptor 处理)
- **响应格式:** 统一 `{status: 'y'|'n', errorCode?, error?, data}`
- **Mock 路径:** `mock/{{module_name}}/{api_name}.json`

---

## 接口 1: {{接口中文名}}

**路径:** `POST /api/{{module_name}}/list`
**Mock Key:** `{{module_name}}/list`
**认证:** JWT
**加密:** ✅
**幂等:** ❌
**频控:** 100/min/user

### 请求字段

| 字段 | 类型 | 必填 | 说明 | 示例 |
|---|---|---|---|---|
| page | int | 是 | 页码,从 1 开始 | 1 |
| pageSize | int | 是 | 每页数量(1-100) | 20 |
| keyword | string | 否 | 搜索关键字 | "更新" |

### 响应结构

```json
{
  "status": "y",
  "data": {
    "list": [
      {
        "id": "65f7a8b9c1d2e3f4",
        "title": "系统升级公告",
        "content": "<p>...</p>",
        "publishAt": "2026-04-10T10:00:00Z",
        "isRead": false
      }
    ],
    "total": 100,
    "page": 1,
    "pageSize": 20
  }
}
```

### 错误响应

```json
{
  "status": "n",
  "errorCode": 21001,
  "error": "参数错误"
}
```

---

## 接口 2: 公告详情

**路径:** `GET /api/{{module_name}}/detail`
**Mock Key:** `{{module_name}}/detail`
**认证:** JWT

### 请求字段

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| id | string | 是 | 公告 ID |

### 响应结构

```json
{
  "status": "y",
  "data": {
    "id": "65f7a8b9c1d2e3f4",
    "title": "系统升级公告",
    "content": "<p>详细内容...</p>",
    "publishAt": "2026-04-10T10:00:00Z",
    "isRead": false,
    "author": "运营团队"
  }
}
```

---

## 接口 3: 标记已读

**路径:** `POST /api/{{module_name}}/markRead`
**Mock Key:** `{{module_name}}/markRead`
**认证:** JWT

### 请求字段

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| id | string | 是 | 公告 ID |

### 响应结构

```json
{
  "status": "y",
  "data": null
}
```

---

## 错误码表

| code | 含义 | HTTP 状态 |
|---|---|---|
| 21001 | 参数错误 | 200 |
| 21002 | 公告不存在 | 200 |
| 21003 | 已读过 | 200 |
| 21099 | 服务异常 | 200 |

> 注意: 业务错误统一 HTTP 200,实际错误在 `errorCode` 字段。
> 这是 yc141 的约定,与 RESTful 不同。

---

## Quality Gate G3 自检

- [ ] 每个接口有 mock key
- [ ] 字段类型明确(无 dynamic / Object)
- [ ] 错误码不与其他模块冲突
- [ ] 路径符合 `/api/{module}/{action}` 规范
- [ ] 必填字段标注
- [ ] 响应有完整示例
