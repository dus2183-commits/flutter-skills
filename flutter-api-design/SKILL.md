---
name: flutter-api-design
description: |
  用户给接口需求（口头描述/JSON/文档/URL/文件），生成接口契约文档。
  触发: "设计接口" / "接口契约" / "api design"。
type: skill
stage: 3
model: sonnet
priority: P0
version: 1.0.0
owner: @b
category: designer
---

# 接口契约设计 (flutter-api-design)

## 1. 触发场景

- "设计 XX 模块的接口" / "定义 XX 的 API"
- "接口契约" / "api design"
- "这是后端给的接口文档，帮我生成契约"
- "把这个 JSON 转成接口契约"
- "帮我根据这个 URL 生成接口文档"
- "这个 curl 命令转成接口契约"

**反例（不该触发）：**
- "生成接口请求代码" / "生成 repository" → 应触发 `flutter-api-gen`
- "JSON 转 model" / "生成 freezed 实体" → 应触发 `flutter-model-gen`

## 2. 前置必读

- `docs/_context/tech-stack.md`  (拿到 ApiClient 约定)
- `docs/_context/conventions.md` (字段命名规则)
- `docs/_context/decisions.md` (检查接口加密策略)
- `docs/_context/glossary.md`
- `docs/specs/{module}.md` (上游 spec,如有)
- `docs/plans/{module}.md` (上游 plan,如有)
- `_design/api_client_signature.dart` (理解 ApiClient 方法签名，保证契约与 ApiClient 对齐)
- `_knowledge/artifact-templates/api.template.md`
- `docs/api/*.md`（已有契约，用于避免错误码段位冲突）

## 3. 输入

**必填参数：**
- `module_name` (string) — 模块英文名，snake_case
- `source` (string) — 用户输入（自然语言 / JSON / 文档文本 / URL / 文件路径）

**可选参数：**
- `force_overwrite` (bool, default false) — 是否覆盖已有契约文档
- `output_path` (string, default `docs/api/{module}.md`) — 自定义输出路径

**自动从上游读取(如有 spec/plan):**
- 模块中文名
- 关键字段列表(spec 第 5 段)
- 接口需求清单(spec 第 4 段)

**输入分流：**

| 形式 | 识别特征 | 解析方式 |
|---|---|---|
| 口头描述 | 自然语言，无结构化数据 | LLM 提取意图，AskUser 补全 |
| 贴 JSON 响应样本 | 包含 `{` 和 `}` 的 JSON 结构 | 解析 JSON，推断字段类型和结构 |
| 贴接口文档文本 | 包含路径、参数、响应等关键词 | LLM 结构化提取 |
| curl 命令 | 以 `curl` 开头 | 提取方法、路径、请求头、请求体，推断认证/Content-Type/请求字段 |
| URL 链接 | 以 http/https 开头（非 curl） | WebFetch 抓取后按文档文本处理 |
| 本地文件路径 | 以 `/` 或 `./` 开头，或 `.json`/`.md` 后缀 | Read 文件后按内容类型分流 |

## 4. 工作流程

**Pipeline:** 任何输入 → 识别输入类型 → 归一化为中间态 → 补全缺失信息 → 按模板输出

**Step 1 — 读 context**
读取段 2 所有前置文件。重点读 `docs/api/` 下已有契约，提取已占用的错误码段位。

**Step 2 — 识别输入类型 & 解析**
- URL → WebFetch 抓取内容
- 本地文件 → Read 读取内容
- 所有形式 → 归一化为中间态

归一化中间态：

    模块名: xxx
    错误码段位: 2{XX}001-2{XX}999
    接口清单:
      - 接口中文名: 列表
        路径: POST /api/xxx/list
        Mock Key: xxx/list
        认证: JWT
        加密: ✅
        幂等: ❌
        频控: 100/min/user
        请求字段: [{字段, 类型, 必填, 说明, 示例}]
        响应结构: (完整 JSON 示例，含 status/data 包装)
        错误响应: (完整 JSON 示例，含 errorCode)

**Step 3 — 全局规则确认（每模块首次 AskUser）**
若该模块是首次设计契约，AskUser 确认以下全局规则（后续接口沿用，不重复问）：
- 路径前缀: `/api/{module}` 还是其他？
- 默认认证方式: JWT (默认) / HMAC / 公开
- 默认是否加密: 是(默认) / 否
- 错误码段位: 自动分配(默认) / 手动指定

若用户全部接受默认值，一次确认即可跳过。

**Step 4 — 补全缺失信息**

接口中文名、路径、请求字段、响应结构为必填项，缺失时 AskUser 补全。

> **重要：** 请求字段不能仅靠推断。即使能从响应结构推断出部分请求字段（如分页参数 page/pageSize），仍必须 AskUser 确认完整的请求字段列表。用户可能有额外的筛选、排序等参数，这些从响应 JSON 中无法推断。

**字段确认规则（逐条遵守）：**
- 不要假设字段类型（string vs int 容易混，必须确认）
- 时间字段必须问用户：ISO 8601 字符串还是时间戳，不能自行决定
- 列表字段要问元素类型（`List<String>` vs `List<Object>` 差别大）
- 嵌套对象要问是否需要独立 model（影响 model-gen 拆分粒度）

其余字段按以下默认值处理：

| 字段 | 默认值 |
|---|---|
| Mock Key | 自动推导: `{module}/{action}` |
| 认证 | JWT |
| 加密 | ✅ |
| 幂等 | ❌ |
| 频控 | 不限 |
| 错误码 | 自动分配（见下方算法） |

**错误码段位分配算法：**
- 格式: `2{XX}{NNN}` — XX 为 2 位模块序号(01-99)，NNN 为 3 位错误序号(001-999)
- 最多支持 99 个模块，每模块 999 个错误码
- 读 `docs/api/` 已有契约段位，取下一个可用模块序号
- 例: 已有 201001-201999(模块 01)，新模块分配 202001-202999(模块 02)
- 如果 99 个段位已用完，AskUser 确认扩展方案

**Step 5 — Dry-run (AskUser)**
列出文件路径（默认 `docs/api/{module}.md`，用户可指定 `output_path`）+ 接口清单摘要，使用 AskUserQuestion 提供三个选项：
1. **确认生成** — 进入 Step 6
2. **不要生成** — stop，不生成文件
3. **补充其他项** — 回到 Step 4，用户补充或修改接口信息后重新 dry-run

**Step 6 — 生成契约文档**
按 `api.template.md` 格式，使用 Write 工具写入 `output_path`（默认 `docs/api/{module}.md`）。

**Step 7 — 自检**
跑段 8 checklist，逐项验证。

**Step 8 — 输出总结**
输出格式：
> "接口契约完成: {output_path}
>   - {N} 个接口
>   - 错误码段位 {start}-{end}
>
> 下一步: 用 `flutter-model-gen` 生成 freezed 实体类"

## 5. 输出产物

    {output_path}    — 接口契约文档（默认 docs/api/{module}.md，可自定义）

格式完全遵循 `_knowledge/artifact-templates/api.template.md`。

## 6. 文档模板

`````markdown
---
artifact_type: api
module: announce
version: 1
created: 2026-04-10
created_by: flutter-api-design
parent_artifact: docs/plans/announce.md
status: draft
owner: @b
---

# 公告 - 接口契约

> 本文档定义模块的接口契约。`flutter-model-gen` 和 `flutter-api-gen` 据此生成代码。
>
> 错误码段位: 201001-201999

---

## 全局规则

- **认证:** 所有接口需 JWT Bearer Token (除标注 公开)
- **加密:** 默认走 AES-CBC 动态密钥(EncryptInterceptor 处理)
- **响应格式:** 统一 `{status: 'y'|'n', errorCode?, error?, data}`
- **Mock 路径:** `mock/announce/{api_name}.json`

---

## 接口 1: 公告列表

**路径:** `POST /api/announce/list`
**Mock Key:** `announce/list`
**认证:** JWT
**加密:** ✅
**幂等:** ❌
**频控:** 100/min/user

### 请求字段

| 字段 | 类型 | 必填 | 说明 | 示例 |
|---|---|---|---|---|
| page | int | 是 | 页码，从 1 开始 | 1 |
| pageSize | int | 是 | 每页数量(1-100) | 20 |
| keyword | string | 否 | 搜索关键字 | "更新" |

### 响应结构

````json
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
````

### 错误响应

````json
{
  "status": "n",
  "errorCode": 201001,
  "error": "参数错误"
}
````

---

## 接口 2: 公告详情

**路径:** `GET /api/announce/detail`
**Mock Key:** `announce/detail`
**认证:** JWT
**加密:** ✅
**幂等:** ✅
**频控:** 不限

### 请求字段

| 字段 | 类型 | 必填 | 说明 | 示例 |
|---|---|---|---|---|
| id | string | 是 | 公告 ID | "65f7a8b9c1d2e3f4" |

### 响应结构

````json
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
````

---

## 接口 3: 标记已读

**路径:** `POST /api/announce/markRead`
**Mock Key:** `announce/markRead`
**认证:** JWT
**加密:** ✅
**幂等:** ✅
**频控:** 不限

### 请求字段

| 字段 | 类型 | 必填 | 说明 | 示例 |
|---|---|---|---|---|
| id | string | 是 | 公告 ID | "65f7a8b9c1d2e3f4" |

### 响应结构

````json
{
  "status": "y",
  "data": null
}
````

---

## 错误码表

| code | 含义 | HTTP 状态 |
|---|---|---|
| 201001 | 参数错误 | 200 |
| 201002 | 公告不存在 | 200 |
| 201003 | 已读过 | 200 |
| 201099 | 服务异常 | 200 |

> 注意: 业务错误统一 HTTP 200，实际错误在 `errorCode` 字段。
`````

## 7. 不做什么

- ❌ 不生成 mock JSON 文件（交给下游）
- ❌ 不生成 Dart 代码（交给 model-gen 和 api-gen）
- ❌ 不修改已有契约文档（如需更新，用户应明确要求覆盖）
- ❌ 不校验后端接口是否真实可用（只做文档设计）
- ❌ 不分配超出本模块的错误码

## 8. 自检 Checklist

- [ ] 每个接口有 Mock Key
- [ ] 字段类型明确（无 dynamic / Object）
- [ ] 时间字段格式统一（全部 ISO 8601 字符串或全部时间戳，不混用）
- [ ] 错误码段位不与已有模块冲突（grep `docs/api/*.md` 验证）
- [ ] 路径符合 `/api/{module}/{action}` 规范
- [ ] 必填字段已标注
- [ ] 响应有完整 JSON 示例（含 status/data 包装）
- [ ] 错误响应示例至少展示一次，错误码表覆盖所有接口
- [ ] frontmatter 字段完整
- [ ] frontmatter `parent_artifact` 指向存在的上游文档，或为空（如无上游文档）

## 9. 失败处理

**何时 ask user：**
- 输入模糊，无法确定接口数量或字段
- 字段类型不明确（string vs int 选哪个）
- 时间格式不明（ISO 8601 vs timestamp）
- 将覆盖已有文件（`force_overwrite` 未设置）
- 用户拒绝 dry-run 结果
- 错误码段位与已有模块冲突（列出冲突让用户决定）

**何时 stop：**
- URL 抓取失败
- 本地文件不存在或内容无法解析
- 用户拒绝 dry-run
- 模块名非法（不是 snake_case）

**何时 rollback：**
- 自检失败 → 删除已生成的 `docs/api/{module}.md`
- 写入中途失败 → 删除不完整文件，不留半成品

## 10. 联动

**成功后建议：**
> "接口契约完成: {output_path}
>   - {N} 个接口
>   - 错误码段位 {start}-{end}
>
> 下一步: 用 `flutter-model-gen` 生成 freezed 实体类"

**失败后回退：**
> "契约设计中断。请检查输入格式，或直接用口头描述接口需求。"

**上游：** flutter-spec / flutter-plan
**下游：** flutter-model-gen → flutter-api-gen
**平行：** flutter-theme-design（主题设计，可同时跑）

> **Mock 归属说明：** 本 skill 不生成 mock JSON 文件。mock 数据由下游 `flutter-api-gen` 根据契约文档自动生成。
