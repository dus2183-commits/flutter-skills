# 技术栈

> 本文件定义本项目的技术选型。任何代码生成都必须遵守。
> 修改本文件需经组长同意,并在 `decisions.md` 追加一条 ADR。
>
> **此文件是 flutter-init 创建,在 docs/_context/ 下。所有 SKILL.md 必读。**

---

## 核心栈

### Flutter / Dart
- Flutter SDK: 3.24.x (stable channel)
- Dart: 3.5.x
- Flutter 版本管理: fvm (.fvmrc)

### 状态管理 + 路由 + DI
- **GetX 4.6.x** — 一个包搞定状态、路由、DI、snackbar、dialog、i18n
- 不使用 Riverpod / Bloc / Provider / go_router

### 网络
- **dio 5.x** + 自封装 ApiClient (lib/core/network/api_client.dart)
- 必须走 ApiClient,**禁止业务代码 new Dio()**
- 6 个拦截器: log / auth / sign / encrypt / mock / error
- web 端不可设代理

### JSON 序列化
- **freezed 2.x** + **json_serializable 6.x**
- 不可变模型,自动 copyWith / ==
- 必须 `dart run build_runner build` 生成

### 加密
- **encrypt 5.x** (基于 pointycastle,API 友好)
- **crypto 3.x** (HMAC / SHA / MD5)
- **archive 4.x** (GZIP,web 兼容)
- 接口加密: AES-CBC-256 + HMAC-SHA256 动态 key + GZIP 压缩 + 随机 IV
- 图片加密: AES-ECB (URL 后缀 `.bnc` 标识)
- Web 端用 asmcrypto.min.js (dart 端 AES 在 web 性能差)

### 本地存储
- **flutter_secure_storage 9.x** (敏感数据,移动端 keychain/keystore)
- **get_storage 2.x** (普通数据,三端兼容)
- ⚠️ web 端 secure_storage 落到 localStorage,**不要存敏感数据**

### 国际化
- GetX 自带 `Translations`
- key 命名: snake_case
- 文件按模块分: lib/app/locales/{lang}/{module}.dart

### 图片
- **自实现 NetworkImage** (lib/core/media/network_image/) — 支持加密图片 + 三端
- 后缀 `.bnc` 自动走解密路径
- io 端用 dart:io HttpClient + 文件缓存
- web 端通过 JS interop 调 fetchImage + IndexedDB 缓存

### 视频
- **video_player 2.10.x** + **chewie**(可选)
- **video_player_web 2.4.x** + **video_player_web_hls 1.3.x** (web HLS 支持)
- 自实现 PlayerAdapter (io / web 双实现)
- ⚠️ web HLS 必须额外测试

### 配置
- **flutter_dotenv 6.x** + .env.dev / .env.prod
- AppConfig (lib/core/config/app_config.dart) 包装 dotenv 读取
- 三端三套 API key (web/ios/android)

### 文件操作
- **cross_file 0.3.x** (XFile,三端兼容)
- **path_provider 2.x** (web 自动降级 IndexedDB)
- ⚠️ **禁止直接 import 'dart:io'**

### Lint
- **very_good_analysis 6.x** (严格的 lint 集)
- analysis_options.yaml 配置

### 测试
- **flutter_test** + **mocktail 1.x** (不需要代码生成)

### 其他依赖
- uuid (requestId 生成)
- url_launcher (打开外部链接)
- device_info_plus (设备信息)
- package_info_plus (apk 信息)

---

## 目录约定

```
lib/
├── main.dart                       入口
├── app/                            ← 应用层
│   ├── app.dart                    根 GetMaterialApp
│   ├── routes/                     路由表
│   │   ├── app_routes.dart         路由名常量
│   │   └── app_pages.dart          GetPage 列表 + binding
│   ├── theme/                      主题
│   │   ├── app_theme.dart          ThemeData 组装
│   │   ├── colors.dart             AppColors.xxx
│   │   ├── text_styles.dart        AppTextStyles.xxx
│   │   └── spacings.dart           kSpacingXxx
│   ├── locales/                    国际化
│   │   ├── translations.dart       AppTranslations
│   │   ├── zh_cn/
│   │   └── en_us/
│   └── bindings/                   全局 binding
│       └── initial_binding.dart
├── core/                           ← 基础库 (不依赖 features)
│   ├── config/                     配置 (dotenv 包装)
│   ├── network/                    网络层
│   │   ├── api_client.dart
│   │   ├── interceptors/
│   │   └── models/
│   ├── crypto/                     加密
│   ├── error/                      异常体系
│   ├── mock/                       Mock 加载器
│   ├── media/                      图片/视频
│   ├── storage/                    存储 (条件导出)
│   ├── platform/                   平台工具
│   └── utils/                      工具
├── features/                       ← 业务模块
│   └── {module}/
│       ├── data/
│       │   ├── models/             freezed 实体
│       │   └── repositories/       Repository
│       ├── domain/                 (可选,如有 use case)
│       └── presentation/
│           ├── pages/              页面三件套 (page+controller+binding)
│           └── widgets/            模块内组件
└── shared/
    ├── widgets/                    全局公共组件 (AppText, AppButton...)
    └── constants/                  全局常量
```

---

## 命名约定

| 类型 | 规则 | 示例 |
|---|---|---|
| 文件名 | snake_case | `announce_list_page.dart` |
| Class | PascalCase | `AnnounceListPage` |
| 私有 | _camelCase | `_isLoading` |
| 常量 | 顶层 kCamelCase | `kPrimaryColor` |
| 路由名 | kebab-case | `/announce-list` |
| Mock 文件 | `mock/{module}/{api}.json` | `mock/announce/list.json` |
| 国际化 key | snake_case | `announce.list_title` |

---

## 三端兼容铁律 (强制)

1. **禁止直接 `import 'dart:io'`** — 用 cross_file XFile,或写条件导出
2. **禁止 `new File()`** — 用 cross_file XFile
3. **路由参数禁止传非可序列化对象** — 用 query string 或 storage 中转
4. **视频不可依赖 HLS** — web 端必须 fallback 或测试
5. **camera/blue/nfc 必须 platform 判断** — web 端提示"暂不支持"
6. **CI 必须三端编译** — `flutter build apk && flutter build ios --no-codesign && flutter build web`
7. **web 端 secure_storage 不存敏感数据** — 落到 localStorage,不安全

---

## 包替换决策表

| 用途 | 选用 | 备选 | 原因 |
|---|---|---|---|
| 状态管理 | GetX | Riverpod | 团队熟悉 + 一站式 |
| 网络 | dio + 自封装 | retrofit | 拦截器灵活 + Mock 可控 |
| JSON | freezed | dart_mappable | 生态成熟 |
| 加密 | encrypt + asmcrypto.min.js (web) | pointycastle 直接用 | dart 端 web 性能差 |
| 图片 | 自实现 NetworkImage | cached_network_image | 加密图必须自实现 |
| 视频 | video_player + 适配器 | better_player | 三端覆盖 |
| 存储 | get_storage + secure_storage | hive | get_storage 三端 OK |
| 国际化 | GetX Translations | flutter_intl | 一站式 |
| 文件 | cross_file XFile | dart:io File | web 兼容 |
