---
name: flutter-env-config
description: 管理多环境配置(dev/staging/prod)。生成 dart-define 配置 + 环境切换脚本。用户说"加环境配置"、"切换到测试环境"、"配置 prod"时触发。
type: skill
stage: 3
model: sonnet
priority: P2
version: 1.0.0
owner: @lead
category: generator
---

# 环境配置 (flutter-env-config)

## 1. 触发场景

- "配置多环境" / "加 staging 环境"
- "prod 的 baseUrl 是什么"
- "切换到测试环境"
- "env 配置"
- 项目初始化后配置环境

**反例:**
- "改 ApiClient" → 手动
- "改 mock 开关" → dart-define USE_MOCK

## 2. 前置必读

- `lib/core/config/` (现有配置文件)
- `docs/_context/decisions.md` (环境策略)
- `scripts/run.sh` (现有启动脚本)

## 3. 输入

**必填:**
- `action` — init (初始化多环境) / add (加一个环境) / switch (切换)
- `env_name` — dev / staging / prod / custom

**可选:**
- `base_url` — 该环境的 API 地址
- `features` — 该环境开启的 feature flag

## 4. 工作流程

**Step 1 — 读现有配置**

**Step 2 — 生成/修改环境配置**

生成 `lib/core/config/env_config.dart`:
```dart
enum Env { dev, staging, prod }

class EnvConfig {
  static Env current = Env.dev;

  static String get baseUrl => switch (current) {
    Env.dev => 'https://dev-api.example.com/api',
    Env.staging => 'https://staging-api.example.com/api',
    Env.prod => 'https://api.example.com/api',
  };

  static bool get useMock => const bool.fromEnvironment('USE_MOCK');
  static String get envName => const String.fromEnvironment('ENV', defaultValue: 'dev');

  static void init() {
    current = Env.values.firstWhere(
      (e) => e.name == envName,
      orElse: () => Env.dev,
    );
  }
}
```

**Step 3 — 生成启动脚本**

```bash
# scripts/run_dev.sh
flutter run --dart-define=ENV=dev --dart-define=USE_MOCK=true -d chrome

# scripts/run_staging.sh
flutter run --dart-define=ENV=staging --dart-define=USE_MOCK=false -d chrome

# scripts/run_prod.sh
flutter run --dart-define=ENV=prod --dart-define=USE_MOCK=false -d chrome
```

**Step 4 — 自检**

## 5. 输出产物

```
lib/core/config/env_config.dart    — 环境配置类
scripts/run_{env}.sh               — 各环境启动脚本
```

## 6. 代码模板

见 Step 2 和 Step 3。

## 7. 不做什么 (Boundary)

- ❌ 不存储敏感信息到代码中 (API key 等用环境变量)
- ❌ 不改 ApiClient 核心逻辑
- ❌ 不改 firebase/push 配置 (那是专项)
- ❌ 不生成 .env 文件 (Flutter 用 dart-define,不用 dotenv)
- ❌ 不自动 commit

## 8. 自检 Checklist

- [ ] EnvConfig 类有所有环境
- [ ] baseUrl 不带尾部 `/`
- [ ] `fromEnvironment` 有 defaultValue
- [ ] 启动脚本可执行 (`chmod +x`)
- [ ] main.dart 调用了 `EnvConfig.init()`

## 9. 失败处理

**ASK_USER:** 缺少某环境的 baseUrl
**STOP:** lib/core/config/ 不存在

## 10. 联动

**上游:** flutter-init (项目初始化后)
**下游:** flutter-release (打包时指定环境)
