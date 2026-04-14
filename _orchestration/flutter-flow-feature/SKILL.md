---
name: flutter-flow-feature
description: Flutter 功能开发主流水线。用户说"做一个 XX 模块"、"实现 XX 功能"、"新需求 XX"时触发。编排 spec→plan→api-design→model-gen→api-gen→page-gen→i18n→test→review 全流程,完整产出可运行的 Flutter 模块代码。
type: workflow
stage: orchestration
model: opus
priority: P0
version: 1.0.0
owner: @lead
---

# 功能开发流水线 (flutter-flow-feature)

> 这是 flutter-skills 系统的**主入口和核心**。80% 的使用场景走这条流水线。

## ⛔ 铁律（违反任何一条立即停止）

1. **禁止跳步骤直接写代码。** 有依赖关系的步骤必须按顺序：spec → plan → api-design → model-gen → api-gen → page-gen。不能跳过 spec 直接写 model，不能跳过 api-design 直接写 repository。
2. **无依赖的步骤可以并行。** 用 Agent tool 并发加速：
   - **多模块并行**: Agent A 做 auth, Agent B 做 post, 同时跑
   - **模块内也可并行**: api-design + theme-design 同时跑，page-gen + widget-gen 同时跑（见段 6 Worker 调用映射的 parallel 标记）
   - **但有依赖的必须串行**: model-gen 必须等 api-design 完成，api-gen 必须等 model-gen 完成
3. **每一步必须读对应的 SKILL.md。** 生成代码前，先读 `.claude/skills/flutter-{skill}/SKILL.md` 里的段 6 代码模板，按模板写，不要凭自己的知识。
4. **每一步必须产出文件。** spec → `docs/specs/{m}.md`，plan → `docs/plans/{m}.md`，api-design → `docs/api/{m}.md`，model-gen → `.model.dart`，api-gen → `_repository.dart` + mock JSON，page-gen → 三件套。没有文件产出 = 没做。
5. **禁止把有依赖的 skill 合并成一步。** 不能"同时生成 model + repository"（repo 依赖 model），但可以"同时生成 page + widget"（无依赖）。

## 🤖 子 Agent 启动模板（必须用这个）

**用 Agent tool 并行做多个模块时，每个子 Agent 的 prompt 必须包含以下完整内容，否则子 Agent 会跳步：**

```
你是 flutter-flow-feature 的子 Agent，负责做 {module} 模块。

⛔ 铁律（必须遵守，违反立即停止）：
1. 必须按顺序执行,禁止跳步（9 步全做,一步不少）:
   spec → plan → api-design → model-gen → api-gen → page-gen → polishing → test-gen → review
2. 每步必须产出文件,没文件 = 没做:
   [1] spec: docs/specs/{module}.md
   [2] plan: docs/plans/{module}.md
   [3] api-design: docs/api/{module}.md
   [4] model-gen: lib/features/{module}/data/models/*.model.dart
       ⛔ 文件名必须是 `{entity}.model.dart` (带 .model 中缀),不是 `{entity}.dart` 或 `{entity}_model.dart`
       ⛔ part 声明必须是 `part '{entity}.model.freezed.dart';` + `part '{entity}.model.g.dart';`
       ⛔ 否则 auto-build-runner hook 不触发,build_runner 不会自动跑,用户会看到 freezed 编译错误
   [5] api-gen: lib/features/{module}/data/repositories/*_repository.dart + mock/{module}/*.json
   [6] page-gen: lib/features/{module}/presentation/pages/{page_name}/ (三件套)
   [7] polishing (并行,4 个都要做):
       - i18n-gen: 提取硬编码中文 → lib/app/locales/zh_cn/{module}.dart + 替换代码
       - error-code-gen: 错误码 enum → lib/features/{module}/data/error_codes/*.dart
       - mock-gen: 补充丰富 mock 数据 (列表 ≥3 条,字段值不重复)
       - skeleton-gen: 列表页/详情页的骨架屏 → lib/features/{module}/presentation/widgets/*_skeleton.dart
   [8] test-gen: test/features/{module}/*_test.dart
   [9] review: docs/review/{date}-{module}.md (review + perf-audit 合并)
3. 每步必须读对应 .claude/skills/flutter-{skill}/SKILL.md 段 6 代码模板,按模板写
4. 启动前必读:
   - docs/_context/tech-stack.md
   - docs/_context/conventions.md
   - docs/_context/decisions.md
   - _design/api_client_signature.dart
   - _design/app_exception.dart

## 模块信息
- 模块名: {module}
- 接口清单: {endpoints}
- 页面清单: {pages}

## 全局配置
- baseUrl: {baseUrl}
- 响应格式: {response_format}
- 分页字段: {page_fields}
- 字段命名: {naming_style}

## Swagger
{swagger_json}

现在开始,先从 spec 开始,按顺序走完 7 步。每步完成后用 "✅ Step N: {skill} → {产出文件}" 格式汇报,再进下一步。
```

**Workflow 主 Agent 的职责（必须做完所有步骤）:**
1. 解析用户需求,拆分成 N 个模块
2. 并行启动 N 个子 Agent,每个子 Agent 按上面模板给 prompt
3. 等所有子 Agent 完成后 — **必须做以下收尾工作,禁止跳过**:
   - 调 flutter-review → 产出 `docs/review/{date}.md`（读 `_knowledge/artifact-templates/review.template.md` 模板）
   - 调 flutter-perf-audit → 产出 `docs/review/{date}-perf.md`
   - 跑 `fvm flutter analyze` 验证 0 error
   - 输出汇总报告给用户

**收尾检查清单（main Agent 必须逐项确认）:**
- [ ] 每个模块都有 docs/specs/{m}.md
- [ ] 每个模块都有 docs/plans/{m}.md
- [ ] 每个模块都有 docs/api/{m}.md
- [ ] 每个模块都有 lib/features/{m}/data/models/
- [ ] 每个模块都有 lib/features/{m}/data/repositories/
- [ ] 每个模块都有 lib/features/{m}/presentation/pages/
- [ ] 每个模块都有 mock/{m}/
- [ ] 每个模块都有 test/features/{m}/
- [ ] 有 docs/review/{date}.md
- [ ] `fvm flutter analyze` 0 error

**缺任何一项 = 流水线未完成,必须补齐。**

---

## 1. 触发场景

- "做一个 XX 模块" / "实现 XX 功能"
- "新需求: XX" / "做一个 XX 页面 + 接口"
- "按这份 PRD 实现"
- "做公告/消息/订单/...模块"
- 用户给一段需求描述,要求生成代码

**反例(不应触发):**
- "Figma 链接 ..." → 应触发 `flutter-flow-design`
- "评审一下 ..." → 应触发 `flutter-flow-review`
- "新建项目" → 应触发 `flutter-flow-init`

---

## 2. 前置必读

- `docs/_context/tech-stack.md`
- `docs/_context/conventions.md`
- `docs/_context/decisions.md`
- `docs/_context/glossary.md`
- `_design/api_client_signature.dart` (理解 ApiClient 接口)
- `_design/app_exception.dart` (理解异常体系)

---

## 3. 输入

### 模式 A — 自然语言(单模块,快速)

**用户原始消息**,可能包含:
- 功能描述(必须)
- 模块英文名建议(可选,Conductor 可推断)
- 引用的设计稿(可选,有则改走 design workflow)
- 引用的接口文档(可选)

**示例输入:**
> "做一个公告模块,有列表和详情,能标记已读。列表分页,详情有富文本。"

### 模式 B — Manifest 批量(多模块,推荐)

**触发:** 用户消息含 `manifest:docs/manifests/manifest-v{N}.yaml` 或 `/flutter-flow-feature manifest:...`

**执行流程:**
1. **校验前置:** `docs/_context/api-global.yaml` 存在(manifest 会继承它)
2. **读 manifest YAML,校验 schema:**
   - 顶层必须有 `version` / `modules`
   - 每模块必须有 `name`(snake_case) / `routes` / `pages`
   - `endpoints[*].req_json`/`resp_json` 必须是合法 JSON(`json.loads(yaml_block)` 能过)
   - `routes[*].type` 必须 ∈ `standalone / tab / sub / modal / dialog / bottom_sheet`
   - `manual_assets[*].purpose` 必须 ∈ `icon / bg / btn / img / avatar / logo`
   - 违反 → 报错,告诉用户哪行哪个字段,不继续
3. **生成代码快照(回退用):**
   ```bash
   mkdir -p .flow_checkpoint/gen-v{N}/
   # 计算本次会触及的文件路径列表 touched_files.txt
   # 对每个存在的文件:tar 打包到 snapshot.tar.gz
   # 对每个 NEW 文件:在 touched_files.txt 标 [NEW]
   cp docs/manifests/manifest-v{N}.yaml .flow_checkpoint/gen-v{N}/
   echo '{"modules":[...]}' > .flow_checkpoint/gen-v{N}/modules.json
   ```
4. **Fan-out 并行子 Agent:**
   - 每模块一个 Agent,用段 "🤖 子 Agent 启动模板"
   - 把 manifest 里该模块的字段**直接塞进** prompt 的 `## 模块信息` 段:
     - `endpoints` → 填 `{swagger_json}` 位置(整块 JSON)
     - `routes` → 指示 page-gen 把路由登记到 `lib/app/routes/app_pages.dart` 的哪个位置
     - `manual_assets` → 子 Agent 先调 `flutter-asset-import` 导入,再继续 page-gen
5. **收尾:** review / perf-audit / flutter analyze 同现有流程
6. **写回 manifest:** 把 `generated_code_version` 字段锁死为 `v{N}`,防止二次运行

**Manifest 模式优势:**
- 批量清单一次性填,不用每模块来回对话
- 接口 JSON 直接从 Postman 贴,免二次描述
- 生成前快照,一键回退
- 多模块真并行(N Agent 同时跑,比自然语言串行快 N 倍)

### 模式判断规则

| 用户消息 | 模式 | 说明 |
|---|---|---|
| 含 `manifest:xxx.yaml` | B | 读 manifest |
| 含 "做 X 模块/功能" 但无 manifest | A | 自然语言,单模块 |
| 含 "做 X 和 Y 两个模块" 无 manifest | **先反问** | 建议用户改用 manifest 模式(`/flutter-manifest-init`),多模块用 manifest 更稳 |

**Conductor 解析后的结构化输入:**
```json
{
  "module_name": "announce",
  "module_chinese": "公告",
  "pages": ["list", "detail"],
  "actions": ["mark_read"],
  "features": {
    "pagination": true,
    "rich_text": true
  }
}
```

---

## 4. 状态机定义

```
                    ┌─────────┐
                    │  IDLE   │
                    └────┬────┘
                         │ user_prompt
                         ▼
                    ┌─────────┐
              ┌────►│ SPEC'ING│
              │     └────┬────┘
              │          │ spec_written
              │          ▼
              │     ┌──────────┐
              │     │SPEC_REVIEW│
              │     └──┬─────┬─┘
              │ retry  │     │ pass
              └────────┘     ▼
                        ┌─────────┐
                  ┌────►│PLANNING │
                  │     └────┬────┘
                  │          │ plan_written
                  │          ▼
                  │     ┌──────────┐
                  │     │PLAN_REVIEW│
                  │     └──┬─────┬─┘
                  │ retry  │     │ pass
                  └────────┘     ▼
                            ┌──────────┐
                            │DESIGNING │  ← 并行: api-design + theme-design
                            └────┬─────┘
                                 │ all_designed
                                 ▼
                            ┌──────────┐
                            │API_REVIEW│
                            └────┬─────┘
                                 │ pass
                                 ▼
                            ┌──────────┐
                            │MODEL_GEN │  ← 串行: model-gen
                            └────┬─────┘
                                 │ models_written
                                 ▼
                            ┌──────────┐
                            │ API_GEN  │  ← 串行: api-gen
                            └────┬─────┘
                                 │ repos_written
                                 ▼
                            ┌──────────┐
                            │  UI_GEN  │  ← 并行: page-gen + widget-gen
                            └────┬─────┘
                                 │ ui_written
                                 ▼
                            ┌──────────┐
                            │ POLISHING│  ← 并行: i18n-gen + error-code-gen + mock-gen + skeleton-gen
                            └────┬─────┘
                                 │ polished
                                 ▼
                            ┌──────────┐
                            │BUILD_CHECK│  ← bash: flutter analyze + build
                            └─┬────────┘
                              │
                       ┌──────┴──────┐
                       │ pass        │ fail
                       ▼             ▼
                  ┌─────────┐  ┌──────────┐
                  │ TEST_GEN│  │  ASK_USER │
                  └────┬────┘  └──────────┘
                       │ tests_written
                       ▼
                  ┌─────────┐
                  │REVIEWING│  ← review + perf-audit
                  └────┬────┘
                       │ pass
                       ▼
                  ┌─────────┐
                  │   DONE  │
                  └─────────┘

ANY → ABORT (致命错误 / 用户取消)
ANY → PAUSED (用户主动暂停)
PAUSED → (上一个 state) (用户继续)
```

**states:**
- `IDLE` - 初始
- `SPEC'ING` - 调用 flutter-spec
- `SPEC_REVIEW` - Reflector 检查 spec
- `PLANNING` - 调用 flutter-plan
- `PLAN_REVIEW` - Reflector 检查 plan
- `DESIGNING` - 并行调用 api-design + theme-design
- `API_REVIEW` - Reflector 检查 api 契约
- `MODEL_GEN` - 调用 model-gen
- `API_GEN` - 调用 api-gen
- `UI_GEN` - 并行调用 page-gen + widget-gen
- `POLISHING` - **新增** 并行调用 i18n-gen + error-code-gen + mock-gen + skeleton-gen
- `BUILD_CHECK` - bash 编译检查
- `TEST_GEN` - **新增** 调用 test-gen 生成单元测试
- `REVIEWING` - 调用 review + perf-audit
- `DONE` - 完成
- `ABORT` - 终止
- `PAUSED` - 暂停

**initial:** `IDLE`
**final:** `[DONE, ABORT]`

---

## 5. Transition 规则

| 当前 State | 触发事件 | 下个 State | 条件 |
|---|---|---|---|
| IDLE | user_prompt | SPEC'ING | 输入非空 |
| SPEC'ING | spec_artifact_written | SPEC_REVIEW | docs/specs/{m}.md 存在 |
| SPEC_REVIEW | reflector_pass | PLANNING | - |
| SPEC_REVIEW | reflector_retry | SPEC'ING | retry < 2 |
| SPEC_REVIEW | reflector_fail | ASK_USER | retry >= 2 |
| PLANNING | plan_artifact_written | PLAN_REVIEW | docs/plans/{m}.md 存在 |
| PLAN_REVIEW | reflector_pass | DESIGNING | - |
| PLAN_REVIEW | reflector_retry | PLANNING | retry < 2 |
| DESIGNING | all_parallel_done | API_REVIEW | api-design + theme-design 全完成 |
| API_REVIEW | reflector_pass | MODEL_GEN | - |
| API_REVIEW | reflector_retry | DESIGNING | retry < 1 |
| MODEL_GEN | models_written | API_GEN | 所有 .model.dart 存在 |
| API_GEN | repos_written | UI_GEN | repository 文件存在 |
| UI_GEN | all_parallel_done | POLISHING | page + widget 全完成 |
| POLISHING | all_parallel_done | BUILD_CHECK | i18n + error-code + mock + skeleton 全完成 |
| BUILD_CHECK | analyze_pass | TEST_GEN | flutter analyze exit 0 |
| BUILD_CHECK | analyze_fail | POLISHING | retry < 1 (可能是 i18n 替换引入的问题) |
| BUILD_CHECK | analyze_fail | ASK_USER | retry >= 1 |
| TEST_GEN | tests_written | REVIEWING | 测试文件已生成 |
| REVIEWING | review_pass | DONE | 0 个 ❌ |
| REVIEWING | review_fail | (对应 stage) | 有 ❌ 时回到对应阶段 |
| 任何 | user_abort | ABORT | - |
| 任何 | user_pause | PAUSED | - |
| PAUSED | user_resume | (上一个 state) | - |
| 任何 | fatal_error | ABORT | - |

---

## 6. Worker 调用映射

| State | 调用方式 | Skills | 备注 |
|---|---|---|---|
| SPEC'ING | sequential | `flutter-spec` | 输出 docs/specs/{m}.md |
| PLANNING | sequential | `flutter-plan` | 读 spec,输出 docs/plans/{m}.md |
| DESIGNING | **parallel** | `flutter-api-design` + `flutter-theme-design` | 用 2 个 Agent 并发 |
| MODEL_GEN | sequential | `flutter-model-gen` | 读 docs/api/{m}.md |
| API_GEN | sequential | `flutter-api-gen` | 必须在 model-gen 之后 |
| UI_GEN | **parallel** | `flutter-page-gen` + `flutter-widget-gen` | 2 个 Agent 并发 |
| POLISHING | **parallel** | `flutter-i18n-gen` + `flutter-error-code-gen` + `flutter-mock-gen` + `flutter-skeleton-gen` | 4 个 Agent 并发,提取中文+生成错误码+补 mock+骨架屏 |
| BUILD_CHECK | bash | `bash scripts/build_check.sh fast` | analyze+web,~20s |
| TEST_GEN | sequential | `flutter-test-gen` | 给 Repository 生成单元测试 |
| REVIEWING | **parallel** | `flutter-review` + `flutter-perf-audit` | 代码评审 + 性能审计 |

**并行实现:** 用 Agent tool 同时启动多个 sub-agent,每个 sub-agent 调用一个 worker skill,等所有完成后 join。

---

## 7. Reflector 配置

**全局设置:**
- 模型: sonnet (检查不需要 opus)
- retry 上限: 见各 state
- 触发时机: 每个 worker 完成后 + 每个 transition 之前

**State 检查标准表:**

| State | 策略 | 检查项 | retry 上限 |
|---|---|---|---|
| SPEC_REVIEW | Schema + LLM | (1) 7 段全 (2) 字段命名合规 (3) 异常 ≥3 (4) 接口 ≥1 (5) 模块名 snake_case | 2 |
| PLAN_REVIEW | Schema | (1) 任务有依赖图 (2) 标 mock 先行 (3) 单任务粒度 ≤ 半天 | 2 |
| API_REVIEW | Schema | (1) 每接口有 mock key (2) 字段类型明确 (3) 错误码不冲突 (4) 路径符合规范 | 1 |
| MODEL_GEN 后 | Rule + bash | (1) dart analyze 0 error (2) freezed 模板正确 (3) 嵌套对象拆文件 (4) DateTime 用 ISO8601 | 1 |
| API_GEN 后 | Rule | (1) 调用 ApiClient 不直接 new Dio (2) 必传 mockKey (3) catch AppException (4) cancelToken 透传 | 1 |
| UI_GEN 后 | Rule | (1) 三件套全 (page+controller+binding) (2) 用 GetView 不用 StatelessWidget (3) loading/error/empty 三态 (4) const 修饰 | 1 |
| POLISHING 后 | Rule | (1) i18n: 无硬编码中文残留 (2) error-code: 常量文件存在 (3) mock: JSON 文件 ≥3 条 (4) skeleton: 骨架文件存在(如需) | 0 |
| BUILD_CHECK | bash | `bash scripts/build_check.sh fast` 退出码 0 (analyze + web,~20s) | 1 |
| TEST_GEN 后 | bash | `flutter test test/features/{m}/` exit 0 | 1 |
| REVIEWING | Schema | review.md 7 段全 + 0 个 ❌ + perf-audit 报告 0 个 🔴 | 不重试 |

**Reflector prompt 模板(共享 LLM 检查时用):**

```
你是 Reflector,负责检查 {artifact_type}。

[artifact 路径] {path}
[artifact 内容]
{content}

[检查项]
{checklist_items}

请逐项检查,严格按 checklist,不要主观发挥。

返回 JSON:
{
  "result": "PASS" | "RETRY" | "ASK_USER" | "ABORT",
  "passed": [list],
  "failed": [list with reason],
  "suggestions": [具体修改建议]
}

注意:
- RETRY 必须给具体修改建议
- ASK_USER 必须给具体问题
- 不要客气,有问题就报
- 失败建议必须可执行,不要"代码不优雅"这种主观项
```

---

## 8. Checkpoint 配置

**位置:** `.flow_checkpoint/feature-{module}-{YYYY-MM-DD}-{HHMM}/`

**结构(详见 _design/checkpoint_design.md):**
```
.flow_checkpoint/feature-announce-2026-04-10-1430/
├── meta.json                       元信息
├── state.json                      当前 state
├── transitions.jsonl               所有 transition (append-only)
├── artifacts.json                  已生成 artifact 列表
├── skill_calls/
│   ├── 01-flutter-spec.json
│   ├── 02-flutter-plan.json
│   └── ...
├── reflector/
│   ├── 01-spec_review.json
│   └── ...
└── error.log                       (如有失败)
```

**写时机:**
- workflow 启动: meta.json + initial state.json
- transition 后: 更新 state.json + 追加 transitions.jsonl
- skill 完成: skill_calls/{N}-{name}.json
- reflector 完成: reflector/{N}-{state}.json
- artifact 写入: 更新 artifacts.json
- 失败: error.log

**读时机:**
- 用户说"继续 XX 模块"
- 用户说"恢复 workflow"

**清理:** DONE 后 24h / ABORT 后 7 天

---

## 9. 失败处理

### Retry 策略

| 失败类型 | retry 次数 | 失败后行为 |
|---|---|---|
| spec 缺段 | 2 | ASK_USER |
| plan 任务粒度过大 | 2 | ASK_USER |
| api-design 字段类型不明 | 1 | ASK_USER |
| model-gen dart analyze 失败 | 1 | ASK_USER |
| api-gen 没用 ApiClient | 1 | ASK_USER (写错代码) |
| build_check flutter analyze 失败 | 1 | ASK_USER |
| build_check flutter build 失败 | 0 | 直接 ASK_USER (常是依赖问题) |

### Ask user 时机

- retry 达到上限
- 检测到将覆盖大量已有文件 (>5 个 .dart)
- 上游 artifact 不存在或损坏
- git 状态不干净 (有未 commit 的 .dart 改动)
- 检测到模块名冲突 (lib/features/{m}/ 已存在)

### Abort 时机

- 用户主动取消 (说"取消"/"停止")
- context pack 缺失 (docs/_context/ 4 个文件不全)
- 致命错误 (磁盘满 / 权限拒绝 / git 仓库损坏)

### Pause 与 Resume

- 用户说"暂停" → 写 PAUSED checkpoint,通知用户已暂停
- 用户说"继续" → 读 checkpoint,从 PAUSED 状态恢复
- 跨会话 resume: 用户说"继续 XX 模块" → 模糊匹配 checkpoint

---

## 10. 进度报告

**实时格式(每个 state transition 通知用户):**

```
🚀 启动 feature workflow: 公告模块
   workflow_id: feature-announce-2026-04-10-1430

[1/12] ✅ SPEC'ING        生成 docs/specs/announce.md (1.2KB) [12s]
[2/12] ✅ SPEC_REVIEW     Reflector PASS [3s]
[3/12] ✅ PLANNING        生成 docs/plans/announce.md (2.1KB) [18s]
[4/12] ✅ PLAN_REVIEW     Reflector PASS [2s]
[5/12] ⏳ DESIGNING       并行: api-design + theme-design ...
[6/12] ⏸ MODEL_GEN       (等待中)
[7/12] ⏸ API_GEN         (等待中)
[8/12] ⏸ UI_GEN          (等待中)
[9/12] ⏸ POLISHING       i18n + error-code + mock + skeleton
[10/12] ⏸ BUILD_CHECK    (等待中)
[11/12] ⏸ TEST_GEN       (等待中)
[12/12] ⏸ REVIEWING      review + perf-audit

预计剩余时间: ~3 分钟
```

**日志路径:** `.flow_log/feature-announce-2026-04-10-1430.log`

**状态符号:**
- ✅ 成功
- ⚠️ 警告但继续
- ❌ 失败
- 🔄 重试中
- ⏳ 进行中
- ⏸ 等待
- 🛑 终止

**完成总结(DONE 时输出):**

```
✅ 公告模块完成

📁 生成文件 (9 个):
   docs/specs/announce.md
   docs/plans/announce.md
   docs/api/announce.md
   lib/features/announce/data/models/announce.model.dart
   lib/features/announce/data/repositories/announce_repository.dart
   lib/features/announce/presentation/pages/announce_list_page.dart
   lib/features/announce/presentation/pages/announce_list_controller.dart
   lib/features/announce/presentation/pages/announce_list_binding.dart
   mock/announce/list.json
   mock/announce/detail.json
   docs/review/2026-04-10-announce.md

⏱  耗时: 4 分 32 秒
🎯 Token 用量: ~12,000

下一步建议:
   1. flutter run --dart-define=USE_MOCK=true  → 看 mock 效果
   2. flutter test                              → 跑测试
   3. 后端接口就绪后,改 USE_MOCK=false
```

---

## 11. 自检 Checklist

**Workflow 设计自检(写完 SKILL.md 后过):**
- [x] 所有 state 有出口
- [x] 所有 transition 有触发条件
- [x] 至少 1 条路径到 DONE
- [x] 至少 1 条路径到 ABORT
- [x] 失败路径全覆盖(每个 state 都有 retry/ask/abort)
- [x] Reflector 检查项可机器验证
- [x] Checkpoint 时机覆盖所有 state
- [x] 并行 state 显式标注
- [x] 进度报告格式定义清晰

**运行时自检(每个 state 完成后):**
- [ ] artifact 已写入磁盘
- [ ] reflector 已通过
- [ ] checkpoint 已更新
- [ ] 进度通知已发送

---

## 12. 联动

**成功后建议:**
> "公告模块完成! 建议下一步:
>   - 跑 `flutter run --dart-define=USE_MOCK=true` 看 mock 效果
>   - 调用 `flutter-flow-review` 做更深入评审
>   - 后端接口就绪后,改 .vscode/launch.json 切到 real 模式"

**失败后建议:**
> "在 {state} 阶段失败,checkpoint 已保存到 .flow_checkpoint/feature-{module}-{date}/
> 解决问题后说'继续 {module} 模块'即可恢复。
> 详细错误见 .flow_log/feature-{module}-{date}.log"

**Workflow 编排关系:**
- 上游: (用户直接触发)
- 下游(可选): `flutter-flow-review` (深度评审) / `flutter-flow-release` (发版)
- 替代(图形需求): `flutter-flow-design` (Figma 路径)
