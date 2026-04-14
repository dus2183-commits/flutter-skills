---
name: flutter-dev
description: Flutter 开发的总入口(新手友好)。用户说"做一个 XX 模块"、"开发 YY 功能"、"新需求"时触发。自动引导:AskUserQuestion 收集需求 → 静默调 flutter-manifest-init 生成 YAML 骨架 → 填入用户答案 → 触发 flutter-flow-feature 自动生成代码 → 报告完成 + 回退指引。全中文对话,新手不用记任何 skill 名字。
type: skill
stage: 0
model: opus
priority: P0
version: 1.0.0
owner: @tg
category: orchestration-entry
---

# 开发总入口 (flutter-dev)

## 1. 触发场景

- "做一个 XX 模块" / "做 X 功能"
- "开发 YY 需求" / "新需求: ..."
- "我要做几个模块: A / B / C"
- "帮我实现 XX 页面"
- "用 skills 工具做 X"

**反例(不要用这个 skill):**
- 用户已经有 manifest.yaml → 直接用 `flutter-flow-feature manifest:...`
- 用户已经有 spec.md → 直接用 `flutter-plan` 推进
- 纯 UI 重画(不加新功能) → 用 `flutter-flow-design`
- 想要空 manifest 自己填 → 用 `flutter-manifest-init`

## 2. 和其他 skill 的关系

`flutter-dev` 是**对话式 UX 外壳**,本身不干活,依赖下游:

```
flutter-dev (对话引导,本 skill)
    ├── 内部调 flutter-manifest-init (生成空 YAML)
    ├── 用户对话答案填入 manifest
    ├── 内部调 flutter-flow-feature manifest:xxx (★ 真正干活)
    │      └── fan-out 多个子 Agent,每个走完整 9 步
    │              ├── flutter-spec
    │              ├── flutter-plan
    │              ├── flutter-api-design
    │              ├── flutter-model-gen
    │              ├── flutter-api-gen
    │              ├── flutter-page-gen
    │              ├── flutter-i18n-gen + error-code-gen + mock-gen + skeleton-gen
    │              ├── flutter-test-gen
    │              └── flutter-review
    └── 报告 + 回退指引
```

**核心设计**:**9 步流水线不变,只是前端 UX 变简单**。

## 3. 前置必读

- `docs/_context/api-global.yaml`(全局 API 配置,必须存在)
- `docs/_context/tech-stack.md`
- `docs/_context/conventions.md`
- `_knowledge/context-templates/manifest.template.yaml`
- `flutter-manifest-init/SKILL.md`(了解如何生成骨架)
- `flutter-flow-feature/SKILL.md`(了解 9 步流程)

如果 `api-global.yaml` 不存在,提示用户先跑 `flutter-init` 或手动配置。

## 4. 执行步骤(核心逻辑)

### Step 1 — 解析用户意图

从用户消息提取:
- 模块数量(1 个 / 多个)
- 模块名暗示(如"登录/帖子/视频")
- 是否有 Figma 链接
- 是否明确说"无接口"(纯 UI)

输出给用户看:
```
✓ 收到需求,我理解是做 N 个模块:X / Y / Z。
我会逐个问你每个模块的细节,然后自动生成 manifest + 代码。
```

### Step 2 — 逐模块收集信息(循环 N 次)

对每个模块,用 `AskUserQuestion` 问:

```
[模块 M/N] {module_chinese_name}

1. 英文名(snake_case,用作目录名):
   (回车用默认: {slug})

2. 优先级 P0/P1/P2:
   (回车默认 P0)

3. 有几个页面?页面名?
   例: list + detail,或 login + register

4. 需要接口吗?
   (A) 是 → 贴 Postman JSON,或说"从 /path/to/controller.java 读"
   (B) 否(纯 UI) → 跳过接口填充

5. 每个页面对应 Figma 节点?
   (粘 figma.com URL + node-id,或说"纯代码无设计稿")

6. 有手工切图吗?
   (A) 没有,从 Figma 下 / 或纯代码
   (B) 有,我贴路径 — 填到 manual_assets

7. 路由落点?(类型选: standalone/tab/sub/modal/dialog/bottom_sheet)
   例: /login standalone,/post/list tab
```

### Step 3 — 生成 manifest YAML

- 计算下一个版本号 `N`:扫 `docs/manifests/manifest-v*.yaml`,取 max+1
- 静默调 `flutter-manifest-init`(不提示用户):生成骨架
- 把 Step 2 收集到的答案**结构化填入** YAML
- 接口 JSON:从用户原文里直接提取(Postman 粘的整块直接进 `req_json` / `resp_json` 块)
- 保存 `docs/manifests/manifest-v{N}.yaml`

### Step 4 — 展示 manifest 让用户 confirm(可选)

```
✓ manifest-v{N}.yaml 生成完成,涉及 {N} 个模块。

要先看一眼吗?
  (A) 看一遍再生成 → 停下,用户打开文件改
  (B) 直接生成代码 → 进 Step 5
  (C) 取消 → 回到 Step 2 重收集
```

### Step 5 — 触发 flutter-flow-feature

```
调: flutter-flow-feature manifest:docs/manifests/manifest-v{N}.yaml

这会:
1. 快照代码到 .flow_checkpoint/gen-v{N}/ (回退用)
2. Fan-out {N} 个子 Agent 并行(每模块走完整 9 步)
3. 收尾 review + perf-audit + flutter analyze
```

展示给用户:
```
▶ 已触发批量生成 ({N} 个模块并行)

  [并行执行中,预计 {estimated_minutes} 分钟]
  
  每个模块走完整 9 步:spec → plan → api-design (如有) → model-gen (如有)
                       → api-gen (如有) → page-gen → polishing
                       → test-gen → review
  
  完成后给你汇总报告。
```

### Step 6 — 报告完成

```
✅ 完成!{N} 个模块代码已生成

产物位置:
  - docs/specs/*.md
  - docs/plans/*.md
  - docs/api/*.md (有接口的模块)
  - lib/features/*/
  - test/features/*/
  - docs/review/{date}.md (汇总)
  - docs/manifests/manifest-v{N}.yaml (归档,可用于复跑)

验证:
  $ fvm flutter analyze   # 应该 0 error
  $ fvm flutter run -d chrome --web-port=9999

回退:
  说 "回退到 v{N}" 或 "只回退 {某模块} 到 v{N}"

下一步建议:
  {根据生成物推荐下一步,如跑 flutter-health-check 或继续做下个模块}
```

## 5. 输出产物

同 `flutter-flow-feature` + 多一个 `docs/manifests/manifest-v{N}.yaml`(归档)。

## 6. 常见错误

### ❌ 跳过对话直接生成
用户消息信息不全时,**必须用 AskUserQuestion 问清楚再生成**,不要脑补。
脑补的 manifest 字段错了,后面 9 步全错。

### ❌ 用户说"有 3 个模块" 但没说具体信息就触发
应反问 "3 个模块分别是什么?先告诉我第 1 个"。

### ❌ 不生成 manifest 直接调 flow-feature
manifest 是**归档产物**,哪怕只 1 个模块也要生成。这样 3 个月后可以翻历史。

### ❌ 把 Figma URL 硬编码进代码
切图必须下载到 `assets/image/3.0x/{module}/`,代码用 `Image.asset`。Reflector 拦截 `figma.com/api/mcp/asset` 字符串。

### ❌ 并行超过 5 个模块
子 Agent 同时跑太多 context 爆炸,超过 5 个时自动分批(每批 3-5 个)。

## 7. 退出条件

- ✅ `docs/manifests/manifest-v{N}.yaml` 已生成
- ✅ `flutter-flow-feature` 已触发并完成
- ✅ 用户收到汇总报告 + 回退指引
- ✅ `fvm flutter analyze` 0 error(由 flow-feature 保证)

## 8. 和 flutter-manifest-init / flutter-flow-feature 的选择

| 场景 | 用 |
|---|---|
| 新手 / 不知道字段怎么填 | **flutter-dev** ← 推荐 |
| 老手 / 精细控制每个字段 | `flutter-manifest-init` + 手动填 + `flutter-flow-feature manifest:` |
| 已有团队协作的 manifest | 直接 `flutter-flow-feature manifest:xxx` |
| 临时问一个简单问题 | 不要走工作流,直接对话 |

**默认推荐 flutter-dev**,除非明确要精细控制。
