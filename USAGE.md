# 使用手册

> 给开发者的标准触发词速查表。复制粘贴直接用。

---

## 核心流程（90% 场景）

### 1. 创建新项目
```
新建一个 Flutter 项目，项目名 xxx，包名 com.xxx.xxx，video 类型，full 规范
```

### 2. 做功能（主入口）
```
做 auth、post、video 3 个模块，走 flutter-flow-feature 流水线。

baseUrl: xxx
响应格式: {code, data, msg}
分页: page + page_size

Swagger: {贴 JSON}
```
**关键词**: "做 XX 模块" / "实现 XX 功能" / "新需求"

### 3. 快速生成接口（跳过 spec/plan）
```
快速生成这些接口：{贴 Swagger}
```
**关键词**: "快速生成 API" / "一键生成" / "粘贴即出"

---

## 单独调用（某个阶段出问题时）

### 设计阶段
| 说什么 | 触发什么 | 产出 |
|--------|---------|------|
| "做 XX 模块 / 新需求 / 设计 XX 功能" | spec | `docs/specs/{m}.md` |
| "拆任务 / 做任务清单" | plan | `docs/plans/{m}.md` |
| "设计接口 / 做接口契约" | api-design | `docs/api/{m}.md` |
| "改技术栈 / 加决策 / 更新规范" | context-update | `docs/_context/*.md` + ADR |

### 生成阶段
| 说什么 | 触发什么 | 产出 |
|--------|---------|------|
| "JSON 转 Dart / 生成 model" | model-gen | `*.model.dart` |
| "生成 repository / 生成接口请求" | api-gen | `*_repository.dart` + mock |
| "生成 XX 页面 / 做列表页 / 做详情页 / 做表单页" | page-gen | 三件套 |
| "做一个按钮 / 封装 XX 组件 / 生成卡片" | widget-gen | 公共组件 |
| "加一个颜色 / 改字号 / 新主题" | theme-design | 修改 `lib/app/theme/` + ADR |

### 增强阶段
| 说什么 | 触发什么 | 产出 |
|--------|---------|------|
| "生成单测 / 写测试 / 给 XX 加测试" | test-gen | `test/features/{m}/*_test.dart` |
| "生成 mock 数据 / 补充测试数据" | mock-gen | `mock/{m}/*.json` |
| "国际化 / 提取中文 / 改成 .tr" | i18n-gen | 替换代码 + `locales/*.dart` |
| "骨架屏 / shimmer / 加载占位" | skeleton-gen | 骨架 Widget |
| "错误码常量 / 生成 enum" | error-code-gen | `*_error_codes.dart` |
| "生成接口文档" | api-doc | `docs/api-public/{m}.md` |

### 质量阶段
| 说什么 | 触发什么 | 产出 |
|--------|---------|------|
| "评审 / review / 检查代码" | review | `docs/review/{date}.md` |
| "性能检查 / 优化扫描" | perf-audit | 性能报告 |
| "体检 / 项目健康检查" | health-check | `docs/_health/{date}.md` |
| "修格式 / 跑 lint" | lint-fix | 自动 format |

### 工程阶段
| 说什么 | 触发什么 | 产出 |
|--------|---------|------|
| "配置多环境 / 加 staging" | env-config | `lib/core/config/env_config.dart` |
| "路由守卫 / 登录拦截" | route-guard | middleware |
| "配置深链接 / URL 打开 App" | deeplink | Android/iOS/Web 配置 |
| "重命名模块 / 删除模块 / 移动页面" | migrate | 批量改 import/路由 |

### 设计稿
| 说什么 | 触发什么 | 产出 |
|--------|---------|------|
| "根据 Figma 生成 / https://figma.com/..." | design-to-code | UI 代码 + 切图清单 |
| "MCP 读取设计稿" | mcp | Token 映射 |

### 发版
| 说什么 | 触发什么 | 产出 |
|--------|---------|------|
| "发版 / build release / 打包" | release | apk/ipa/web 产物 |
| "生成 changelog / 更新变更日志" | changelog | `CHANGELOG.md` |

---

## 流水线（一句话触发多个 skill）

| 说什么 | 流水线 | 覆盖 |
|--------|--------|------|
| "做 XX 模块" | flutter-flow-feature | spec→plan→api-design→model→repo→page→test→review |
| "根据 Figma 生成页面" | flutter-flow-design | figma→design-to-code→page-gen→review |
| "评审一下" | flutter-flow-review | health-check→lint-fix→review→perf-audit |
| "发版 v1.0.0" | flutter-flow-release | pre-check→bump→changelog→build三端 |
| "新建项目" | flutter-flow-init | init→replace→pub get→build→install skills |
| "改技术栈 / 新 ADR" | flutter-flow-govern | context-update→compliance-check→migrate |

---

## 常见问答

**Q: 说了"做 XX 模块"但 Claude 直接写代码没走流水线？**
A: 加一句"走 flutter-flow-feature 流水线，严格按 spec → plan → api-design → model-gen → api-gen → page-gen → test-gen 顺序"。

**Q: 多模块怎么说？**
A: "做 A、B、C 三个模块，可以并行，每个模块按完整流水线"。

**Q: 想跳过 spec 直接生成代码？**
A: 说 "用 flutter-api-quick 一键生成，Swagger: {...}"。

**Q: 改的东西涉及核心文件（ApiClient 等）被 hook 拦截？**
A: 这是故意的，核心文件不该随意改。确有必要设置 `ALLOW_CORE_EDIT=1`。

**Q: 想让 Claude 只读 SKILL.md 模板不自己发挥？**
A: 在请求里加一句"必须先读 .claude/skills/flutter-xxx/SKILL.md 段 6 代码模板"。

---

## 推荐说话模板（复制粘贴）

### 完整功能开发
```
做 {模块名} 模块，走 flutter-flow-feature 流水线。

baseUrl: {xxx}
响应格式: {code: int, data: any, msg: string}
分页: page + page_size
字段: snake_case

Swagger:
{贴 JSON}
```

### 单模块快速生成
```
快速生成 {模块名} 的接口和 model，用 flutter-api-quick。
Swagger: {...}
```

### 质量检查
```
评审一下 lib/features/{模块}/ 的代码，走 flutter-flow-review 流水线。
```

### 加新功能到现有模块
```
给 {模块} 加一个 {页面/接口}，按项目规范。
```
