---
name: flutter-spec
description: |
  用户描述需求，生成结构化的需求设计文档（7段规范格式）。
  触发场景：用户说"做一个公告功能"、"写一个页面需求"、"拆解这个功能"。
type: skill
stage: 0
model: opus
priority: P1
version: 1.0.0
owner: @lead
category: designer
---

# 需求设计文档 (flutter-spec)

## 1. 触发场景
- "做一个 XX 功能"
- "写一个 XX 页面需求"
- "拆解 XX 需求"
- "用户要求是 XX，怎么做"
- "有个 XX 想法，帮我整理一下"

## 2. 前置必读
- `docs/_context/tech-stack.md`
- `docs/_context/conventions.md`
- `docs/_context/decisions.md`
- `docs/_context/glossary.md`

## 3. 输入

**必填:**
- 用户的自然语言需求描述（可以是一句话，也可以是长段落）

**自动识别:**
- 功能类型: 列表型 / 详情型 / 表单型 / 流程型 / 自定义
- 涉及的数据模型
- 交互复杂度

## 4. 工作流程

**Step 1 — 解析需求**
用户的描述可能是模糊的。Claude 需要通过问题澄清:
- 这是列表还是详情或表单?
- 涉及哪些实体?(事件、用户、数据)
- 需要哪些交互?(下拉刷新、搜索、筛选)
- 是否涉及多页面流程?

**Step 2 — 抽取功能结构**
梳理出:
- 主业务流程：3-5 个主要步骤
- 数据模型：该功能涉及的 entity
- 关键交互：用户核心操作
- 边界情况：异常/空态/错误处理

**Step 3 — 生成 7 段规范文档**

见下方段 6。

**Step 4 — 列出依赖**
输出"需要哪些接口" / "需要哪些数据模型"。

**Step 5 — 建议后续步骤**
告诉用户可以用 `flutter-page-gen` 生成页面。

## 5. 输出产物

生成一份结构化的需求文档，包含 7 段内容。

**输出位置:** spec 文档存放位置由用户决定，通常放在 `docs/specs/{module_name}.md`。

**文件命名:** `{module_name}_spec.md`，例如 `announce_spec.md`。

## 6. 模板示例 — 7 段需求设计文档格式

```markdown
---
artifact_type: spec
created: 2026-04-10
created_by: flutter-spec
---

# 需求设计 · {功能名}

## 1. 功能概述

**一句话:**
用户能通过公告模块查看系统发布的通知，支持按类型筛选和搜索。

**业务价值:**
- 降低消息漏看率
- 实时推送系统更新
- 支持消息存档查询

**目标用户:**
所有 App 用户 (Admin / User)

---

## 2. 用户流程

### 2.1 主流程

```
App 首页
  ↓
进入"公告"Tab / 菜单
  ↓
看到公告列表（时间倒序）
  ↓
上拉加载更多 / 下拉刷新
  ↓
点击公告 → 进入详情页
  ↓
阅读内容 / 分享 / 标记已读
  ↓
返回列表
```

### 2.2 支线流程

- 无网络或加载失败 → 显示重试按钮
- 搜索：用户在列表页点击搜索 → 显示搜索框 → 输入关键词 → 过滤结果
- 筛选：按"类别"或"时间"筛选公告

---

## 3. 数据结构

### 3.1 核心实体

```
Announcement {
  id: string,              // 唯一标识
  title: string,           // 标题
  category: string,        // 分类 (系统/更新/活动)
  content: string,         // 正文
  imageUrl?: string,       // 可选：封面图
  createdAt: timestamp,    // 发布时间
  isRead: bool,            // 是否已读
  priority: int,           // 优先级 (1-5)
}
```

### 3.2 API 接口需求

- `GET /api/v1/announcements` — 分页列表 (支持 skip/limit/category)
- `GET /api/v1/announcements/{id}` — 详情
- `PATCH /api/v1/announcements/{id}/read` — 标记已读
- `GET /api/v1/announcements/categories` — 获取类别列表

---

## 4. 功能清单

### 4.1 列表页面

- [ ] 展示公告列表（卡片形式，时间倒序）
- [ ] 每个卡片显示: 分类标签 + 标题 + 发布时间
- [ ] 支持下拉刷新（刷新列表）
- [ ] 支持上拉加载更多（分页）
- [ ] 空态显示 (无数据时)
- [ ] 加载态显示 (loading skeleton 或 CircleProgressIndicator)
- [ ] 错误态显示 (网络异常时)
- [ ] 支持在列表页搜索 (按标题搜索)
- [ ] 支持按分类筛选
- [ ] 点击卡片进入详情页

### 4.2 详情页面

- [ ] 显示标题 + 分类 + 发布时间 + 作者
- [ ] 展示详情内容 (富文本或 plain text)
- [ ] 如果有封面图，显示在顶部
- [ ] 标记为"已读"
- [ ] 返回按钮或 back gesture

### 4.3 非功能需求

- [ ] 列表页响应时间 < 1s (缓存处理)
- [ ] 支持离线查看（可选：本地 SQLite 缓存已读列表）
- [ ] 国际化支持 (i18n) — 分类名、按钮文案
- [ ] 支持 Android / iOS / Web

---

## 5. 设计约束

- 列表卡片宽度贴满屏幕，两侧 padding 8dp
- 分类标签背景 → 从 `AppColors.categories[category]` 取色
- 字体 → 遵循 `AppTextStyles` (标题 / 副标题 / 正文 / 辅助文字)
- 若无数据，显示"暂无公告"占位图

---

## 6. 技术建议

**推荐架构:**
- View: `announcement_list_page.dart` + `announcement_detail_page.dart`
- Controller: `AnnouncementController` + `AnnouncementDetailController`
- Repository: `AnnouncementRepository`
- Model: `Announcement`

**状态管理:**
使用 GetX 的响应式:
- `announcements` (Rxn<List<Announcement>>)
- `isLoading` (RxBool)
- `hasError` (RxBool)

**关键交互:**
- 列表分页: 保存 `currentPage` 和 `pageSize`
- 搜索/筛选: 分别维护搜索关键词 state 和筛选 state
- 已读状态: 点击详情页时调用标记接口

---

## 7. 下一步

建议使用 `flutter-page-gen` skill 生成:
1. 公告列表页面 GetX 三件套
2. 公告详情页面 GetX 三件套
```

## 7. 不做什么

- ❌ 不生成代码 (只生成需求文档)
- ❌ 不修改已有需求 (只新增)
- ❌ 不做 UX 设计 (只做逻辑设计)
- ❌ 不写接口实现 (只定义接口入参出参)
- ❌ 不做数据库设计 (后端的事)

## 8. 自检 Checklist

- [ ] 功能概述清晰 (一句话说得通)
- [ ] 用户流程是否完整 (正常流 + 支线流)
- [ ] 数据结构定义了所有必要字段
- [ ] API 接口清单完整
- [ ] 功能清单覆盖 UI 需求 + 交互需求
- [ ] 设计约束提到了颜色/字体/spacing
- [ ] 7 段格式完整

## 9. 失败处理

**需求过于模糊时:**
> ASK_USER "需求还有以下问题,需要澄清: ..."

**如果需求超出 UI 范围:**
> "这个需求涉及 {网络层/加密/Model} 部分,超出我的职责范围。请联系 @渡 处理相关部分。"

## 10. 联动

**成功后:**
> "✅ 需求设计文档已生成。
> 建议下一步:
> 1. 确保产品方同意这份设计
> 2. 用 `flutter-page-gen` 生成页面代码"

**下游:**
- flutter-page-gen (页面生成)
- flutter-design-to-code (如果有 Figma 设计稿)
