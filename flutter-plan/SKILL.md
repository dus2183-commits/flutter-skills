---
name: flutter-plan
description: 把 spec 拆成可执行的实施任务清单。读 docs/specs/{module}.md,输出 docs/plans/{module}.md。 按 6 类拆分(api/theme/model/repo/page/widget),标依赖关系,标 mock 先行点。
type: skill
stage: 2
model: opus
priority: P0
version: 1.0.0
owner: @lead
category: designer
---

# 任务拆解 (flutter-plan)

## 1. 触发场景
- "拆任务 XX" / "把这个 spec 拆成实施步骤"
- "做个 plan" / "实施计划"
- spec 完成后,workflow 自动触发

## 2. 前置必读
- `docs/_context/tech-stack.md`
- `docs/_context/conventions.md`
- `docs/specs/{module}.md` (上游 artifact)
- `_knowledge/artifact-templates/plan.template.md` (输出格式)

## 3. 输入

**必填:**
- `spec_path` (string) — spec 文件路径,如 `docs/specs/announce.md`

**自动从 spec 读取:**
- module_name
- 接口列表
- 字段列表
- 页面列表

## 4. 工作流程

**Step 1 — 读取 spec**
读取指定 spec 文件,解析 7 段内容。

**Step 2 — 验证 spec 完整性**
- 检查 7 段是否齐全
- 检查接口数 ≥ 1
- 检查异常场景 ≥ 3
- 不全则 ASK_USER 是否回到 spec 阶段

**Step 3 — 拆解为 6 类任务**
按以下规则拆:

| 类 | 任务来源 | 数量推断 |
|---|---|---|
| A. 接口契约 | spec 第 4 段(接口需求) | 总是 1 个 (api-design 一次设计所有接口) |
| B. 主题/颜色 | spec 中是否提到新颜色/字号 | 0-1 个 |
| C. Model | spec 第 5 段(关键字段) + 接口数 | N 个(每个核心实体 1 个) |
| D. Repository | spec 第 4 段 | 1 个 (一个 module 一个 repo) |
| E. 页面 | spec 第 2 段(涉及页面) | N 个(每个页面一个 page-gen) |
| F. 公共组件 | spec 中提到的复用元素 | 0-N 个 |

**Step 4 — 标注依赖关系**
- A 是所有 C/D 的前置
- C 是 D 的前置
- D 是 E 的前置(但 mock 先行可解锁)
- E 之间通常并行
- F 在 E 之后识别

**Step 5 — 标注 mock 先行点**
- D 任务下注明: "完成后 E 系列可立即开始,无需等真实接口"
- 提示用户 `--dart-define=USE_MOCK=true` 用法

**Step 6 — 估计工作量**
每个任务标 S/M/L:
- S = ≤30 分钟 (单文件)
- M = 30 分钟-1 小时 (多文件 / 复杂逻辑)
- L = > 1 小时 (拆得太大,应再拆)

如有 L,提示用户 spec 太复杂,建议拆模块。

**Step 7 — 写入 plan.md**
按 `_knowledge/artifact-templates/plan.template.md` 格式输出。

**Step 8 — 输出依赖图**
用 ASCII 画 DAG。

**Step 9 — 自检**
跑段 8 checklist。

**Step 10 — 联动建议**
提示用户下一步用 `flutter-api-design`。

## 5. 输出产物

```
docs/plans/{module}.md
```

frontmatter:
```yaml
---
artifact_type: plan
module: announce
version: 1
created: 2026-04-10
created_by: flutter-plan
parent_artifact: docs/specs/announce.md
status: draft
owner: @lead
---
```

## 6. 文档模板

```markdown
# 公告 - 实施计划

## 任务清单

### A. 接口契约设计 (使用 flutter-api-design)
- [ ] **A1**. 设计 3 个接口契约 (S, ~30min)
  - 输出: docs/api/announce.md + mock JSON 草稿

### C. Model 生成 (使用 flutter-model-gen)
- 依赖: A1
- [ ] **C1**. Announce 实体 (S)
- [ ] **C2**. AnnounceListReq / AnnounceListResp DTO (S)

### D. Repository 生成 (使用 flutter-api-gen)
- 依赖: A1, C1, C2
- [ ] **D1**. AnnounceRepository (3 个方法) (M, ~1h)
- [ ] **D2**. Mock JSON 数据 (S)

### E. 页面生成 (使用 flutter-page-gen)
- 依赖: D1 (Mock 模式可立即开始)
- [ ] **E1**. AnnounceListPage 列表型 (M)
- [ ] **E2**. AnnounceDetailPage 详情型 (M)
- [ ] **E3**. 路由注册 (S)

### G. 评审 (使用 flutter-review)
- 依赖: 全部
- [ ] **G1**. 整体评审 (S)

## 依赖图
A1 ──┬─→ C1 ──┐
     ├─→ C2 ──┴─→ D1 ──┬─→ E1 ─┐
                       │   E2  ├─→ G1
                       └─→ E3 ─┘
                  D2 ─┘
```

## 7. 不做什么

- ❌ 不直接生成代码 (那是下游 skill 的事)
- ❌ 不修改 spec.md (只读)
- ❌ 不创建超过 15 个任务的 plan (太多说明 spec 拆得不够)
- ❌ 不自动调用下游 skill (workflow 才能编排)

## 8. 自检 Checklist

- [ ] 6 类全考虑过 (即使某类是 0 个任务)
- [ ] 每个任务有 [ ] checkbox
- [ ] 每个任务有依赖标注
- [ ] 每个任务有工作量 S/M/L
- [ ] 没有 L 任务 (有则警告 spec 太复杂)
- [ ] 标注了 mock 先行点
- [ ] 依赖图是 DAG (无循环)
- [ ] 总任务数 ≤ 15

## 9. 失败处理

**ASK_USER 时机:**
- spec 不完整 (段缺失)
- spec 中字段类型不明确
- 任务粒度无法决定 (S 还是 M)

**STOP 时机:**
- spec 文件不存在
- spec frontmatter 损坏

**ROLLBACK:** 无 (本 skill 不修改其他文件)

## 10. 联动

**成功后:**
> "拆分完成,共 {N} 个任务。
> 建议下一步: `flutter-api-design`(从 A1 开始)
> 或者直接跑 workflow: `flutter-flow-feature` 自动按依赖执行"

**失败后:**
> "spec 不完整,先用 `flutter-spec` 完善"

**上游:** flutter-spec
**下游:** flutter-api-design
