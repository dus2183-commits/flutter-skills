# {{PROJECT_NAME_PASCAL}}

这是一个用 flutter-skills 工作流初始化的 Flutter 项目。

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

### 必须
- ✅ 网络请求走 ApiClient (`Get.find<ApiClient>()`)
- ✅ Repository 用 GetxService
- ✅ 页面用 GetView<Controller>
- ✅ DI 在 binding 注册
- ✅ 异常 catch AppException
- ✅ 列表用 ListView.builder + const

### 禁止
- ❌ 直接 `import 'dart:io'` (用 cross_file XFile)
- ❌ 直接 `new Dio()` (用 ApiClient)
- ❌ 硬编码中文字符串 (用 .tr)
- ❌ 在 build 内 Get.find
- ❌ throw String

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
