# {{PROJECT_NAME_PASCAL}}

这是一个用 flutter-skills 工作流初始化的 Flutter 项目。

## ⛔ 最高优先级规则

1. **做功能必须走流水线**：有依赖的步骤按顺序 spec → plan → api-design → model-gen → api-gen → page-gen，禁止跳步
2. **尽量并行加速**：多模块并行 + 无依赖步骤并行（api-design||theme-design, page-gen||widget-gen），有依赖的串行
3. **每步读 SKILL.md 模板**：生成代码前必须读对应 skill 的段 6 代码模板
4. **每步产出文件**：spec → docs/specs/{m}.md, model → .model.dart, repo → _repository.dart

## 项目记忆（跨 session 持久化）

如果存在,**每次打开必读** `.claude/memory/project.md` — 记录了之前 session 做了什么。
memory 由 memory hook 自动维护,不要手动改。

## AI 协作必读

任何 AI 操作前,请先读以下 4 个文件:
1. `docs/_context/tech-stack.md` — 技术栈
2. `docs/_context/conventions.md` — 编码规范
3. `docs/_context/decisions.md` — 决策记录 (ADR)
4. `docs/_context/glossary.md` — 项目术语

## 锁定环境(重要)
- Flutter: **3.27.2** (锁定,通过 .fvmrc + fvm)
- Dart: 3.6.1 (Flutter 3.27.2 自带)
- 启动命令: `fvm flutter run` (注意带 fvm 前缀)
- 第一次跑: `bash scripts/setup.sh`

## 技术栈速查
- 状态管理/路由/DI: **GetX 4.6.x**
- 网络: **dio + 自封装 ApiClient (lib/core/network/)**
- JSON: **freezed + json_serializable**
- 加密: **AES-CBC + 动态 key + GZIP** (lib/core/crypto/)
- 存储: **flutter_secure_storage** (敏感) + **get_storage** (普通)
- 三端: **Android + iOS + Web** (严格)

## 约定速查

## ★ 代码生成铁律（最重要）

**生成任何 Dart 代码前，必须先读对应的 SKILL.md 文件里的代码模板。**
不要凭自己的知识写代码，必须按 SKILL.md 段 6 的模板来。

skill 文件在 `~/.claude/skills/flutter-*/SKILL.md`。

### Model: 必须 freezed
- `@freezed` + `part .freezed.dart` + `part .g.dart` + `factory fromJson`
- snake_case 字段加 `@JsonKey(name: 'xxx')`
- 生成后跑 `fvm dart run build_runner build --delete-conflicting-outputs`

### Repository: 必须走 ApiClient
- 继承 `GetxService`，`final ApiClient _api = Get.find()`
- 每个方法传 `mockKey` + `CancelToken? cancelToken`
- path 不带 /api 前缀
- 不 import app_exception，不 catch 异常

### Binding: 用 tearoff
- `Get.lazyPut<Xxx>(Xxx.new, fenix: true)`（不用 lambda）

### 页面: GetView 三件套
- `{name}_page.dart` + `{name}_controller.dart` + `{name}_binding.dart`
- 路径: `lib/features/{module}/presentation/pages/{page_name}/`
- 列表用 EasyRefresh（不是 RefreshIndicator）
- loading/error/empty 三态必须处理

### 必须
- ✅ 网络请求走 ApiClient + mockKey + cancelToken
- ✅ Model 用 freezed + @JsonKey
- ✅ Repository 用 GetxService
- ✅ Binding 用 tearoff
- ✅ 页面用 GetView<Controller> + EasyRefresh
- ✅ 生成代码前读 SKILL.md 模板

### 禁止
- ❌ 手写 Model class（必须 freezed）
- ❌ 直接 `new Dio()`（用 ApiClient）
- ❌ Repository 内 catch 异常
- ❌ Binding 用 lambda
- ❌ path 带 /api 前缀
- ❌ Color.withOpacity（用 withValues）
- ❌ RefreshIndicator（用 EasyRefresh）
- ❌ 不看 SKILL.md 凭自己知识写代码

## 启动

```bash
# 第一次: 一键 setup
bash scripts/setup.sh

# Mock 模式 (用 mock 数据,适合开发)
fvm flutter run --dart-define=USE_MOCK=true
# 或: bash scripts/run.sh

# 真实接口模式
fvm flutter run
# 或: bash scripts/run.sh --no-mock
```

⚠️ 首次启动前,请先编辑 `.env.dev` 填入真实 API key。
⚠️ 所有 Flutter 命令都加 `fvm` 前缀,确保用项目锁定的 3.27.2 版本。

## 推荐工作流

```
1. flutter-flow-feature   做新功能
2. flutter-flow-design    从 Figma/截图生成代码
3. flutter-flow-review    评审
4. flutter-flow-release   发版
```

## 目录约定

```
lib/
├── main.dart                  入口
├── app/                       应用层 (路由/主题/i18n)
├── core/                      基础库 (网络/加密/Mock/媒体/配置/异常)
├── features/                  业务模块
│   ├── home/
│   ├── category/
│   ├── discover/
│   ├── message/
│   └── mine/
└── shared/                    公共组件
    └── widgets/
```

## 链接

- [tech-stack](./docs/_context/tech-stack.md)
- [conventions](./docs/_context/conventions.md)
- [decisions](./docs/_context/decisions.md)
- [glossary](./docs/_context/glossary.md)
