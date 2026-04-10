---
name: flutter-spec
description: Flutter 需求设计文档生成。用户说"做 XX 模块"、"新需求"、"设计 XX 功能"或描述功能需求时触发。把自然语言需求拆解成结构化 spec.md(7 段:目标/页面/流转/接口/字段/异常/非功能),给 flutter-plan 拆任务用。
type: skill
stage: 1
model: opus
priority: P0
version: 1.0.0
owner: @c
category: designer
---

# 需求设计 (flutter-spec)

> ⚠️ **张和锋的样板** — 这是渡作为示例写的第一版,张和锋可以照这个格式改 page-gen / review / api-doc 等。

---

## 1. 触发场景

- "做一个 XX 模块" / "做 XX 功能"
- "新需求: ..." / "实现 XX"
- "设计 XX 模块的交互"
- "我想加一个 XX 页面"
- workflow 自动触发 (作为 flutter-flow-feature 的第一步)

**反例(不该触发):**
- "拆任务" → 应触发 `flutter-plan` (spec 的下游)
- "生成代码" → 应触发对应 gen skill
- "评审" → 应触发 `flutter-review`

---

## 2. 前置必读

- `docs/_context/tech-stack.md`
- `docs/_context/conventions.md` (字段命名 / 模块命名规则)
- `docs/_context/glossary.md` (项目术语,避免重名)
- `docs/_context/decisions.md` (检查是否有相关决策)
- `_knowledge/artifact-templates/spec.template.md` (输出格式标准)

**注意:** 不要读 docs/api/ 或 lib/features/(那是后续阶段的事,spec 不该被代码影响)。

---

## 3. 输入

**必填:**
- 用户的自然语言需求 (任意长度)

**会被自动追问的(若用户没说):**
- 模块英文名 (snake_case)
- 模块中文名
- 目标用户 (新用户/老用户/管理员/...)
- 关键交互(点击/拖动/扫码...)
- 数据来源 (后端接口/本地存储/混合)
- 是否需要登录
- 是否需要支付
- 是否需要权限 (相机/位置/通知...)

**用户 likely 模糊的地方,要问清:**
- "做一个公告模块" → 是只有列表,还是带详情/已读/分类?
- "做用户中心" → 哪些字段?哪些操作?
- "实现订单" → 创建?查询?支付?退款?

---

## 4. 工作流程

### Step 1 — 读取上下文
读 `docs/_context/` 4 个文件 + spec.template.md。

### Step 2 — 解析用户需求,提炼关键信息
不要立刻开始问,先把用户说的拆成 5 类:
1. **核心实体** - 名词 (公告 / 用户 / 订单)
2. **核心动作** - 动词 (查看 / 标记 / 提交)
3. **角色** - 谁用 (普通用户 / 管理员)
4. **场景** - 在什么情境下用 (启动后 / 收到推送后)
5. **约束** - 必须 / 不要 / 优先 (必须支持离线 / 不要弹窗 / 优先 web 端)

### Step 3 — 确认模块命名
- ASK_USER 模块英文名 (snake_case),给 1-2 个建议
- 检查 `lib/features/` 是否已有同名(冲突则改名)
- 检查 `docs/_context/glossary.md` 是否有相关术语
- 确认中文名

### Step 4 — 列出涉及页面
- ASK_USER 涉及哪些页面 (let user list, 然后回填表格)
- 每个页面给一个 id (snake_case) + 中文名 + 一句话描述
- 推断是列表型 / 详情型 / 表单型 / 自定义

### Step 5 — 画页面流转图 (ASCII)
- 从入口开始 (App 启动 / 某 Tab / 推送)
- 列出所有跳转
- 标注分支条件 (登录态 / 权限 / 数据状态)
- 用 ASCII art (mermaid 也可)

### Step 6 — 列出接口需求(粗粒度)
- 不要细化字段(那是 api-design 的事)
- 只列: 接口中文名 / 用途 / HTTP 方法
- 给个数量预估 (≥1, ≤10)

### Step 7 — 列出关键字段
- 模块的核心实体字段(后续 model-gen 用)
- 字段名 (camelCase) / 类型 / 必填 / 中文说明
- 至少 3 个字段
- 时间字段必须标 ISO/timestamp

### Step 8 — 列出异常场景 (强制 ≥3)
- 无网络
- 数据为空
- 接口失败
- 未登录
- 无权限
- 缓存失效
- ...

**Reflector 会检查异常场景 ≥3 条**。

### Step 9 — 列出非功能需求
- 性能 (列表分页 / 详情缓存)
- 深链接 (web URL / Universal Links)
- 国际化
- 可访问性
- 埋点
- 离线支持
- ...

### Step 10 — 写入 docs/specs/{module}.md
按 `_knowledge/artifact-templates/spec.template.md` 7 段格式写入。

### Step 11 — 自检 (跑段 8 checklist)

### Step 12 — 联动建议
建议下一步用 `flutter-plan` 拆任务。

---

## 5. 输出产物

```
docs/specs/{module}.md
```

文件 frontmatter:
```yaml
---
artifact_type: spec
module: announce
version: 1
created: 2026-04-10
created_by: flutter-spec
parent_artifact: null
status: draft
owner: @c
---
```

正文 7 段,详见段 6 模板。

---

## 6. 文档模板

```markdown
---
artifact_type: spec
module: announce
version: 1
created: 2026-04-10
created_by: flutter-spec
parent_artifact: null
status: draft
owner: @c
---

# 公告 - 需求设计

## 1. 目标

公告模块给所有用户展示运营公告。用户可以查看列表、点开详情、标记已读。
解决"用户不知道有新公告"的问题。

**目标用户:** 所有登录用户
**核心场景:** App 启动 → 看到红点提示 → 点入公告列表 → 阅读详情

## 2. 涉及页面

| 页面 ID | 页面名 | 描述 |
|---|---|---|
| announce_list | 公告列表 | 分页查看所有公告,显示已读/未读状态 |
| announce_detail | 公告详情 | 显示单条公告的完整富文本内容 |

## 3. 页面流转

```
启动 App
   │
   ▼
我的 Tab (有红点提示未读数)
   │ tap "公告"
   ▼
公告列表
   │ tap 单条
   ▼
公告详情
   │ 自动标记已读
   │
   ▼ 返回
公告列表 (该条状态变成已读)
```

## 4. 接口需求 (粗粒度)

| 接口名 | 用途 | 方法 |
|---|---|---|
| 公告列表 | 分页查询所有公告 | POST |
| 公告详情 | 按 ID 查单条 | GET |
| 标记已读 | 改变某条已读状态 | POST |

(详细字段交给 flutter-api-design)

## 5. 关键字段

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| id | string | 是 | 公告唯一 ID |
| title | string | 是 | 标题(最长 100 字符) |
| content | string | 否 | 富文本 HTML |
| publishAt | string (ISO 8601) | 是 | 发布时间 |
| isRead | bool | 是 | 当前用户是否已读 |
| author | string | 否 | 发布者 |

## 6. 异常场景

- **无网络** → 显示 "网络异常,点击重试"
- **列表为空** → 显示空状态图 + "暂无公告"
- **加载失败** → toast 提示 + 返回上一页
- **未登录** → 跳转登录页
- **接口超时** → 显示重试按钮
- **数据格式错误** → 上报埋点 + 兜底文案

## 7. 非功能需求

- **性能:** 列表必须分页 (每页 20 条),避免大数据卡顿
- **缓存:** 详情可缓存 5 分钟,避免重复请求
- **深链接:** 支持 `/announce/:id` URL 直接打开详情(web 刷新不崩)
- **国际化:** 支持中英文
- **埋点:** 列表曝光 + 详情点击 + 已读标记 三个事件
- **可访问性:** AppBar / Button 有 semanticLabel
```

---

## 7. 不做什么 (Boundary)

- ❌ 不细化字段类型(交给 flutter-api-design)
- ❌ 不写代码(交给后续 gen skill)
- ❌ 不创建任何 lib/ 文件
- ❌ 不调用其他 skill(只产 artifact)
- ❌ 不修改 docs/_context/(那是 context-update 的事)
- ❌ 不假设技术实现(spec 是"做什么",不是"怎么做")
- ❌ 不写 SQL / 表结构(那是后端的事)
- ❌ 不分配错误码(交给 flutter-api-design)

---

## 8. 自检 Checklist (Quality Gate)

- [ ] 7 段全(目标/页面/流转/接口/字段/异常/非功能)
- [ ] 模块英文名 snake_case 且不与现有冲突
- [ ] 至少列出 1 个页面
- [ ] 流转图存在(可以是 ASCII)
- [ ] 至少列出 1 个接口
- [ ] 至少列出 3 个关键字段
- [ ] **异常场景 ≥ 3 条**(Reflector 强制)
- [ ] 至少 1 条非功能需求
- [ ] frontmatter 完整 (artifact_type / module / created_by / status)
- [ ] 字段命名符合 conventions (camelCase)

---

## 9. 失败处理

**ASK_USER 时机:**
- 用户需求过于模糊(连模块名都说不出)
- 与已有模块功能重叠(是否合并)
- 涉及尚未做的能力(支付 / 推送 / 蓝牙 — 检查 decisions.md)
- 字段类型推断不出(string 还是 int)

**STOP 时机:**
- docs/_context/ 不存在(项目未初始化)
- 模块名与系统保留字冲突 (如 main / app / core)

**ROLLBACK:**
- 写文件失败 → 删除半成品
- 用户中途取消 → 删除 docs/specs/{module}.md(若已创建)

---

## 10. 联动

**成功后建议:**
> "Spec 完成: docs/specs/{module}.md
>   - {N} 个页面
>   - {M} 个接口
>   - {K} 个异常场景
>
> 下一步:
>   - `flutter-plan` 把 spec 拆成实施任务清单
>   - 或直接调 `flutter-flow-feature` 跑全流程"

**失败后建议:**
> "Spec 起草失败,详情见 docs/_failures/{date}.md
> 修正需求描述后重新调用 flutter-spec"

**Workflow 编排关系:**
- **上游:** (用户直接触发)
- **下游:** flutter-plan (拆任务) / flutter-api-design (跳过 plan 直接定接口)
- **平行:** flutter-theme-design (如有新颜色需求)

---

## 给张和锋的备注

这是渡写的第一版样板。你接手后:

### 必须照这个套路写的 6 个 SKILL.md
1. **flutter-page-gen** ★ 最复杂,要支持 4 种页面类型(列表/详情/表单/自定义)
2. **flutter-widget-gen** 公共组件
3. **flutter-design-to-code** ★ Figma + 截图,**第一周必须先跑通 figma MCP**
4. **flutter-review** 7 大类 checklist
5. **flutter-api-doc** 简单 transformer
6. **flutter-theme-design** 简单 designer

### 写的时候必须注意

1. **frontmatter 用单行 description**(不要 yaml `|` 多行,Claude Code 只读第一行)
2. **代码模板段(段 6)** 必须真实可运行
3. **段 8 自检** 必须可机器验证(不要 "代码优雅" 这种主观项)
4. **段 7 boundary** 至少 5 条
5. **段 9 失败处理** ask/stop/rollback 三种情况都写
6. **段 10 联动** 标明上游下游

### 模板速查

抄这个 spec 的结构,改成你自己的:
```
段 1: 触发场景 (3-5 个短语)
段 2: 前置必读 (4 个 _context + 自己的)
段 3: 输入 (必填 / 自动 / 追问)
段 4: 工作流 (Step 1-N)
段 5: 输出产物 (文件路径)
段 6: 模板 (真实代码/markdown)
段 7: 不做什么 (8+ 条)
段 8: 自检 checklist
段 9: 失败处理
段 10: 联动
```

完成后让渡 review 一遍。
