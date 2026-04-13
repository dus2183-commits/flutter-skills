---
name: flutter-perf-audit
description: 性能审计 — 自动扫描大 build 方法、重复 rebuild、未 const widget、大列表未用 builder 等性能问题。用户说"性能检查"、"优化扫描"时触发。输出结构化报告。
type: skill
stage: 5
model: sonnet
priority: P2
version: 1.0.0
owner: @lead
category: validator
---

# 性能审计 (flutter-perf-audit)

## 1. 触发场景

- "检查性能问题" / "性能审计"
- "这个页面卡,帮我看看"
- "扫描优化项"
- flutter-review 后想深入看性能

**反例:**
- "代码评审" → flutter-review (更广,含规范/安全等)
- "格式化代码" → flutter-lint-fix

## 2. 前置必读

- `docs/_context/conventions.md` (Widget 拆分阈值: build >80 行 / 嵌套 >5 层 / 文件 >300 行)
- 目标代码文件

## 3. 输入

**必填:**
- `source` — 文件路径 / 目录路径

**可选:**
- `scope` — full (全扫) / quick (只看高危项)

## 4. 工作流程

**Step 1 — 扫描以下 7 类性能问题**

| 类别 | 检查项 | 严重度 |
|------|--------|--------|
| 大 build | `build()` 方法超过 80 行 | 🔴 |
| 深嵌套 | Widget 嵌套超过 5 层 | 🔴 |
| 大文件 | 单文件超过 300 行 | 🟠 |
| 列表性能 | `ListView(children:)` 用于长列表 (应 `.builder`) | 🔴 |
| 未 const | 可以 const 的 Widget 没加 const | 🟠 |
| Obx 范围 | Obx 包了整个 Scaffold (应只包变化部分) | 🟠 |
| build 内创建对象 | `TextStyle(...)` / `EdgeInsets(...)` 每次 rebuild 重建 | 🟡 |

**Step 2 — 逐项标记问题,给出代码位置**

**Step 3 — 生成报告**

**Step 4 — 自检**

## 5. 输出产物

```
docs/reviews/{module}_perf_{date}.md
```

## 6. 代码模板

```markdown
# 性能审计报告 · {module}

## 扫描范围
{文件列表}

## 发现 {N} 个问题

### 🔴 P0 — 必须修

**[1] ListView 未用 .builder**
- 文件: `announce_list_page.dart:45`
- 问题: `ListView(children: list.map(...).toList())`
- 影响: 100+ 条数据全量渲染,滑动卡顿
- 修法: 改 `ListView.builder(itemCount:, itemBuilder:)`

**[2] build() 方法 120 行**
- 文件: `order_detail_page.dart:30`
- 问题: build 方法过长,难维护且影响 rebuild 性能
- 修法: 拆为 `_buildHeader()` / `_buildContent()` / `_buildActions()`

### 🟠 P1 — 应该修

**[3] Obx 包裹整个 Scaffold**
- 文件: `settings_page.dart:15`
- 修法: 只包需要响应的子 Widget

### 统计

| 类别 | 数量 |
|------|------|
| 🔴 P0 | 2 |
| 🟠 P1 | 1 |
| 🟡 P2 | 0 |
| **总计** | **3** |
```

## 7. 不做什么 (Boundary)

- ❌ 不自动修复代码 (只报告)
- ❌ 不检查业务逻辑正确性
- ❌ 不做运行时 profiling (只静态分析)
- ❌ 不检查第三方包性能
- ❌ 不自动 commit

## 8. 自检 Checklist

- [ ] 7 类检查项都扫过了
- [ ] 每个问题有文件名+行号
- [ ] 每个问题有修法建议
- [ ] 报告有统计表

## 9. 失败处理

**ASK_USER:** 文件过多 (>50 文件) 时建议分批
**STOP:** 目标路径不存在

## 10. 联动

**上游:** flutter-review (发现性能问题后深入)
**下游:** flutter-lint-fix (格式修复)
