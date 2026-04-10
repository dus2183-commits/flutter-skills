---
name: flutter-flow-review
description: 代码评审流水线。用户说"评审一下"、"检查代码"、"PR 评审"时触发。 跑 health-check + review + lint-fix,输出 docs/review/{date}.md。
type: workflow
stage: orchestration
model: opus
priority: P0
version: 1.0.0
owner: @lead
---

# 评审流水线 (flutter-flow-review)

## 1. 触发场景
- "评审一下" / "评审 XX 模块"
- "检查代码" / "代码审查"
- "做一次 code review"
- "PR 评审" / "审下这个 PR"

## 2. 前置必读
- `docs/_context/conventions.md` (评审标准)
- `_governance/checklists/` 全部 5 个

## 3. 输入
- A. 模块名 (评审 lib/features/{module}/)
- B. 文件路径列表 (评审指定文件)
- C. PR 范围 (评审 git diff)
- D. 全项目 (无指定 → 全量评审)

## 4. 状态机定义

```
states:
  - IDLE
  - DETERMINE_SCOPE        确定评审范围
  - HEALTH_CHECK           跑项目健康检查
  - LINT_AUTO_FIX          自动修复可修的 lint
  - REVIEW_CODE            人工 review (LLM)
  - GENERATE_REPORT        生成评审报告
  - DONE
  - ABORT

initial: IDLE
final: [DONE, ABORT]
```

## 5. Transition 规则

| 当前 | 事件 | 下个 | 条件 |
|---|---|---|---|
| IDLE | user_prompt | DETERMINE_SCOPE | - |
| DETERMINE_SCOPE | scope_confirmed | HEALTH_CHECK | - |
| HEALTH_CHECK | health_done | LINT_AUTO_FIX | 健康报告生成 |
| HEALTH_CHECK | critical_issue | ASK_USER | 严重问题 → 是否继续 |
| LINT_AUTO_FIX | autofix_done | REVIEW_CODE | dart fix 跑完 |
| REVIEW_CODE | review_done | GENERATE_REPORT | LLM 评审完成 |
| GENERATE_REPORT | report_written | DONE | docs/review/{date}.md 存在 |
| 任何 | user_abort | ABORT | - |

## 6. Worker 调用映射

| State | 调用方式 | Skill |
|---|---|---|
| HEALTH_CHECK | sequential | `flutter-health-check` |
| LINT_AUTO_FIX | sequential | `flutter-lint-fix` |
| REVIEW_CODE | sequential | `flutter-review` |
| GENERATE_REPORT | (内联,review skill 自己写) | - |

## 7. Reflector 配置

**模型:** sonnet  
**retry 上限:** 0 (评审本身就是 reflect,不嵌套)

| State | 检查项 |
|---|---|
| HEALTH_CHECK 后 | docs/_health/{date}.md 存在 |
| LINT_AUTO_FIX 后 | dart fix --apply exit 0 |
| REVIEW_CODE 后 | docs/review/{date}.md 存在 + 7 大类全检查 |

## 8. Checkpoint 配置

**位置:** `.flow_checkpoint/review-{scope}-{date}/`

**清理:** DONE 后立即删除 (评审报告本身就是 artifact)

## 9. 失败处理

**ASK_USER 时机:**
- 评审范围模糊 (没指定模块也没 git diff)
- health-check 发现严重问题(是否继续 review)
- lint-fix 失败 (是否手动修)

**STOP 时机:**
- 评审范围内代码不存在
- 不在 git 仓库 (无法 diff)

## 10. 进度报告

```
🔍 启动 review workflow

[1/5] ✅ DETERMINE_SCOPE  范围: lib/features/announce/ (12 个 .dart 文件)
[2/5] ✅ HEALTH_CHECK     健康度: 良好 (3 个 warning, 0 个 error)
[3/5] ✅ LINT_AUTO_FIX    自动修复 8 处
[4/5] ⏳ REVIEW_CODE      LLM 评审中...
[5/5] ⏸ GENERATE_REPORT

预计剩余: ~2 分钟
```

## 11. 自检 Checklist

- [x] 评审 7 大类全覆盖
- [x] 自动修复在 LLM 评审之前(减少 LLM 工作)
- [x] 健康检查在最前(早发现严重问题)

## 12. 联动

**成功后:**
> "评审完成! 报告: docs/review/{date}-{module}.md
>   - ❌ 严重: N
>   - ⚠️ 警告: N
>   - ✅ 通过: N/7
>
>   下一步:
>   - 修复严重问题后再次 review
>   - 或用 `flutter-flow-release` 准备发版"

**失败后:**
> "评审中断,详情见 .flow_log/"

**Workflow 编排关系:**
- 上游: feature workflow / 用户直接触发
- 下游: release workflow (评审通过后)
