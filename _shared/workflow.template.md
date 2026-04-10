# Workflow SKILL.md 标准 12 段格式（L5/L6 编排层）

> 6 个 flutter-flow-* workflow 必须遵循此格式。
> 与 L4 worker SKILL.md 不同 —— workflow 不生成代码,只编排其他 skill。

---

## Workflow 与 Skill 的根本区别

| | Workflow (L5/L6) | Skill (L4) |
|---|---|---|
| 自己生成代码？ | ❌ 不生成 | ✅ 生成 |
| 调其他 skill？ | ✅ 多个 | ❌ 不调 |
| 维护状态？ | ✅ 状态机 | ❌ 无状态 |
| 模型 | 几乎都用 opus | sonnet/haiku 居多 |
| 篇幅 | 长(状态机+reflector) | 中 |

---

## Frontmatter

```yaml
---
name: flutter-flow-xxx          # 必填
description: |                   # 必填,Claude 据此触发
  用户说"做 XX 模块"或"实现 XX 功能"时触发。
  本 workflow 编排 ... 一系列 skill,自动从设计→代码→评审。
type: workflow                   # 必填,固定值 "workflow"
stage: orchestration             # 必填,固定值
model: opus                      # workflow 推荐 opus(推理强)
priority: P0                     # 必填
version: 1.0.0
owner: @lead
---
```

---

## 正文 12 段

### 段 1: 触发场景
同 skill 模板,但触发短语应该是"高层意图",而非具体动作。

```markdown
## 1. 触发场景
- "做一个 XX 模块" / "实现 XX 功能"
- "新需求: ..."
- "按这份 PRD 实现"
```

---

### 段 2: 前置必读

```markdown
## 2. 前置必读
- `docs/_context/tech-stack.md`
- `docs/_context/conventions.md`
- `docs/_context/decisions.md`
- `docs/_context/glossary.md`
```

---

### 段 3: 输入

通常是用户的原始自然语言意图,可能模糊。

```markdown
## 3. 输入
用户原始消息(自然语言),可能包含:
- 模块描述
- 引用的设计稿(Figma URL/截图)
- 引用的接口文档

示例: "做一个公告模块,有列表和详情,能标记已读"
```

---

### 段 4: 状态机定义

**Workflow 的灵魂。** 用 ASCII 画状态图。

```markdown
## 4. 状态机定义

```
states:
  - IDLE             初始
  - SPEC'ING         调用 flutter-spec 中
  - SPEC_REVIEW      reflector 检查 spec
  - PLANNING         调用 flutter-plan
  - PLAN_REVIEW      reflector 检查 plan
  - DESIGNING        并行调用 api-design + theme-design
  - GENERATING       串行调用 model-gen → api-gen → 并行(page-gen + widget-gen)
  - BUILD_CHECK      bash: flutter analyze + build
  - REVIEWING        调用 flutter-review
  - REVIEW_PASS      通过
  - DONE             完成
  - ABORT            致命错误终止
  - PAUSED           用户暂停

initial: IDLE
final: [DONE, ABORT]
```

---

### 段 5: Transition 规则

```markdown
## 5. Transition 规则

| 当前 | 事件 | 下个 | 条件 |
|---|---|---|---|
| IDLE | user_prompt | SPEC'ING | 输入非空 |
| SPEC'ING | spec_artifact_written | SPEC_REVIEW | 文件存在 |
| SPEC_REVIEW | reflector_pass | PLANNING | reflector 返回 PASS |
| SPEC_REVIEW | reflector_fail | SPEC'ING | retry < 2 |
| SPEC_REVIEW | reflector_fail | ABORT | retry >= 2 |
| PLANNING | plan_written | PLAN_REVIEW | - |
| PLAN_REVIEW | reflector_pass | DESIGNING | - |
| DESIGNING | all_designed | GENERATING | parallel 全部完成 |
| GENERATING | gen_complete | BUILD_CHECK | - |
| BUILD_CHECK | build_pass | REVIEWING | bash exit 0 |
| BUILD_CHECK | build_fail | GENERATING | retry < 1 |
| BUILD_CHECK | build_fail | ASK_USER | retry >= 1 |
| REVIEWING | review_pass | DONE | 0 个 ❌ |
| REVIEWING | review_fail | GENERATING | 有 ❌ 时,回到对应 stage |
| 任何 | user_abort | ABORT | - |
| 任何 | user_pause | PAUSED | - |
| PAUSED | user_resume | (上一个 state) | - |
```

---

### 段 6: Worker 调用映射

每个 state 对应调用的 L4 skill。

```markdown
## 6. Worker 调用映射

| State | 调用方式 | Skills | 备注 |
|---|---|---|---|
| SPEC'ING | sequential | `flutter-spec` | - |
| PLANNING | sequential | `flutter-plan` | - |
| DESIGNING | **parallel** | `flutter-api-design`, `flutter-theme-design` | 用 Agent tool 并发 |
| GENERATING-1 | sequential | `flutter-model-gen` | 必须先于 api-gen |
| GENERATING-2 | sequential | `flutter-api-gen` | 必须在 model-gen 后 |
| GENERATING-3 | **parallel** | `flutter-page-gen`, `flutter-widget-gen` | 可并发 |
| BUILD_CHECK | bash | `flutter analyze && flutter build apk --debug` | 不调 skill |
| REVIEWING | sequential | `flutter-review` | - |
```

---

### 段 7: Reflector 配置

Reflector 是 workflow 的"质量保障层"。每个 skill 完成后,Reflector 检查产物。

```markdown
## 7. Reflector 配置

**调用模型:** sonnet (轻量,只做检查)
**重试上限:** 2 次
**触发时机:** 每个 worker skill 完成后

**State 检查标准:**

| State | Reflector 检查项 | 失败动作 |
|---|---|---|
| SPEC_REVIEW | 1. 7 段是否全 2. 字段命名合规 3. 异常场景 ≥3 4. 接口 ≥1 | retry SPEC'ING |
| PLAN_REVIEW | 1. 任务有依赖图 2. 标注 mock 先行 3. 单任务 ≤ 半天 | retry PLANNING |
| API_REVIEW | 1. 每接口有 mock key 2. 字段类型明确 3. 错误码不冲突 | retry api-design |
| GEN_REVIEW | 1. 文件存在 2. 引用了 ApiClient 3. 三态 UI 完整 4. const 修饰 | retry 对应 gen |
| BUILD_REVIEW | flutter analyze 0 error | retry GENERATING |
| FINAL_REVIEW | 0 个 ❌ | retry 对应 stage |

**Reflector prompt 模板(共享):**
```
你是 Reflector。检查以下 artifact 是否符合标准:
- artifact 路径: {path}
- artifact 类型: {type}
- 检查项:
  {checklist}
返回:
- PASS / RETRY / ABORT / ASK_USER
- 如 RETRY/ABORT,说明原因
```
```

---

### 段 8: Checkpoint 配置

允许 workflow 中断后恢复。

```markdown
## 8. Checkpoint 配置

**位置:** `.flow_checkpoint/{workflow_id}/`

**结构:**
```
.flow_checkpoint/announce-2026-04-10-1430/
├── state.json              当前状态机位置
├── artifacts.json          已生成的 artifact 列表
├── skill_outputs/          每个 skill 的原始输出
│   ├── 01-spec.json
│   ├── 02-plan.json
│   └── ...
├── reflector_decisions.json
└── error.log               (如有失败)
```

**写时机:** 每次 state transition 后立即写
**读时机:** 用户说"继续 XX 模块"时读

**恢复逻辑:**
1. 找最近的 checkpoint
2. 读 state.json
3. 跳过已完成步骤
4. 从中断处继续

**清理:** workflow 完成 24h 后自动删除
```

---

### 段 9: 失败处理

```markdown
## 9. 失败处理

**Retry 策略:**
- skill 调用失败 → 重试 1 次
- reflector 失败 → 重试 1-2 次(看 state)
- bash 命令失败 → 不重试,直接 ask user

**Ask user 时机:**
- retry 达到上限
- 检测到将覆盖大量已有文件
- 上游 artifact 不存在或损坏
- 检测到 git 状态不干净

**Abort 时机:**
- 用户主动取消
- context pack 缺失
- 致命错误(磁盘满、权限拒绝)

**Pause 与 resume:**
- 用户说"暂停" → 写 PAUSED checkpoint
- 用户说"继续" → 从 checkpoint 恢复
```

---

### 段 10: 进度报告

每次 state transition 都要通知用户。

```markdown
## 10. 进度报告

**格式:**
```
[1/8] ✅ SPEC'ING        生成 docs/specs/announce.md (1.2KB)
[2/8] ⏳ PLANNING        正在拆任务...
[3/8] ⏸  DESIGNING       (等待中)
...
```

**详细日志:** 写到 `.flow_log/{workflow_id}.log`

**关键节点必须高亮:**
- ✅ 成功
- ⚠️ 警告但继续
- ❌ 失败
- 🔄 重试中
- ⏸ 等待用户
```

---

### 段 11: 自检 Checklist

```markdown
## 11. 自检 Checklist

**Workflow 设计自检(写完 SKILL.md 后过):**
- [ ] 所有 state 有出口
- [ ] 所有 transition 有条件
- [ ] 至少 1 条路径到 DONE
- [ ] 至少 1 条路径到 ABORT
- [ ] 失败路径全覆盖
- [ ] Reflector 检查项可机器验证
- [ ] Checkpoint 时机覆盖所有 state

**运行时自检(每个 state 完成后):**
- [ ] artifact 已写入
- [ ] reflector 已通过
- [ ] checkpoint 已更新
```

---

### 段 12: 联动

```markdown
## 12. 联动

**成功后建议:**
> "公告模块完成! 建议下一步:
> - 跑 `flutter run --dart-define=USE_MOCK=true` 看效果
> - 或调用 `flutter-flow-review` 做完整评审
> - 或调用 `flutter-flow-release` 准备发版"

**失败时建议:**
> "在 GENERATING 阶段失败,checkpoint 已保存。
> 解决问题后说'继续公告模块'即可恢复。"

**Workflow 编排关系:**
- 上游: (用户直接触发)
- 下游: flutter-flow-review (可选)
```

---

## Workflow 写作 7 条原则

1. **状态机闭合** — 每个 state 都有出口
2. **失败可恢复** — Checkpoint 是 must-have
3. **Reflector 是质量灵魂** — 不要把检查塞进 worker
4. **进度透明** — 用户随时知道在哪一步
5. **并行机会要标** — 能并行的 state 显式标注
6. **不要塞业务逻辑** — workflow 只编排,不生成代码
7. **保持一致** — 6 个 workflow 的状态机风格统一(便于学习)
