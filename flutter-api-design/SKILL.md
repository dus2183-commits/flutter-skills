---
name: flutter-api-design
description: Flutter 接口契约设计。用户说"设计 XX 接口"、"做接口契约"、"新增 API"或 plan 完成后触发。逐个确认接口路径/方法/认证/字段/错误码,输出 docs/api/{module}.md 和 mock JSON 草稿。给 flutter-model-gen 和 flutter-api-gen 用。
type: skill
stage: 3
model: sonnet
priority: P0
version: 1.0.0
owner: @b
category: designer
---

# 接口契约设计 (flutter-api-design)

> ⚠️ **博龙的样板** — 这是渡作为示例写的第一版,博龙可以照这个格式改 model-gen 和 api-gen。

---

## 1. 触发场景

- "设计 XX 模块的接口" / "做 XX 接口契约"
- "新增 API: 公告列表 / 公告详情 / 标记已读"
- "把这几个接口的字段定一下"
- plan 完成后,workflow 自动触发
- 用户说 "做一个公告模块" 后,中间环节调用

**反例(不该触发):**
- "生成接口请求代码" → 应触发 `flutter-api-gen`
- "JSON 转 model" → 应触发 `flutter-model-gen`

---

## 2. 前置必读

- `docs/_context/tech-stack.md` (拿到 ApiClient 约定)
- `docs/_context/conventions.md` (字段命名规则)
- `docs/_context/decisions.md` (检查接口加密策略)
- `docs/specs/{module}.md` (上游 spec,如有)
- `docs/plans/{module}.md` (上游 plan,如有)
- `_design/api_client_signature.dart` (理解 ApiClient 接口契约)
- `_knowledge/artifact-templates/api.template.md` (输出格式标准)

---

## 3. 输入

**必填:**
- `module_name` (string, snake_case) — 模块英文名,如 `announce`
- `endpoints` (list) — 接口清单,每项至少包含: 中文名 + 用途
  - 例: `[{name: "公告列表", purpose: "分页查询"}, {name: "公告详情", purpose: "按 ID"}]`

**自动从上游读取(如有 spec/plan):**
- 模块中文名
- 关键字段列表(spec 第 5 段)
- 接口需求清单(spec 第 4 段)

**用户后续会被问的事:**
- 每个接口的具体字段类型
- 是否分页
- 是否需要 JWT
- 错误码段位选哪个区间(默认按模块自动分配)

---

## 4. 工作流程

### Step 1 — 读取上下文
读 `docs/_context/` 4 个文件 + 上游 spec/plan(如存在)。

### Step 2 — 检查输入完整性
若用户没指定接口列表,从 spec 第 4 段自动提取。
若 spec 也没有,ASK_USER 列出接口需求。

### Step 3 — 全局规则确认(每模块跑一次)
ASK_USER 确认这一组接口的全局规则:
- 路径前缀: `/api/{module}` 还是其他?
- 默认认证方式: JWT (默认) / HMAC / 公开
- 默认是否加密: 是(默认)/ 否
- 错误码段位: 自动分配(每模块 100 个段位,不冲突)

### Step 4 — 逐个接口确认
对每个接口:
- 4.1 确认 HTTP 方法 (POST / GET / DELETE / PUT)
- 4.2 确认完整路径 (默认 `/api/{module}/{action}`)
- 4.3 列出请求字段:
  - 字段名(camelCase)、类型、必填、说明、示例
- 4.4 列出响应结构(JSON 示例)
- 4.5 标注是否分页(若是,继承 PageReq/PageResp)
- 4.6 标注 mock key (默认 `{module}/{action}`)

**列字段的提问要求:**
- 不要假设字段类型(string vs int 容易混)
- 时间字段必须问 ISO 字符串还是时间戳
- 列表字段要问元素类型
- 嵌套对象要问是否独立 model

### Step 5 — 错误码分配
按模块预留段位(每模块 100 个):
- `{XXNNN}` — XX 是模块代号,NNN 是 1-99
- 例: announce 模块 21001-21099
- announce 模块下: 21001 参数错误 / 21002 公告不存在 / 21003 已读过 ...

记录到 docs/api/{module}.md 错误码表。

### Step 6 — 生成接口契约文档
按 `_knowledge/artifact-templates/api.template.md` 的 7 段格式写入 `docs/api/{module}.md`:
- frontmatter(artifact_type / module / version / created / parent_artifact)
- 全局规则
- 每个接口一节(路径 / mock key / 认证 / 加密 / 字段表 / 响应 JSON / 错误码)

### Step 7 — 生成 mock JSON 草稿
为每个接口生成对应的 mock JSON 文件:
- 路径: `mock/{module}/{action}.json`
- 数据按响应结构,字段值用合理示例(不是 placeholder)
- 列表数据至少 3 条,字段不重复

### Step 8 — 自检 (跑段 8 checklist)

### Step 9 — 联动建议
建议下一步用 `flutter-model-gen` 生成 freezed 实体。

---

## 5. 输出产物

```
docs/api/{module}.md                  接口契约主文档
mock/{module}/
  ├── {action1}.json                  每个接口一个 mock 文件
  ├── {action2}.json
  └── ...
```

示例:
```
docs/api/announce.md
mock/announce/
  ├── list.json
  ├── detail.json
  └── markRead.json
```

---

## 6. 文档模板

### docs/api/{module}.md 完整结构

```markdown
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

## 全局规则
- 路径前缀: `/api/announce`
- 认证: JWT
- 加密: 是 (EncryptInterceptor 自动处理)
- 错误码段位: 21001-21099

---

## 接口 1: 公告列表

**路径:** `POST /api/announce/list`
**Mock Key:** `announce/list`
**认证:** JWT
**加密:** ✅
**分页:** ✅ (PageReq)

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
        "content": "<p>详细内容...</p>",
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

### 错误码
| code | 说明 |
|---|---|
| 21001 | 参数错误 |
| 21002 | 公告不存在 |

---

## 接口 2: 公告详情
... (同样格式)

---

## 接口 3: 标记已读
... (同样格式)
```

### mock/{module}/{action}.json 模板

```json
{
  "status": "y",
  "data": {
    "list": [
      {
        "id": "65f7a8b9c1d2e3f4",
        "title": "系统升级公告",
        "content": "<p>本周日凌晨进行系统升级...</p>",
        "publishAt": "2026-04-10T10:00:00Z",
        "isRead": false
      },
      {
        "id": "65f7a8b9c1d2e3f5",
        "title": "新功能上线",
        "content": "<p>我们新增了 ...</p>",
        "publishAt": "2026-04-08T15:30:00Z",
        "isRead": true
      },
      {
        "id": "65f7a8b9c1d2e3f6",
        "title": "维护通知",
        "content": "<p>本周二晚 22:00 进行 ...</p>",
        "publishAt": "2026-04-05T09:00:00Z",
        "isRead": false
      }
    ],
    "total": 3,
    "page": 1,
    "pageSize": 20
  }
}
```

---

## 7. 不做什么 (Boundary)

- ❌ 不写 Dart 代码 (那是 model-gen 和 api-gen 的事)
- ❌ 不修改 lib/core/network/ (核心库不动)
- ❌ 不调用真实接口 (这是契约设计,不是联调)
- ❌ 不创建 lib/features/{module}/ 目录 (gen skill 做)
- ❌ 不生成 ApiClient.binding.dart (api-gen 做)
- ❌ 不修改 spec.md (只读)
- ❌ 不自动 git commit
- ❌ 不分配错误码到其他模块的段位

---

## 8. 自检 Checklist (Quality Gate)

- [ ] 每个接口有 mockKey
- [ ] 每个字段有类型 (没有 dynamic / Object)
- [ ] 路径符合 `/api/{module}/{action}` 规范
- [ ] 必填字段标注清楚
- [ ] 时间字段统一(ISO 8601 字符串 或 时间戳,不混用)
- [ ] 错误码不与其他模块冲突 (grep 现有 docs/api/*.md 验证)
- [ ] 错误码段位合理 (每模块 100 个,从 N1001 开始)
- [ ] 响应结构有完整 JSON 示例
- [ ] mock JSON 文件能被 jsonDecode 解析
- [ ] mock 数据 ≥ 3 条 (列表场景)
- [ ] mock 字段类型与契约一致 (不能 mock 是 string,契约是 int)
- [ ] frontmatter 完整 (含 parent_artifact 指向 plan)

---

## 9. 失败处理

**ASK_USER 时机:**
- 字段类型不明确 (string vs int 选哪个)
- 时间格式不明 (ISO vs timestamp)
- 错误码段位与已有冲突 (列出来让用户决定)
- 接口需要分页但 spec 没说

**STOP 时机:**
- spec/plan 文件不存在 (要先跑 spec/plan)
- 全局加密策略不明 (decisions.md 没记录)
- 模块名非法 (不是 snake_case)

**ROLLBACK:**
- 写文件失败时不留半成品
- 已写入 docs/api/{m}.md 但 mock JSON 失败 → 删除 docs/api/{m}.md

---

## 10. 联动

**成功后建议:**
> "接口契约完成: docs/api/{module}.md
>   - {N} 个接口
>   - {M} 个 mock 文件
>   - 错误码段位 {start}-{end}
>
> 下一步: 用 `flutter-model-gen` 生成 freezed 实体类"

**失败后建议:**
> "契约设计中断,详情见 docs/_failures/{date}.md
> 修复 spec 后重新调用 flutter-api-design"

**Workflow 编排关系:**
- **上游:** flutter-plan (提供 plan 文档) 或 flutter-spec (提供 spec)
- **下游:** flutter-model-gen (用 docs/api/{m}.md 生成 model)
- **平行:** flutter-theme-design (主题设计,可同时跑)

---

## 给博龙的备注

这是渡写的第一版样板,你接手后:
1. **照这个格式写** flutter-model-gen 和 flutter-api-gen
2. **代码模板段(段 6)** 必须真实可用,不要伪代码
3. **段 8 自检** 必须可机器验证
4. **段 9 失败处理** 三种情况都要写


`_design/api_client_signature.dart` 是你的"圣经",api-gen 必须严格按那里的方法签名生成代码。
