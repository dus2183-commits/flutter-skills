# 使用手册

> 给开发者的标准触发词速查表。38 个 skill,复制粘贴直接用。
>
> 当前规模:32 个 L4 工种 skill + 6 个 L6 编排流水线 + L5 L3 基础设施。
> 最近更新:2026-04-14 — 加入 `flutter-dev` 新手入口 / `manifest-init` 批量清单 / `post-figma` MCP 后处理 / `rollback` 版本回退 / `asset-import` 批量切图 / 10 条 Figma 坑 reflector 静态拦截。

---

## 📌 入口速查(90% 场景)

### 🟢 新手 / 不知道用哪个 → `flutter-dev`
```
做一个启动页,居中 logo,2s 后按 token 跳 home/sign-in
```
**关键词:** "做 XX 模块" / "开发 YY 功能" / "新需求" / "做一个 XX 页"
**自动串:** AskUserQuestion 收集 → 生成 manifest → `flutter-flow-feature` 批量生成
**适合:** 从零起步、不想记 skill 名字

### 🟢 新项目 → `flutter-init` / `flutter-flow-init`
```
新建一个 Flutter 项目,项目名 social_app,包名 com.xxx.social,video 类型,full 规范
```
**产出:** GetX + 三端 + 接口加密 + Mock 开关 + 5-Tab 主壳 + 完整 docs/_context/ 的脚手架。

### 🟢 批量模块 → `flutter-manifest-init` + `flutter-flow-feature`
```
步骤 1: /flutter-manifest-init        → 生成 docs/manifests/manifest-v{N}.yaml 骨架
步骤 2: 用户填:路由 / 页面 Figma node-id / 接口 JSON / 手工切图
步骤 3: /flutter-flow-feature manifest:docs/manifests/manifest-v{N}.yaml
                                      → fan-out 子 Agent 并行做 N 个模块
```
**关键词:** "批量开发" / "生成清单模板" / "做这 9 个模块"
**适合:** 一次要做 3+ 个模块,Figma 全图拿到手

### 🟢 单模块快速 API → `flutter-api-quick`
```
快速生成这几个接口:{贴 Swagger}
```
**关键词:** "快速生成 API" / "一键生成" / "粘贴即出"
**跳过:** spec / plan 直接产 contract + model + Repository + Binding + Mock + build_runner

### 🟢 Figma 画面 → `flutter-design-to-code`(⚠️ 不是 figma-implement-design)
```
根据 Figma 生成 XX 页: https://www.figma.com/design/.../...?node-id=1-577
```
**关键词:** "根据 Figma 生成" / "实现这个 Figma 设计" / "重新设计 XX 页(含链接)"
**区别:** 按项目规范下 3x 切图到 `assets/image/3.0x/{module}/`、按 `ic_/bg_/img_` 命名、更新 pubspec、map 到项目 token — 而官方 `figma:figma-implement-design` 用的是 7 天过期的 MCP URL。

### 🟢 回退批次 → `flutter-rollback`
```
/flutter-rollback v3            # 整批回到 v3 生成前
/flutter-rollback v3 post       # 只回 post 模块,其他保留
```
**关键词:** "回退到 v2" / "撤销上次生成" / "恢复之前的代码"

---

## 🧩 L4 工种 skill(32 个,单阶段出问题时单独调用)

### ─── 设计阶段 ───

| 说什么 | 触发 | 产出 |
|---|---|---|
| "做 XX 模块 / 新需求 / 设计 XX 功能" | `flutter-spec` | `docs/specs/{m}.md` 7 段 |
| "拆任务 / 做任务清单" | `flutter-plan` | `docs/plans/{m}.md` 6 类任务 |
| "设计接口 / 做接口契约" | `flutter-api-design` | `docs/api/{m}.md` |
| "加一条决策 / 改技术栈 / 更新规范" | `flutter-context-update` | `docs/_context/*.md` + ADR |
| "做接口使用文档" | `flutter-api-doc` | `docs/api-public/{m}.md` |

### ─── 生成阶段 ───

| 说什么 | 触发 | 产出 |
|---|---|---|
| "JSON 转 Dart / 生成 model" | `flutter-model-gen` | freezed `*.dart` |
| "生成 repository / 生成接口请求" | `flutter-api-gen` | `*_repository.dart` + Binding + Mock |
| "生成 XX 页面 / 做列表页 / 做表单页" | `flutter-page-gen` | View + Controller + Binding |
| "做一个按钮 / 封装 XX / 抽成组件" | `flutter-widget-gen` | stateless / stateful / reactive widget |
| "加一个颜色 / 改字号 / 新主题" | `flutter-theme-design` | `lib/app/theme/` + ADR |

### ─── 增强阶段 ───

| 说什么 | 触发 | 产出 |
|---|---|---|
| "生成单测 / 写测试 / 加测试" | `flutter-test-gen` | mocktail `*_test.dart`,3 场景 |
| "生成 mock 数据 / 补充测试数据" | `flutter-mock-gen` | `mock/{m}/*.json`,faker 风格 |
| "国际化 / 提取中文 / 改成 .tr" | `flutter-i18n-gen` | 替换代码 + `locales/*.dart` |
| "骨架屏 / shimmer / 加载占位" | `flutter-skeleton-gen` | 骨架 Widget |
| "错误码常量 / 生成 enum" | `flutter-error-code-gen` | `*_error_codes.dart` |

### ─── 设计稿 / 切图 ───

| 说什么 | 触发 | 产出 |
|---|---|---|
| "根据 Figma 生成 / Figma URL" | `flutter-design-to-code` ⭐ | UI 代码 + 3x 切图 + pubspec 登记 |
| "figma-implement-design 跑完了要补全" | `flutter-post-figma` ⭐ | 下载 CDN 图 / 改 `Image.asset` / 加 Controller+Binding / 登路由 / 反推 spec |
| "导入切图 / 我自己切的图 / 贴图 + 自动改名" | `flutter-asset-import` | 按 `ic_/bg_/img_` 命名 + 3x/2x/1x + pubspec |

### ─── 质量阶段 ───

| 说什么 | 触发 | 产出 |
|---|---|---|
| "评审 / review / 检查代码 / 看下规范" | `flutter-review` | `docs/review/{date}.md` |
| "性能检查 / 优化扫描" | `flutter-perf-audit` | 性能报告 |
| "体检 / 项目健康检查" | `flutter-health-check` | `docs/_health/{date}.md` |
| "修格式 / 跑 lint" | `flutter-lint-fix` | dart format + dart fix(PostToolUse hook 自动触发) |

### ─── 工程阶段 ───

| 说什么 | 触发 | 产出 |
|---|---|---|
| "配置多环境 / 加 staging / 切 prod" | `flutter-env-config` | `lib/core/config/env_config.dart` + 脚本 |
| "路由守卫 / 登录拦截 / 未登录跳登录" | `flutter-route-guard` | GetX middleware |
| "配置深链接 / URL 打开 App / web 刷新不崩" | `flutter-deeplink` | Android/iOS/Web 配置 |
| "重命名模块 / 删除模块 / 移动页面" | `flutter-migrate` | 批量改 import / 路由 / binding / mock 路径 |

### ─── 发版阶段 ───

| 说什么 | 触发 | 产出 |
|---|---|---|
| "发版 / build release / 打包 v1.0.0" | `flutter-release` | apk/ipa/web 产物 |
| "生成 changelog / 更新变更日志" | `flutter-changelog` | `CHANGELOG.md`(Keep a Changelog) |

---

## 🚀 L6 编排流水线(6 个,一句话触发多个 skill)

| 说什么 | 流水线 | 覆盖 |
|---|---|---|
| "做 XX 模块"(单/多) | `flutter-flow-feature` | spec → plan → api-design → model → repo → page → test → review |
| "根据 Figma 生成页面" | `flutter-flow-design` | figma → design-to-code → page-gen → review |
| "评审一下 / 全量检查" | `flutter-flow-review` | health-check → lint-fix → review → perf-audit |
| "发版 v1.0.0" | `flutter-flow-release` | pre-check → bump → changelog → build 三端 |
| "新建项目 / 初始化 Flutter" | `flutter-flow-init` | init → replace → pub get → build → install skills |
| "改技术栈 / 新 ADR" | `flutter-flow-govern` | context-update → compliance-check → migrate |

---

## 🔁 批量开发最佳实践(manifest 流)

### 场景
一次性要做 3+ 个模块,每个都有路由 + 页面 + 接口 + 切图。

### 4 步走
```
1. /flutter-manifest-init modules_count=9
   → docs/manifests/manifest-v{N}.yaml 骨架(9 个空 module 块)

2. 手工填 yaml(从 Swagger / API.md / Figma nodeId 复制即可)
   - routes[]: path + type + parent + position_note
   - pages[]: name + file_key + node_id + spec_only
   - endpoints[]: method + path + mock_key + req_json + resp_success + resp_fail
   - manual_assets[]: 切图路径(可留 TODO)

3. /flutter-flow-feature manifest:docs/manifests/manifest-v{N}.yaml
   → fan-out N 个子 Agent 并行做(每个模块走完整 9 步)
   → 自动跑 flutter-review + perf-audit + analyze
   → 产出 docs/review/{date}.md 汇总

4. 失误回退: /flutter-rollback v{N}          # 全回
             /flutter-rollback v{N} post     # 只回 post 模块
```

### 触发时机
- ✅ 设计稿已经拿到全部 Figma nodeId
- ✅ 后端接口 mock / 文档已写好
- ✅ 已跑 `/flutter-manifest-init` 生成骨架
- ❌ 只想做 1 个模块 → 直接 `/flutter-dev` 更快
- ❌ 还不知道要做啥 → 先 `/flutter-dev` 对话收集

---

## ❓ 常见问答

**Q: 说了"做 XX 模块"但 Claude 直接写代码没走流水线?**
A: 加 "走 flutter-flow-feature 流水线,严格按 spec → plan → api-design → model-gen → api-gen → page-gen → test-gen 顺序"。更稳的做法:**`/flutter-dev` 开头**。

**Q: Claude 去加载 `figma:figma-implement-design` 抢占了我们的 `flutter-design-to-code`?**
A: 这是常见坑 — 官方 skill 触发词太宽。修法:
- 永远用 `/flutter-dev` 开头 → 它不会跳
- 或显式说:"用 flutter-design-to-code,不要用 figma-implement-design"
- 如果已经被抢占跑了一半 → `/flutter-post-figma` 反推 spec + 补全项目规范

**Q: MCP asset URL 写进了 Dart 代码,7 天后图全挂?**
A: reflector.sh 已自动拦截(blocking)。正确做法:curl 下载到 `assets/image/3.0x/{module}/` + 改 `Image.asset`。`flutter-design-to-code` 自动做。

**Q: 下载完图 Read 验证就 API 400?**
A: 大图(>1MB)Read 会 API 400 卡死。用 `ls -lh` / `file` 代替,SVG 例外(XML 文本)。CLAUDE.md 已写铁律。

**Q: 改的东西涉及核心文件(ApiClient 等)被 hook 拦截?**
A: 故意的,核心文件不该随意改。确有必要 `ALLOW_CORE_EDIT=1`。

**Q: 想跳过 spec 直接生成代码?**
A: `/flutter-api-quick` 一键出,Swagger: {...}。

**Q: 多模块并行不好控?**
A: 用 manifest 流 — fan-out 子 Agent 自然并行,单 Agent 不易漏步。

**Q: 想让 Claude 只读 SKILL.md 模板不自己发挥?**
A: 请求里加 "必须先读 `.claude/skills/flutter-xxx/SKILL.md` 段 6 代码模板"。

---

## 📝 推荐说话模板

### 从零做一个模块(新手推荐)
```
/flutter-dev 做 {模块名}:{一句话描述}
Figma: {URL}(可选)
接口: 见 {后端 API.md 路径}
```

### 批量做多个模块
```
步骤 1: /flutter-manifest-init
步骤 2: 填 docs/manifests/manifest-v{N}.yaml
步骤 3: /flutter-flow-feature manifest:docs/manifests/manifest-v{N}.yaml
```

### 单模块完整流水线(老手精确)
```
做 {模块名},走 flutter-flow-feature。

baseUrl: {xxx}
响应格式: {code, data, msg}
加密: static_aes / none
分页: page + page_size
字段: snake_case

Swagger / 接口文档:
{贴 JSON 或路径}
```

### Figma 画面落地
```
/flutter-design-to-code {Figma URL}
```
(不要说 "根据 Figma 实现" — 会被官方 figma-implement-design 抢)

### 质量检查
```
评审一下 lib/features/{模块}/ 的代码,走 flutter-flow-review。
```

### 加新功能到现有模块
```
给 {模块} 加一个 {页面/接口},按项目规范。
```

### 回退
```
/flutter-rollback v{N}          # 全批
/flutter-rollback v{N} {模块}   # 只回某模块
```

---

## 📚 参考路径

- **skill 源:** `/Users/tg/Desktop/skills/flutter-skills/`
  - `_orchestration/flutter-flow-*/` — 6 个流水线
  - `flutter-*/` — 32 个工种
  - `_knowledge/context-templates/*.template.yaml` — manifest / api-global 模板
  - `_shared/skill.template.md` / `workflow.template.md` — SKILL.md 10 段 / workflow 12 段标准
  - `_governance/hooks/reflector.sh` — 静态拦截(25 类 bug 防御)
- **项目级 skill:** `{project}/.claude/skills/flutter-*` — 项目内软链,每项目独立
- **全局 skill:** `~/.claude/skills/flutter-*` — 跨项目共享
- **架构:** `ARCHITECTURE.md` — 8 层架构详解
- **README:** `README.md` — 项目入口
