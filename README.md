    # Flutter Skills

> 一套基于 Claude Code Skill 框架的 Flutter 工程化工具集。
>
> **一句话:** 用户输入"做一个 XX 模块",自动产出符合规范、加密、三端兼容的 Flutter 代码。

---

## 目录

- [项目定位](#项目定位)
- [Quick Start](#quick-start)
- [系统全景](#系统全景)
- [24 个交付物](#24-个交付物)
- [3 人分工总览](#3-人分工总览)
- [完整工作流示例](#完整工作流示例)
- [与 yc141 / Go skill 的关系](#与-yc141--go-skill-的关系)
- [贡献指南](#贡献指南)

---

## 项目定位

### 核心价值
1. **降本** — 从 0 到可运行的 Flutter 项目: 2 周 → 1 天
2. **保质** — 所有代码自动符合规范、三端兼容、加密、Mock-first
3. **可演进** — 每次决策入档,新人 1 天上手

### 与同类项目的差异
- vs **手写 Flutter 项目** — 不需要每次重新搭脚手架
- vs **`flutter create` 模板** — 内置加密、Mock、GetX、规范、AI 工作流
- vs **Go 那套 skill** — 完整 multi-agent 编排,有 Reflector + Checkpoint
- vs **yc141** — 多了工作流编排 + Mock 系统 + 18 个 skill

---

## Quick Start

### 1. 安装
```bash
git clone <this repo> ~/.claude/skills/flutter-skills
```

### 2. 创建新项目
```
你: 帮我新建一个 Flutter 项目 my_app

Claude: [触发 flutter-flow-init workflow]
  → 收集参数 (项目名/包名/Tab/平台)
  → dry-run 列出 67 个文件
  → 用户确认
  → 复制 template/
  → 三端编译验证
  → ✅ 项目 my_app 创建成功

你: 现在做一个公告模块,有列表和详情

Claude: [触发 flutter-flow-feature workflow]
  → spec → plan → api-design → model-gen → api-gen → page-gen → review
  → ✅ 公告模块完成,已生成 11 个文件

你: flutter run --dart-define=USE_MOCK=true
```

---

## 系统全景

### 8 层架构

```
┌──────────────────────────────────────────────────────────┐
│ L8 Observability   日志 / 调用统计 / 失败追踪              │
├──────────────────────────────────────────────────────────┤
│ L7 Governance      规则 / 检查清单 / Hook                  │
├──────────────────────────────────────────────────────────┤
│ L6 Orchestration   Router + Conductor + Reflector         │
├──────────────────────────────────────────────────────────┤
│ L5 Workflow        6 个 flutter-flow-*                    │
├──────────────────────────────────────────────────────────┤
│ L4 Skill           18 个 worker skill                     │
├──────────────────────────────────────────────────────────┤
│ L3 Knowledge       Context + Artifact + Memory            │
├──────────────────────────────────────────────────────────┤
│ L2 Tool            Read/Write/Bash/Figma MCP/Vision       │
├──────────────────────────────────────────────────────────┤
│ L1 Foundation      Claude Opus / Sonnet / Haiku           │
└──────────────────────────────────────────────────────────┘
```

详见 [`ARCHITECTURE.md`](./ARCHITECTURE.md)。

---

## 24 个交付物

### Workflow (6 个,L5/L6 编排层)

| Workflow | 用途 |
|---|---|
| `flutter-flow-init` | 初始化新 Flutter 项目 |
| `flutter-flow-feature` ★ | 功能开发主流水线(spec→...→review) |
| `flutter-flow-design` | Figma/截图 → 代码 |
| `flutter-flow-review` | 评审流水线 |
| `flutter-flow-govern` | 治理(改决策/规范) |
| `flutter-flow-release` | 发版构建 |

### Skill (18 个,L4 worker)

按 6 类组织:

**Designer (4)** — 生成结构化文档
- `flutter-spec`
- `flutter-plan`
- `flutter-api-design`
- `flutter-theme-design`

**Generator (5)** — 生成代码
- `flutter-init` ★ (含 template/)
- `flutter-model-gen`
- `flutter-api-gen` ★
- `flutter-page-gen`
- `flutter-widget-gen`

**Bridge (1)** — 调外部系统
- `flutter-design-to-code` (Figma MCP)

**Validator (3)** — 检查不修改
- `flutter-review`
- `flutter-health-check`
- `flutter-test-gen`

**Mutator (3)** — 修改现有文件
- `flutter-context-update`
- `flutter-lint-fix`
- `flutter-release`

**Transformer (2)** — 格式转换
- `flutter-api-doc`
- `flutter-changelog`

---

## 3 人分工总览

| | 你(组长) | B | C |
|---|---|---|---|
| **抓什么** | 系统 + 主轴 | 数据生成 | UI + 设计 + 质量 |
| **Workflow** | 全部 6 个 | - | - |
| **Skill** | 6 个 | 5 个 | 7 个 |
| **代码** | template + core/ | - | 5-Tab UI + widgets |
| **总交付物** | 14 项 | 6 项 | 10 项 |
| **关键路径** | ApiClient 签名 + Workflow | 等签名 | 等 5-Tab 框架 |

详细分工见 [`docs/team.md`](./docs/team.md) (待写)。

---

## 完整工作流示例

### 场景: "做一个公告模块"

```
[用户] 做一个公告模块,能看列表和详情,能标记已读

         ↓ Router 识别为 feature_workflow

[Conductor] 启动 flutter-flow-feature

[Step 1/9] SPEC'ING       
  → 调用 flutter-spec
  → 生成 docs/specs/announce.md (1.2 KB)
  → Reflector 检查: PASS

[Step 2/9] PLANNING       
  → 调用 flutter-plan
  → 生成 docs/plans/announce.md
  → 拆出 9 个任务,标记 mock 先行点
  → Reflector PASS

[Step 3/9] DESIGNING       
  → 并行调用 flutter-api-design + flutter-theme-design
  → 生成 docs/api/announce.md
  → 错误码段位 21001-21099
  → Reflector PASS

[Step 4/9] MODEL_GEN      
  → 调用 flutter-model-gen
  → 生成 announce.model.dart (freezed)
  → bash: dart run build_runner build → 通过

[Step 5/9] API_GEN        
  → 调用 flutter-api-gen
  → 生成 announce_repository.dart + binding
  → 生成 mock/announce/list.json + detail.json
  → Reflector 检查: 调用 ApiClient ✓

[Step 6/9] UI_GEN         
  → 并行调用 flutter-page-gen × 2 (list + detail)
  → 生成 6 个文件 (page + controller + binding × 2)
  → 注册路由

[Step 7/9] BUILD_CHECK    
  → bash: flutter analyze (0 error)
  → bash: flutter build apk --debug (通过)

[Step 8/9] REVIEWING      
  → 调用 flutter-review
  → 7 大类全过 (0 ❌, 0 ⚠️)
  → 写 docs/review/2026-04-10-announce.md

[Step 9/9] DONE           ✅

📁 生成 11 个文件
⏱  耗时 4 分 32 秒
🎯 Token: ~12k

下一步: flutter run --dart-define=USE_MOCK=true
```

---

## 与 yc141 / Go skill 的关系

### 与 yc141_app 的关系
yc141 是我们的**代码底座**:
- 加密层 (aes_dynamic + aes_util) → 直接复用
- 加密图片三平台实现 → 直接复用
- web/js/ 加密 JS → 直接复用
- HttpApi → 改造成 ApiClient + 6 个 Interceptor
- AppAPI → 改造成 AppConfig (GetxService + abstract)

我们的**增量价值**:
- Mock-first 工作流 (yc141 没有)
- 6 个 Workflow 编排 (yc141 没有)
- 18 个自动化 skill (yc141 没有)
- AppException sealed class 体系 (yc141 用 String)
- Context Pack + ADR 机制 (yc141 没有)

### 与 Go 那套 skill 的对比

| 特性 | Go 那套 (api-design/code-generate/api-doc/solution-review) | 我们 |
|---|---|---|
| Skill 数 | 4 个 | 24 个 (6 workflow + 18 skill) |
| 编排 | 靠 frontmatter 提示用户 | 完整 L6 Conductor |
| 状态 | 无 | 状态机 + Checkpoint |
| 质量保障 | 单 skill 自检 | Reflector 二次评估 |
| 失败恢复 | 无 | Checkpoint 恢复 |
| Mock 支持 | 无 | 全套 |
| 多端 | 无 | 严格三端 |
| 加密 | 无 | yc141 级别 |

---

## 贡献指南

### Skill 开发流程
1. 写 SKILL.md (10 段或 12 段标准格式)
2. 跑 `tests/e2e/` 端到端测试
3. 跑 `flutter-review` 自审
4. PR review 后 merge

### SKILL.md 必须遵循
- L4 worker: `_shared/skill.template.md` 10 段
- L5/L6 workflow: `_shared/workflow.template.md` 12 段
- frontmatter: `_shared/frontmatter-spec.md`

### 测试
- 单 skill: `tests/fixtures/{skill}/`
- 端到端: `tests/e2e/`

---

## License

Internal use only.

---

## 链接

- [架构设计](./ARCHITECTURE.md) — 8 层架构详解
- [SKILL.md 模板](./_shared/skill.template.md) — 写 skill 必读
- [Workflow 模板](./_shared/workflow.template.md) — 写 workflow 必读
- [Frontmatter 规范](./_shared/frontmatter-spec.md) — 字段定义
- [Reflector 设计](./_design/reflector_design.md) — 系统灵魂
- [Checkpoint 设计](./_design/checkpoint_design.md) — 失败恢复
- [ApiClient 接口契约](./_design/api_client_signature.dart) — B 必读
- [AppException 体系](./_design/app_exception.dart) — 异常类
