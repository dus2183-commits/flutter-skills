---
name: flutter-context-update
description: 维护 docs/_context/ 4 个文件 (tech-stack/conventions/decisions/glossary)。 用户说"加一条决策"、"改技术栈"、"更新规范"时触发。 改动后追加 ADR 到 decisions.md。
type: skill
stage: 0
model: sonnet
priority: P1
version: 1.0.0
owner: @lead
category: mutator
---

# Context 维护 (flutter-context-update)

## 1. 触发场景
- "加一条决策 ..." / "记录一个 ADR"
- "改技术栈" / "升级 GetX"
- "更新命名规范" / "在 conventions 加一条"
- "添加术语 XX 到 glossary"
- "把 XX 决策标为 deprecated"

## 2. 前置必读
- `docs/_context/tech-stack.md`
- `docs/_context/conventions.md`
- `docs/_context/decisions.md`
- `docs/_context/glossary.md`

## 3. 输入

**必填:**
- 自然语言描述要改什么

**自动识别:**
- 改动类型: tech-stack / conventions / decisions / glossary
- 改动操作: add / modify / deprecate / remove

## 4. 工作流程

**Step 1 — 读取现有 4 个 context 文件**
全部 read,建立改动前的 baseline。

**Step 2 — 识别改动类型**
根据用户描述判断改哪个文件:
- 技术栈/版本/包 → tech-stack.md
- 命名/注释/规范 → conventions.md
- 决策/选择 → decisions.md (追加 ADR)
- 术语/词汇 → glossary.md

若多个文件 → 列出来让用户确认。

**Step 3 — 起草 diff**
- 显示给用户改动的 before/after
- 用 unified diff 格式

**Step 4 — 用户确认**
ASK_USER "确认应用此改动?"

**Step 5 — 应用改动**
- 用 Edit 工具修改对应文件
- 不删除已有内容(除非用户明确要求)

**Step 6 — 追加 ADR 到 decisions.md**
**关键步骤**。任何改动都要在 decisions.md 追加一条 ADR,即使是改 conventions 或 glossary。
ADR 格式:
```markdown
## ADR-{N} | {YYYY-MM-DD} | {简短标题}

### 决策
{改了什么}

### 理由
{为什么改}

### 影响范围
{影响哪些代码 / 哪些规范}

### 拍板人
@{lead}

### 状态
active
```

**Step 7 — 检查是否需要更新 CLAUDE.md**
若改动是技术栈级(如换状态管理),提示更新 CLAUDE.md。

**Step 8 — 提示合规检查**
建议跑 `flutter-flow-govern` 触发 health-check 检查现有代码。

## 5. 输出产物

修改 1-2 个文件:
- 主改动文件 (tech-stack/conventions/glossary 之一)
- decisions.md (追加 ADR)

**永远不修改**: spec/plan/api/review 等其他 artifact。

## 6. 模板示例

**示例 1: 升级 GetX 版本**

```markdown
# 改动: tech-stack.md
- GetX 4.6.x
+ GetX 5.0.x

# 追加 ADR:
## ADR-007 | 2026-05-01 | GetX 升级到 5.0
### 决策
GetX 版本升级 4.6.x → 5.0.x
### 理由
1. 5.0 修复了 web 端路由 bug
2. 性能优化 30%
### 影响范围
- 所有 controller 迁移
- 路由 API 部分变化
### 拍板人
@lead
### 状态
active
```

**示例 2: 加一条编码规范**

```markdown
# 改动: conventions.md
追加段落:

## 11. Provider 命名 (新)
- Repository 命名: `{Module}Repository`
- Service 命名: `{Domain}Service`

# 追加 ADR:
## ADR-008 | 2026-05-02 | 明确 Repository / Service 命名
### 决策
Repository 处理数据访问,Service 处理跨模块业务
...
```

## 7. 不做什么

- ❌ 不删除已有 ADR(只能追加 / 改 status)
- ❌ 不修改 specs/plans/api/review 文件
- ❌ 不修改代码 (.dart 文件)
- ❌ 不自动 commit
- ❌ 不创建新的 context 文件 (4 个就够)
- ❌ 不删除 glossary 的术语 (只能加 / 标 deprecated)

## 8. 自检 Checklist

- [ ] 改动只涉及 docs/_context/ 下的 4 个文件
- [ ] decisions.md 必有新 ADR 追加
- [ ] ADR 格式完整 (含日期/决策/理由/拍板人/状态)
- [ ] ADR 编号递增不重复
- [ ] 不破坏现有 ADR 历史
- [ ] dry-run 让用户确认

## 9. 失败处理

**ASK_USER 时机:**
- 改动类型模糊 (不知道改哪个文件)
- 检测到与现有 ADR 冲突 (是否标 superseded)
- 改动可能破坏现有代码大量违规

**STOP 时机:**
- docs/_context/ 不存在 (项目未初始化)
- ADR 编号已达上限 999

**ROLLBACK:**
- 写入失败时 git checkout 还原对应文件

## 10. 联动

**成功后:**
> "Context 已更新:
>   - {file} 已修改
>   - 新 ADR: ADR-{N}
> 
>   建议:
>   - 跑 `flutter-flow-govern` 触发合规检查
>   - 通知 B/C 看新 ADR"

**失败后:**
> "改动未应用,context 文件未修改"

**上游:** (用户直接触发)
**下游:** flutter-flow-govern (合规检查) / flutter-health-check
