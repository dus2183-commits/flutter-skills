# {{PROJECT_NAME_PASCAL}}

由 flutter-skills 初始化的 Flutter 项目。

## 🔒 锁定环境

本项目锁定 **Flutter 3.27.2** (通过 fvm)。
团队任何人 clone 后跑一行 setup 即可获得相同环境。

---

## 🚀 第一次运行 (Setup)

```bash
bash scripts/setup.sh
```

这一步会自动:
1. 装 fvm (如果没装)
2. 下载 Flutter 3.27.2 到 `.fvm/flutter_sdk`(首次约 5-10 分钟)
3. 跑 `flutter pub get`
4. 跑 `build_runner` 生成 freezed 代码

完成后,你的项目就跟团队完全一致了。

---

## 启动

```bash
# Mock 模式 (推荐开发用,跳过真实接口)
bash scripts/run.sh
# 或显式:
fvm flutter run --dart-define=USE_MOCK=true

# 真实接口模式
bash scripts/run.sh --no-mock
# 或:
fvm flutter run

# 指定设备
bash scripts/run.sh -d chrome
```

---

## 三端编译验证

```bash
# 三端全跑
bash scripts/build_check.sh

# 单端
bash scripts/build_check.sh android
bash scripts/build_check.sh ios
bash scripts/build_check.sh web
```

---

## 清理

```bash
# 清 build/ + .dart_tool
bash scripts/clean.sh

# 全清(含 fvm 软链接和 pubspec.lock)
bash scripts/clean.sh --all
```

---

## 编辑器配置

### VS Code
已自动配置好(`.vscode/settings.json`)。
**重启 VS Code 即可** — Dart SDK 自动指向 `.fvm/flutter_sdk`。

### Android Studio / IntelliJ
1. Settings → Languages → Flutter
2. **Flutter SDK path:** 选择 `<项目目录>/.fvm/flutter_sdk`
3. Apply

### Cursor / 其他
跟 VS Code 一样,读 `.vscode/settings.json`。

---

## 项目结构

```
{{PROJECT_NAME}}/
├── .fvmrc                    锁定 Flutter 3.27.2
├── .vscode/settings.json     编辑器配置
├── .env.dev / .env.prod      环境变量
├── scripts/                  setup/run/build/clean
├── lib/
│   ├── main.dart
│   ├── app/                  应用层 (路由/主题/i18n)
│   ├── core/                 基础库 (网络/加密/Mock/媒体)
│   ├── features/             业务模块 (5 个 Tab)
│   └── shared/               公共组件
├── mock/                     mock 数据
├── docs/_context/            AI 协作上下文
├── web/js/                   加密 JS (web 端)
└── CLAUDE.md                 AI 协作必读
```

---

## 文档

- [CLAUDE.md](./CLAUDE.md) — **AI 协作必读**
- [tech-stack](./docs/_context/tech-stack.md) — 技术栈
- [conventions](./docs/_context/conventions.md) — 编码规范
- [decisions](./docs/_context/decisions.md) — 决策记录
- [glossary](./docs/_context/glossary.md) — 术语表

---

## 故障排查

### `setup.sh` 失败 — fvm 装不上
```bash
# 手动装 fvm
brew tap leoafarias/fvm && brew install fvm
# 或
dart pub global activate fvm
```

### `fvm install 3.27.2` 卡住
首次下载需要 5-10 分钟,网络慢的话用代理:
```bash
export https_proxy=http://127.0.0.1:7890
bash scripts/setup.sh
```

### Android Studio 找不到 SDK
确认你装的不是 Android Studio 的 Flutter 插件 bundled SDK。
手动配 SDK Path 为 `<项目>/.fvm/flutter_sdk`。

### `dart_tool` / 编辑器报错
```bash
bash scripts/clean.sh
bash scripts/setup.sh
```
