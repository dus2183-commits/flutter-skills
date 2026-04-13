# Flutter Skills 架构设计

> 8 层 multi-agent 架构。读完这篇你能理解整个系统怎么运转。
> **B 和 C 必读。**

---

## 一、根本视角

### 不要把它当 "skill 集合"

把它当**多 agent 系统** (multi-agent system)。
区别:

| 视角 | skill 集合 | multi-agent system |
|---|---|---|
| 谁决定下一步 | 用户手动 | Orchestrator 自动 |
| 出错怎么办 | 用户处理 | 系统自我修复 |
| 状态在哪 | 对话上下文 | 持久化文件 |
| 能并行吗 | 不能 | 能 |
| 能恢复吗 | 不能 | Checkpoint |

我们做的是后者。

### 6 个根本问题

每个 multi-agent 系统都要回答这 6 个问题:

| # | 问题 | 我们的答案 |
|---|---|---|
| 1 | 谁决定下一步? | L6 Orchestrator |
| 2 | 状态存哪? | L3 Knowledge (context + artifact + memory) |
| 3 | 怎么知道做对? | L7 Quality Gate + L6 Reflector |
| 4 | 错了怎么办? | L6 Recovery + Checkpoint |
| 5 | 怎么协作? | 知识层共享,执行层隔离 |
| 6 | 怎么演进? | L8 Telemetry → 反馈到 L7 治理 |

---

## 二、8 层架构详解

```
╔══════════════════════════════════════════════════════════════╗
║                    Flutter Skills System                      ║
╠══════════════════════════════════════════════════════════════╣
║  L8 Observability     日志 + 统计 + 失败追踪                   ║
║  ──────────────────────────────────────────────────────       ║
║  L7 Governance        规则 + Quality Gate + Hook              ║
║  ──────────────────────────────────────────────────────       ║
║  L6 Orchestration ★   Router + Conductor + Reflector         ║
║  ──────────────────────────────────────────────────────       ║
║  L5 Workflow          6 个 flutter-flow-* (DAG)               ║
║  ──────────────────────────────────────────────────────       ║
║  L4 Skill             18 个 worker (无状态函数)                ║
║  ──────────────────────────────────────────────────────       ║
║  L3 Knowledge         Context + Artifact + Memory             ║
║  ──────────────────────────────────────────────────────       ║
║  L2 Tool              Read/Write/Bash/Figma MCP/Vision        ║
║  ──────────────────────────────────────────────────────       ║
║  L1 Foundation        Claude Opus/Sonnet/Haiku                ║
╚══════════════════════════════════════════════════════════════╝
```

### 各层职责

#### L1 Foundation Model
- **是什么:** Claude Opus/Sonnet/Haiku
- **职责:** 基础推理能力
- **谁实现:** Anthropic
- **谁使用:** 所有上层

#### L2 Tool / MCP
- **是什么:** Read/Write/Edit/Bash/Glob/Grep/Figma MCP/Vision
- **职责:** 真实执行 (改文件、跑命令、调外部 API)
- **谁实现:** Claude Code 内置 + Anthropic MCP
- **谁使用:** L4 skill

#### L3 Knowledge
- **是什么:** 三套知识 (Context + Artifact + Memory)
- **职责:** 提供和持久化知识
- **谁实现:** 文件系统 (`docs/_context/`, `docs/specs/`, etc.)
- **谁使用:** L4/L5/L6 都读

详见 [Knowledge 层](#l3-knowledge-层详解) 章节。

#### L4 Skill (Worker)
- **是什么:** 18 个 worker skill,各自一个 SKILL.md
- **职责:** 完成单点任务 (生成 model / 写 spec / 评审 / ...)
- **特征:** 无状态、原子、不调用其他 skill
- **谁实现:** B/C 主写,A review
- **谁使用:** L5 workflow 调用

#### L5 Workflow
- **是什么:** 6 个 `flutter-flow-*` SKILL.md
- **职责:** 编排多个 worker 完成复杂任务
- **特征:** 有状态机 + DAG + 并行
- **谁实现:** A
- **谁使用:** L6 调用

#### L6 Orchestration ★
- **是什么:** Router + Conductor + Reflector 三角色
- **职责:** 决定执行什么 + 检查质量 + 处理失败
- **谁实现:** A (核心创新点)
- **谁使用:** Claude Code 自动调度

详见 [L6 Orchestration 详解](#l6-orchestration-详解) 章节。

#### L7 Governance
- **是什么:** settings.json + checklists + hooks
- **职责:** 强制规则和质量
- **谁实现:** A
- **谁使用:** Claude Code 自动应用

#### L8 Observability
- **是什么:** Telemetry 脚本 + 日志文件
- **职责:** 记录一切发生的事
- **谁实现:** A
- **谁使用:** 后期分析 / 故障排查

---

## 三、层间通信规则 (铁律)

### 允许 ✅
```
L6 → L5 → L4 → L3 → L2 → L1   (向下调用)
L4 → L3                       (skill 读 context)
L4 → L2                       (skill 用 tool)
任何层 → L8                   (写日志)
L7 → 任何层                   (治理可拦截)
```

### 禁止 ❌
```
L4 → L4    (skill 不能直接调 skill,必须经 L6)
L4 → L6    (skill 不知道有 orchestrator)
跨层跳跃    (L6 不能直接用 L2,要经 L4)
```

### 为什么这个规则重要

skill 之间解耦后,L6 可以自由组合它们。
这是 multi-agent system 可演进的基础。

类比: Unix 哲学 — 小工具组合,而非大单体。

---

## 四、L6 Orchestration 详解

> Orchestration 是整个系统的核心创新。

### 4.1 三个角色

```
┌──────────────────────────────────────────────┐
│              L6 Orchestration                │
│                                              │
│   Router → Conductor → Reflector             │
│                                              │
└──────────────────────────────────────────────┘
```

#### Router (路由器)
- **输入:** 用户原始消息
- **输出:** workflow 名 + 提取参数
- **决策树:**
  ```
  "新建项目"           → init_workflow
  "做 XX 模块"         → feature_workflow
  "Figma 链接"         → design_workflow
  "评审"               → review_workflow
  "改决策"             → govern_workflow
  "发版"               → release_workflow
  ```

#### Conductor (指挥家) ★ 核心
- **输入:** workflow 名 + 参数
- **职责:** 按状态机调用 L4 worker
- **能力:**
  - Decompose (拆解高层意图)
  - Dispatch (调用 L4)
  - Track State (维护状态机)
  - Checkpoint (持久化进度)
  - Recover (失败恢复)

#### Reflector (反思器)
- **输入:** worker 刚生成的 artifact
- **职责:** 评估 artifact 是否合格
- **输出:** PASS / RETRY / ASK_USER / ABORT

详见 [`_design/reflector_design.md`](./_design/reflector_design.md)。

### 4.2 Workflow 状态机示例

以 `flutter-flow-feature` 为例:

```
IDLE
  ↓ user_prompt
SPEC'ING ─→ flutter-spec
  ↓ artifact_written
SPEC_REVIEW ─→ Reflector
  ↓ pass
PLANNING ─→ flutter-plan
  ↓
PLAN_REVIEW
  ↓
DESIGNING ─→ [api-design + theme-design] (并行)
  ↓
API_REVIEW
  ↓
MODEL_GEN ─→ flutter-model-gen
  ↓
API_GEN ─→ flutter-api-gen
  ↓
UI_GEN ─→ [page-gen + widget-gen] (并行)
  ↓
BUILD_CHECK ─→ bash (flutter analyze + build)
  ↓
REVIEWING ─→ flutter-review
  ↓ 0 ❌
DONE ✅
```

任何 state 都可:
- → ABORT (致命错误 / 用户取消)
- → PAUSED (用户暂停)
- 失败时 → 上一个 state retry

详见 `_orchestration/flutter-flow-feature/SKILL.md`。

---

## 五、L4 Skill 详解

### 5.1 6 类 Skill (按职责)

| 类别 | 特征 | 例子 |
|---|---|---|
| **Designer** | 生成结构化设计文档 | spec / plan / api-design / theme-design |
| **Generator** | 生成新代码 | init / model-gen / api-gen / page-gen / widget-gen |
| **Bridge** | 调外部系统 | design-to-code (Figma) |
| **Validator** | 检查不修改 | review / health-check / test-gen |
| **Mutator** | 修改现有文件 | context-update / lint-fix / release |
| **Transformer** | 格式转换 | api-doc / changelog |

### 5.2 Worker 6 个铁律

每个 L4 skill 必须遵守:

1. **Stateless** — 不依赖会话状态,只依赖输入参数
2. **Idempotent** — 同输入跑两次 = 跑一次
3. **Atomic** — 要么全成功,要么不留痕迹
4. **No-Cross-Talk** — 不调用其他 skill,不知道有 orchestrator
5. **Schema-In-Out** — 输入输出有结构化定义
6. **Self-Contained** — SKILL.md 包含所有必要信息

### 5.3 SKILL.md 10 段格式

详见 [`_shared/skill.template.md`](./_shared/skill.template.md):
1. 触发场景
2. 前置必读
3. 输入
4. 工作流程
5. 输出产物
6. 代码模板
7. 不做什么 (boundary)
8. 自检 Checklist
9. 失败处理
10. 联动

---

## 六、L3 Knowledge 层详解

### 6.1 三套知识

```
┌──────────────────────────────────────────────────┐
│              L3 Knowledge                         │
│                                                  │
│  Context (静态)    Artifact (动态)   Memory (持久)│
│  ───────────       ───────────       ───────────  │
│  docs/_context/    docs/specs/       ~/.claude/   │
│  - tech-stack      docs/plans/       memory/      │
│  - conventions     docs/api/         - user.md    │
│  - decisions       docs/review/      - feedback   │
│  - glossary        docs/_health/     - project    │
│                    docs/_failures/                │
│                                                  │
│  生命周期:          生命周期:          生命周期:   │
│  跟随项目           跟随 feature       跨会话      │
│                                                  │
│  写入者:            写入者:            写入者:     │
│  context-update     生成类 skill       所有 skill  │
└──────────────────────────────────────────────────┘
```

### 6.2 Context Pack
- **位置:** `docs/_context/`
- **内容:** tech-stack / conventions / decisions / glossary 4 个 md
- **大小:** ≤ 30KB (避免 token 浪费)
- **生命周期:** 项目级,跟随项目终生
- **谁写:** flutter-init 创建,flutter-context-update 维护
- **谁读:** 所有 SKILL.md 必读

### 6.3 Artifact
- **位置:** `docs/specs/`, `docs/plans/`, `docs/api/`, `docs/review/`
- **内容:** 由 skill 生成的结构化文档
- **特征:** 带 frontmatter,有 lineage (parent_artifact 字段)
- **生命周期:** feature 级,跟随业务模块

### 6.4 Memory
- **位置:** `~/.claude/projects/{p}/memory/`
- **内容:** user / feedback / project / reference 4 类
- **特征:** 个人级,不入 git
- **生命周期:** 跨会话

---

## 七、Quality Gate 系统

### 5 个 Gate

| Gate | 位置 | 检查项 | 失败动作 |
|---|---|---|---|
| **G1** Spec → Plan | spec 完成时 | 7 段全 / 字段命名 / 异常 ≥3 | retry spec |
| **G2** Plan → Design | plan 完成时 | 任务有依赖图 / mock 标注 | retry plan |
| **G3** Design → Code | api-design 完成时 | mock key / 类型 / 错误码 | retry api-design |
| **G4** Code → Review | 代码生成完成时 | flutter analyze + build 通过 | retry gen |
| **G5** Review → Done | review 完成时 | 0 个 ❌ | retry 对应 stage |

### 由谁检查
- **G1/G2/G3:** Reflector (Schema + LLM)
- **G4:** bash (flutter analyze + build)
- **G5:** Reflector (Schema)

### 失败动作
- **Retry:** 回到上一个 state,重新调用 worker (带 reflector 反馈)
- **Ask user:** retry 达到上限,让用户决定
- **Abort:** 致命错误,终止 workflow

---

## 八、失败和恢复

### Checkpoint 机制
位置: `.flow_checkpoint/{workflow_id}/`

```
.flow_checkpoint/feature-announce-2026-04-10-1430/
├── meta.json
├── state.json
├── transitions.jsonl
├── artifacts.json
├── skill_calls/
│   ├── 01-flutter-spec.json
│   └── ...
├── reflector/
└── error.log
```

### 恢复流程
```
用户: "继续公告模块"
→ 找最近 checkpoint (模糊匹配)
→ 读 state.json
→ 跳过已完成步骤
→ 从中断处继续
```

详见 [`_design/checkpoint_design.md`](./_design/checkpoint_design.md)。

---

## 九、L8 Observability

### 5 类 telemetry

| 类 | 内容 | 存哪 |
|---|---|---|
| Skill 调用日志 | 谁调谁 / 何时 / 入参 | `.telemetry/calls.jsonl` |
| Token 用量 | 每次调用消耗 | `.telemetry/tokens.jsonl` |
| Quality Gate 结果 | 通过 / 失败 / 原因 | `.telemetry/gates.jsonl` |
| 失败原因 | error + stack | `docs/_failures/{date}.md` |
| 用户反馈 | 满意度 / 吐槽 | `docs/_feedback/{date}.md` |

通过 hook 自动收集,不污染 skill 代码。

---

## 十、13 条 AI 架构原则

> 这是写每个 SKILL.md 的"宪法"。

| # | 原则 | 含义 |
|---|---|---|
| 1 | **Context First** | 所有 skill 必须先读 context pack |
| 2 | **Artifact In, Artifact Out** | skill 之间靠文件传递,不靠对话 |
| 3 | **Idempotent** | 同输入跑两次结果一致 |
| 4 | **Fail Loud** | 失败立即停,不要兜底 |
| 5 | **No Hidden Magic** | 不在背后做用户没要求的事 |
| 6 | **Determinism over Cleverness** | 模板化优先于"AI 灵感发挥" |
| 7 | **Reuse, Don't Reinvent** | 优先用现有 core/ 库 |
| 8 | **Human in the Loop** | 关键决策让用户拍板 |
| 9 | **Read Before Write** | 修改任何文件前必须先读 |
| 10 | **Quality Gate** | 每个阶段输出要过 checklist |
| 11 | **Minimal Surprise** | skill 行为可预测 |
| 12 | **Trace Everything** | 所有产物有出处 |
| 13 | **Cost Aware** | 大模型只用在该用的地方 |

---

## 十一、模型选择策略

| 模型 | 适用 | 用途 | 哪些 skill |
|---|---|---|---|
| **Opus** | 复杂推理 | 架构 / 评审 / Figma 解析 | spec / plan / review / design-to-code / 所有 workflow |
| **Sonnet** | 一般生成 | 代码生成 / 文档生成 / Reflector | api-design / model-gen / api-gen / page-gen / api-doc / context-update / release |
| **Haiku** | 简单任务 | 格式化 / 简单检查 / changelog | lint-fix / health-check / changelog |

通过 SKILL.md frontmatter `model:` 字段声明。

---

## 十二、扩展性

### 加新 worker skill
1. 在 `_skills/{category}/flutter-{name}/SKILL.md` 写 10 段格式
2. 更新 README skill 清单
3. (可选) 让某个 workflow 的 SKILL.md 引用它

### 加新 workflow
1. 在 `_orchestration/flutter-flow-{name}/SKILL.md` 写 12 段格式
2. 定义状态机
3. 配置 Reflector
4. 测试端到端

### 加新 MCP
1. 在 _design/ 写集成方案
2. 在某个 bridge skill 内调用
3. 更新 settings.json 权限

---

## 十三、读完之后

下一步:
- **B/C** 读 [`_shared/skill.template.md`](./_shared/skill.template.md) 学怎么写 SKILL.md
- **A** 读 [`_design/reflector_design.md`](./_design/reflector_design.md) 设计 Reflector
- **所有人** 读 [`_design/api_client_signature.dart`](./_design/api_client_signature.dart) 理解 ApiClient
- **所有人** 读 [`docs/team.md`](./docs/team.md) 看自己负责什么 (待写)
