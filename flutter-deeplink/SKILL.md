---
name: flutter-deeplink
description: 生成深链接配置(Universal Links / App Links / Web URL)+ 路由映射。用户说"配置深链接"、"URL 直接打开页面"、"web 刷新不崩"时触发。
type: skill
stage: 5
model: sonnet
priority: P2
version: 1.0.0
owner: @lead
category: generator
---

# 深链接配置 (flutter-deeplink)

## 1. 触发场景

- "配置深链接" / "deep link"
- "URL 直接打开详情页"
- "分享链接能打开 App"
- "web 端刷新不白屏"
- spec 中有深链接需求时

**反例:**
- "注册路由" → flutter-page-gen Step 4
- "路由守卫" → flutter-route-guard

## 2. 前置必读

- `lib/app/routes/app_routes.dart` (现有路由)
- `lib/app/routes/app_pages.dart` (路由配置)
- `docs/_context/decisions.md` (域名、URL scheme)
- Android: `android/app/src/main/AndroidManifest.xml`
- iOS: `ios/Runner/Info.plist` + `ios/Runner/Runner.entitlements`

## 3. 输入

**必填:**
- `domain` — 深链接域名 (如 `example.com`)
- `routes` — 需要支持深链接的路由列表

**可选:**
- `scheme` — 自定义 URL scheme (如 `myapp://`)
- `platforms` — 需要配置的平台 (默认 android + ios + web)

## 4. 工作流程

**Step 1 — 读现有路由,确认哪些需要深链接**

**Step 2 — 生成路由映射表**

```
https://example.com/announce/list    → Routes.announceList
https://example.com/announce/{id}    → Routes.announceDetail (参数: id)
myapp://announce/{id}                → Routes.announceDetail
```

**Step 3 — 配置 Android (App Links)**

在 `AndroidManifest.xml` 加 intent-filter:
```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https" android:host="example.com" />
</intent-filter>
```

**Step 4 — 配置 iOS (Universal Links)**

在 `Runner.entitlements` 加:
```xml
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:example.com</string>
</array>
```

**Step 5 — 配置 Web (URL Strategy)**

确认 `main.dart` 使用 `setUrlStrategy(PathUrlStrategy())`:
```dart
import 'package:flutter_web_plugins/url_strategy.dart';

void main() {
  usePathUrlStrategy();
  runApp(const MyApp());
}
```

**Step 6 — 生成路由解析中间件**

处理深链接进来时的参数解析和页面跳转。

**Step 7 — 自检**

## 5. 输出产物

```
修改:
- android/app/src/main/AndroidManifest.xml (App Links)
- ios/Runner/Runner.entitlements (Universal Links)
- lib/main.dart (URL strategy)

新增:
- lib/app/routes/deeplink_handler.dart (路由映射)
- docs/deeplink-config.md (配置说明文档)
```

## 6. 代码模板

```dart
// lib/app/routes/deeplink_handler.dart
import 'package:get/get.dart';

import 'app_routes.dart';

/// 深链接路由映射
///
/// 将外部 URL 映射到内部路由。
/// GetX 的路由参数自动从 URL 解析,所以大部分情况不需要额外处理。
///
/// 需要特殊处理的场景:
/// 1. URL 参数名和路由参数名不一致
/// 2. 需要登录才能访问的深链接 (配合 AuthMiddleware)
/// 3. 需要预加载数据的深链接
class DeeplinkHandler {
  /// 外部 URL path → 内部路由 path
  ///
  /// GetX 已自动处理 /announce/:id 这种参数路由,
  /// 这里只处理需要转换的非标准映射。
  static final Map<RegExp, String> customMappings = {
    // 例: /article/123 → /announce/123 (路径名不同)
    // RegExp(r'^/article/(.+)$'): '/announce/\$1',
  };

  /// 检查深链接是否需要登录
  static bool requiresAuth(String path) {
    const publicPaths = ['/login', '/register', '/about'];
    return !publicPaths.any((p) => path.startsWith(p));
  }
}
```

## 7. 不做什么 (Boundary)

- ❌ 不配置服务端 (apple-app-site-association / assetlinks.json 需后端部署)
- ❌ 不处理推送跳转 (那是推送 SDK 的事)
- ❌ 不修改路由注册 (page-gen 的事)
- ❌ 不生成分享功能
- ❌ 不自动 commit

## 8. 自检 Checklist

- [ ] AndroidManifest.xml 有 intent-filter
- [ ] iOS entitlements 有 applinks
- [ ] web 使用 PathUrlStrategy
- [ ] 所有需要深链接的路由都能通过 URL 访问
- [ ] 参数路由 (/:id) 能正确解析
- [ ] 配置说明文档已生成

## 9. 失败处理

**ASK_USER:** 域名未确定
**STOP:** 路由文件不存在 (项目未初始化)
**ROLLBACK:** revert native 配置文件改动

## 10. 联动

**上游:** flutter-page-gen (注册路由)
**下游:** flutter-route-guard (深链接进来也要检查登录态)
