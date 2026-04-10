---
name: flutter-lint-fix
description: 自动 lint 修复。跑 dart format + dart fix --apply,报告剩余 warning。 hook 自动调用 (Write/Edit 后),也可手动触发。
type: skill
stage: 5
model: haiku
priority: P2
version: 1.0.0
owner: @lead
category: mutator
---

# 自动 Lint 修复 (flutter-lint-fix)

## 1. 触发场景
- "修 lint" / "格式化代码"
- "跑一下 dart format"
- "dart fix"
- hook PostToolUse 自动触发 (写完代码后)
- review workflow 内自动跑

## 2. 前置必读
- `analysis_options.yaml`

## 3. 输入

**可选:**
- `scope` (path) — 修复范围,默认 `lib/` + `test/`
- `dry_run` (bool, default false) — 只报告不修改

## 4. 工作流程

**Step 1 — 检查 git 状态**
- bash: `git status --porcelain`
- 若有未 commit 改动,提示用户先 stash 或继续

**Step 2 — dart format**
- bash: `dart format {scope}`
- 报告: 修改了 N 个文件

**Step 3 — dart fix --apply**
- bash: `dart fix --apply {scope}`
- 报告: 应用了 N 处修复

**Step 4 — flutter analyze**
- bash: `flutter analyze --no-pub`
- 解析输出,统计 error/warning/info

**Step 5 — 输出报告**
- 修复了多少
- 剩余多少
- 剩余的简短列表

## 5. 输出产物

不写新文件,只修改现有 .dart 文件。
报告打印到 stdout (不写到磁盘)。

## 6. 命令模板

```bash
#!/bin/bash
SCOPE="${1:-lib/ test/}"

echo "📐 dart format..."
dart format $SCOPE

echo "🔧 dart fix..."
dart fix --apply $SCOPE

echo "🔍 flutter analyze..."
flutter analyze --no-pub | tail -20
```

## 7. 不做什么

- ❌ 不重构代码 (只做 format + fix)
- ❌ 不删除"未使用"的代码 (只 dart fix 标记的)
- ❌ 不改 import 顺序 (除非 conventions 要求)
- ❌ 不修改测试代码 (除非用户指定)
- ❌ 不 commit
- ❌ 不修改 generated 文件 (.g.dart / .freezed.dart)

## 8. 自检 Checklist

- [ ] dart format 跑过
- [ ] dart fix --apply 跑过
- [ ] flutter analyze 跑过
- [ ] 报告了剩余 warning 数
- [ ] generated 文件未被修改

## 9. 失败处理

**ASK_USER 时机:**
- git 不干净 (是否继续)
- dart fix 改动太多 (>50 文件,是否真要全改)

**STOP 时机:**
- dart 命令找不到
- analysis_options.yaml 损坏

**ROLLBACK:**
- 失败时 `git checkout -- {scope}` 还原

## 10. 联动

**成功后:**
> "Lint 修复完成:
>   - format: {N} 个文件
>   - fix: {M} 处
>   - 剩余 warning: {W}
>   
>   {若有 warning} 用 `flutter-flow-review` 查看详情"

**失败后:**
> "Lint 失败,详情见 stderr"

**上游:** review workflow / hook
**下游:** flutter-flow-review (深度检查)
