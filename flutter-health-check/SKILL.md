---
name: flutter-health-check
description: Flutter 项目健康体检。检查依赖过期、lint 错误、未使用 import、孤儿 spec、context 过期等。 输出 docs/_health/{date}.md 报告。
type: skill
stage: 0
model: haiku
priority: P2
version: 1.0.0
owner: @lead
category: validator
---

# 项目健康体检 (flutter-health-check)

## 1. 触发场景
- "项目体检" / "健康检查"
- "查看项目状态"
- "检查项目是否健康"
- 周期性 (周一早上自动跑)
- review workflow 内自动触发

## 2. 前置必读
- `docs/_context/tech-stack.md` (拿到依赖版本期望)
- `pubspec.yaml`

## 3. 输入

**可选:**
- `scope` — 检查范围,默认全项目
- `level` — 详细度: brief / normal / detailed,默认 normal

## 4. 工作流程

**Step 1 — 依赖过期检查**
- bash: `flutter pub outdated --json`
- 解析输出
- 列出: 当前版本 → 最新版本 → 升级建议
- 标注: 主版本升级(可能 breaking) / 次版本(安全) / patch(无脑升)

**Step 2 — Lint 错误检查**
- bash: `flutter analyze --no-pub`
- 统计 error / warning / info 数量
- 列出前 10 条最严重的

**Step 3 — 未使用 import 检查**
- bash: `dart fix --dry-run` 或 grep
- 列出未使用的 import

**Step 4 — 未使用资源检查**
- 扫描 `assets/` 目录
- grep 代码中的引用
- 列出未引用的图片/字体/lottie

**Step 5 — Context 过期检查**
- 读 `docs/_context/decisions.md` 最后一条 ADR 日期
- 若超过 60 天没新 ADR,提醒"Context 可能过期"

**Step 6 — 孤儿 spec 检查**
- 列出 `docs/specs/` 下所有 spec
- 对每个 spec,检查 `lib/features/{m}/` 是否存在
- 不存在 → 孤儿 spec(可能是废弃功能)

**Step 7 — Mock 数据检查**
- 列出 `mock/` 下所有 JSON
- 检查是否有对应 model
- 检查 mock 数据格式是否符合 model 字段

**Step 8 — Context 一致性**
- 检查 conventions.md 中的规则是否在代码中违反
- 抽样检查 (3 个文件) 是否符合命名约定

**Step 9 — 测试覆盖率**
- 若有 test 目录,跑 `flutter test --coverage`
- 输出覆盖率(细致级别)

**Step 10 — 输出报告**
写入 `docs/_health/{YYYY-MM-DD}.md`。

## 5. 输出产物

```
docs/_health/{YYYY-MM-DD}.md
```

格式:
```markdown
---
artifact_type: health_check
created: 2026-04-10
created_by: flutter-health-check
---

# 项目健康报告 - 2026-04-10

## 总评
- 状态: 🟢 健康 / 🟡 注意 / 🔴 严重
- 综合分: 85/100

## 1. 依赖 (8/10)
- ⚠️ 3 个包有次版本更新
- ✅ 0 个安全警告

## 2. Lint (10/10)
- ✅ 0 errors / 2 warnings / 5 info

## 3. 未使用资源 (9/10)
- ⚠️ 2 个图片未引用 (assets/image/old/)

## 4. Context (10/10)
- ✅ 最后 ADR: ADR-006 (10 天前)

## 5. 孤儿 spec (10/10)
- ✅ 所有 spec 有对应代码

## 6. Mock 数据 (8/10)
- ⚠️ 1 个 mock 字段类型不匹配 model

## 7. 测试覆盖 (5/10)
- ⚠️ 覆盖率 32% (目标 60%)

## 详细问题
...
```

## 6. 检查项模板

```dart
final checks = [
  HealthCheck('依赖过期', _checkOutdated),
  HealthCheck('Lint 错误', _checkLint),
  HealthCheck('未使用 import', _checkUnusedImports),
  HealthCheck('未使用资源', _checkUnusedAssets),
  HealthCheck('Context 过期', _checkContextStale),
  HealthCheck('孤儿 spec', _checkOrphanSpecs),
  HealthCheck('Mock 数据一致性', _checkMockData),
  HealthCheck('Convention 合规', _checkConventions),
  HealthCheck('测试覆盖率', _checkCoverage),
];

for (final check in checks) {
  final result = await check.run();
  report.add(result);
}
```

## 7. 不做什么

- ❌ 不修改任何文件 (纯只读)
- ❌ 不自动修复 (建议用户跑 lint-fix)
- ❌ 不删除孤儿 spec / 未使用资源 (报告即可)
- ❌ 不调用其他 skill
- ❌ 不发送通知 (telemetry 是另一回事)

## 8. 自检 Checklist

- [ ] 9 项检查全跑
- [ ] 输出 markdown 格式正确
- [ ] 总评有评分
- [ ] 严重问题在前
- [ ] 写到 docs/_health/{date}.md

## 9. 失败处理

**ASK_USER 时机:**
- 没有 docs/_context/ (项目未初始化)
- pubspec.yaml 不存在 (不是 Flutter 项目)

**STOP 时机:**
- bash 命令全部失败 (Flutter SDK 缺失)

**ROLLBACK:** 无 (只读)

## 10. 联动

**成功后:**
> "健康报告: docs/_health/{date}.md
>   总评: {score}/100
>   严重问题: {N}
>   
>   建议:
>   {N} 严重问题: 跑 `flutter-flow-review` 修复
>   依赖过期: `flutter pub upgrade`
>   未使用资源: 手动清理"

**失败后:**
> "体检失败,可能项目结构不完整"

**上游:** (用户触发 / review workflow)
**下游:** flutter-flow-review (修问题) / flutter-lint-fix (自动修)
