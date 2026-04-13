---
name: flutter-flow-govern
description: 治理流水线。用户说"改技术栈"、"新决策"、"更新规范"时触发。 调用 context-update 修改 docs/_context/,然后 health-check 验证现有代码合规。
type: workflow
stage: orchestration
model: opus
priority: P1
version: 1.0.0
owner: @lead
---

# 治理流水线 (flutter-flow-govern)

## 1. 触发场景
- "改技术栈" / "升级 XX 包"
- "新决策: ..."
- "更新命名规范"
- "在 conventions 加一条 ..."
- "记录一个 ADR"

## 2. 前置必读
- `docs/_context/` 全部 4 个文件

## 3. 输入
用户描述要改什么(自然语言)。

## 4. 状态机定义

```
states:
  - IDLE
  - IDENTIFY_CHANGE       识别改动类型 (tech-stack/conventions/decisions/glossary)
  - DRAFT_DIFF            起草 diff
  - USER_CONFIRM          用户确认
  - APPLY                 应用到对应 context 文件
  - APPEND_ADR            追加 ADR 到 decisions.md
  - COMPLIANCE_CHECK      检查现有代码是否还合规
  - DONE
  - ABORT

initial: IDLE
final: [DONE, ABORT]
```

## 5. Transition 规则

| 当前 | 事件 | 下个 | 条件 |
|---|---|---|---|
| IDLE | user_prompt | IDENTIFY_CHANGE | - |
| IDENTIFY_CHANGE | change_identified | DRAFT_DIFF | - |
| IDENTIFY_CHANGE | ambiguous | ASK_USER | 不知道改哪个文件 |
| DRAFT_DIFF | diff_ready | USER_CONFIRM | - |
| USER_CONFIRM | confirmed | APPLY | - |
| USER_CONFIRM | rejected | DRAFT_DIFF | 重新起草 |
| APPLY | applied | APPEND_ADR | 改动已写入 |
| APPEND_ADR | adr_written | COMPLIANCE_CHECK | - |
| COMPLIANCE_CHECK | all_compliant | DONE | 现有代码符合新规 |
| COMPLIANCE_CHECK | violations_found | MIGRATE | 需要批量迁移代码 |
| MIGRATE | migrate_done | DONE | 迁移完成 |
| COMPLIANCE_CHECK | violations_found (minor) | ASK_USER | 小问题,是否手动修 |
| 任何 | user_abort | ABORT | - |

## 6. Worker 调用映射

| State | 调用方式 | Skill |
|---|---|---|
| IDENTIFY_CHANGE | inline | (LLM 识别) |
| DRAFT_DIFF | sequential | `flutter-context-update` |
| APPLY | sequential | `flutter-context-update` (写入) |
| APPEND_ADR | sequential | `flutter-context-update` (追加 ADR) |
| COMPLIANCE_CHECK | sequential | `flutter-health-check` |
| MIGRATE | sequential | `flutter-migrate` (批量重命名/路径修改,仅 violations_found 时调用) |

## 7. Reflector 配置

**模型:** sonnet

| State | 检查项 |
|---|---|
| APPLY 后 | 改动符合用户意图 / 没破坏现有 ADR 历史 |
| APPEND_ADR 后 | ADR 格式完整(日期/决策/理由/拍板人) |
| COMPLIANCE_CHECK 后 | 健康报告生成 |

## 8. Checkpoint 配置

**位置:** `.flow_checkpoint/govern-{date}/`
**清理:** DONE 后 7 天 (治理记录有审计价值)

## 9. 失败处理

**ASK_USER 时机:**
- 改动类型模糊
- 检测到将破坏现有代码大量违规
- ADR 与已有 ADR 冲突

**STOP 时机:**
- docs/_context/ 不存在(未初始化)

## 10. 进度报告

```
📋 启动 govern workflow

[1/7] ✅ IDENTIFY_CHANGE  类型: tech-stack 升级 (GetX 4.6 → 5.0)
[2/7] ✅ DRAFT_DIFF       diff 已起草
[3/7] ✅ USER_CONFIRM     用户确认
[4/7] ✅ APPLY            tech-stack.md 已更新
[5/7] ✅ APPEND_ADR       ADR-007 已追加
[6/7] ⏳ COMPLIANCE_CHECK 检查现有代码...
       ⚠️ 发现 3 处需要适配 GetX 5.0 的写法
[7/7] ⏸ DONE

是否触发 review workflow 自动修复?
```

## 11. 自检 Checklist

- [x] ADR 追加式,不删历史
- [x] 改动前 dry-run
- [x] 合规检查在最后(否则改动后可能假阳性)

## 12. 联动

**成功后:**
> "治理完成。
>   - 已更新: {file}
>   - 新 ADR: {ADR-N}
>   - 合规检查: {result}
>   
>   建议:
>   - 通知 B/C 看新 ADR
>   - 若有违规,跑 `flutter-flow-review` 修复"

**失败后:**
> "治理中断在 {state}"

**Workflow 编排关系:**
- 上游: (用户直接触发)
- 下游: `flutter-flow-review` (若有违规)
