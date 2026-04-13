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
- [完整工作流示例](#完整工作流示例)
- [核心能力](#核心能力)
- [贡献指南](#贡献指南)

---

## 项目定位

### 核心价值
1. **降本** — 从 0 到可运行的 Flutter 项目: 2 周 → 1 天
2. **保质** — 所有代码自动符合规范、三端兼容、加密、Mock-first
3. **可演进** — 每次决策入档,新人 1 天上手

### 它解决什么问题
- **从 0 搭 Flutter 项目** → 不需要每次重新配加密/Mock/GetX/三端/Lint
- **团队协作** → SKILL.md 模板 + 规范 + 工作流,新人 1 天上手
- **代码生成** → 说"做 XX 模块",自动产出 spec → plan → 接口契约 → model → repository → 页面
- **质量保障** → 14 类常见 bug 防御,Quality Gate 5 个关卡自动卡

---

## Quick Start

### 1. 克隆仓库
```bash
# 放到任意位置,比如 ~/Desktop/skills/
git clone <this repo> ~/Desktop/skills/flutter-skills
```

### 2. 安装 (一次性)
```bash
mkdir -p ~/.claude/skills

# 全局装 init（用于创建新项目）
ln -s ~/Desktop/skills/flutter-skills/flutter-init ~/.claude/skills/flutter-init
ln -s ~/Desktop/skills/flutter-skills/_orchestration/flutter-flow-init ~/.claude/skills/flutter-flow-init

# 其他 skill 在 init 创建项目时自动复制到项目 .claude/skills/
# ⚠️ 是复制不是软链（Claude Code 不跟踪软链）
```

### 3. 创建新项目
打开 Claude Code,直接说:
```
新建一个 Flutter 项目 my_app
```

Claude 会问你:
- 项目名/包名
- 项目类型: standard (普通) 还是 video (视频)
- 代码规范: full (严格) / light (宽松) / free (自由)
- Tab 数量和名称

然后自动:
- 生成项目骨架 (60+ 文件)
- **安装对应的 skill 到项目 `.claude/skills/`**
- 复制对应等级的 CLAUDE.md
- 三端编译验证

### 4. 做功能
在项目目录下说:
```
做一个公告模块,有列表和详情,后端 Swagger 如下: {...}
```

Claude 自动走完整流水线:
```
spec → plan → api-design → model-gen → api-gen → page-gen → review
```

### 5. 运行
```bash
fvm flutter run --dart-define=USE_MOCK=true
```

---

## 代码规范等级

| 等级 | 安装的 skill | 强制规则 | 适合场景 |
|------|-------------|---------|---------|
| **full** | 全部 35 个 | freezed + ApiClient + mockKey + tearoff + EasyRefresh | 团队正式项目 |
| **light** | 5 个核心 | GetX 但不强制 freezed/ApiClient | 个人项目、快速原型 |
| **free** | 无 | 只有目录结构 | Demo、实验 |

**已有项目切换等级?** 换 CLAUDE.md + 增删 `.claude/skills/` 里的软链:
```bash
# 换规范
cp ~/Desktop/skills/flutter-skills/flutter-init/template/_claude_templates/CLAUDE_light.md ./CLAUDE.md

# 加/减 skill
ln -s ~/Desktop/skills/flutter-skills/flutter-page-gen .claude/skills/flutter-page-gen
```

---

## Skill 依赖关系

skill 之间有上下游依赖,**不能跳步骤**:

```
用户需求
   │
   ▼
flutter-spec         需求 → 结构化文档 (docs/specs/{m}.md)
   │
   ▼
flutter-plan         文档 → 任务清单 (docs/plans/{m}.md)
   │
   ▼
flutter-api-design   任务 → 接口契约 (docs/api/{m}.md)
   │
   ├──────────────────────────┐
   ▼                          ▼
flutter-model-gen          flutter-theme-design
freezed 实体类               主题配置
   │
   ▼
flutter-api-gen            依赖 model-gen 的输出
Repository + Binding + Mock
   │
   ├──────────────────────────┐
   ▼                          ▼
flutter-page-gen           flutter-widget-gen
页面三件套                   公共组件
   │
   ▼
flutter-test-gen           依赖 repository 的输出
单元测试
   │
   ▼
flutter-review + flutter-perf-audit
代码评审 + 性能审计
```

**快捷方式:** 不想一步步来? 用 `flutter-api-quick` 一键从 Swagger JSON 生成全套 (契约+model+repository+binding+mock)。

**Workflow 自动编排:** 用户只说"做 XX 模块",`flutter-flow-feature` 会自动按依赖顺序调用每个 skill,不需要手动一个个触发。

---

## 独立 skill (无依赖,随时可用)

这些 skill 不依赖其他 skill,可以单独使用:

| Skill | 触发词 |
|-------|--------|
| flutter-i18n-gen | "国际化" / "提取中文" |
| flutter-route-guard | "加登录拦截" / "路由守卫" |
| flutter-migrate | "重命名模块" / "移动页面" |
| flutter-mock-gen | "生成 mock 数据" |
| flutter-env-config | "配置多环境" |
| flutter-error-code-gen | "生成错误码常量" |
| flutter-skeleton-gen | "骨架屏" / "shimmer" |
| flutter-deeplink | "配置深链接" |
| flutter-changelog | "生成 changelog" |
| flutter-lint-fix | "格式化代码" |
| flutter-health-check | "项目体检" |

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
│ L4 Skill           29 个 worker skill                     │
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

## 核心能力

### 生产级代码底座
- **接口加密** — AES-CBC-256 + 动态 key (HMAC-SHA256) + GZIP 压缩,三端一套
- **加密图片** — 自实现 `NetworkImage`,`.bnc` URL 自动解密,io / web 双实现
- **三端严格兼容** — Android / iOS / Web 全量支持,条件导出 + 权限降级
- **Mock-first 开发** — `MockInterceptor` 按 `USE_MOCK` 编译期开关,业务层零感知
- **sealed class 异常体系** — `AppException` 基类 + 7 类子异常,类型安全 catch
- **GetX 全家桶** — 状态管理 / 路由 / DI / i18n 一体化
- **fvm 版本锁定** — 锁 Flutter 3.27.2,团队任何环境一行命令就绪

### AI 工作流编排
- **24 个交付物**: 6 个 Workflow + 18 个 Worker Skill
- **Artifact 管道**: spec → plan → api-design → model → api → page → review,全流程产物可追溯
- **L6 Orchestration**: Router + Conductor + Reflector 三角色,自动编排多步骤任务
- **状态机 + Checkpoint**: workflow 可中断、可恢复、跨会话延续
- **Reflector 质量保障**: 每步 artifact 二次评估(Schema + Rule + LLM 三策略)
- **5 个 Quality Gate**: Spec / Plan / Design / Code / Review 每阶段卡口

### 自动化脚手架
- **一键 setup**: `bash scripts/setup.sh` 装 fvm + 锁 Flutter 版本 + pub get + build_runner
- **分级 build_check**: `quick` (3s) / `fast` (20s,默认) / `full` (2-5 min)
- **数据驱动 Tab**: `lib/app/tabs.dart` 加减 Tab 改一个文件,自动适应 0/1/N
- **EasyRefresh 下拉刷新 + 上拉加载**: 中文文案,锁版本兼容 web
- **占位符替换**: 新项目初始化自动替换 `{{PROJECT_NAME}}` / `{{TAB_1_NAME}}` 等

### 工程规范
- **14 类常见 bug 防御** 写入 SKILL.md 模板(R2-R6 端到端测试积累)
- **编码规范** 命名 / Widget 拆分阈值 / GetX 使用 / 多平台铁律
- **错误码段位** 每模块 100 个段位,不冲突
- **ADR 决策记录** 追加式,不删历史
- **项目级权限** 82 allow + 30 deny,sub-agent 继承

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
