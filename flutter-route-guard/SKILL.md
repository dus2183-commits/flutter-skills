---
name: flutter-route-guard
description: 生成路由拦截中间件(登录态检查/权限校验/深链接恢复)。用户说"加登录拦截"、"路由守卫"、"未登录跳登录页"时触发。基于 GetX middleware。
type: skill
stage: 4
model: sonnet
priority: P1
version: 1.0.0
owner: @lead
category: generator
---

# 路由守卫 (flutter-route-guard)

## 1. 触发场景

- "加登录拦截" / "未登录跳登录页"
- "某些页面需要权限"
- "路由守卫" / "route guard"
- "deep link 进来要检查登录态"

**反例:**
- "注册路由" → flutter-page-gen Step 4
- "生成登录页" → flutter-page-gen (form 型)

## 2. 前置必读

- `docs/_context/decisions.md` (鉴权方案)
- `lib/app/routes/app_pages.dart` (现有路由)
- `lib/core/storage/` (token 存储方式)

## 3. 输入

**必填:**
- `guard_type` — auth (登录态) / permission (权限) / custom
- `protected_routes` — 需要拦截的路由列表 (或 "all except login")

**可选:**
- `redirect_to` — 拦截后跳转目标 (默认 /login)

## 4. 工作流程

**Step 1 — 读 context**
确认鉴权方案 (JWT token / session)、token 存储位置。

**Step 2 — 生成 Middleware 类**
按段 6 模板生成 `GetMiddleware` 子类。

**Step 3 — 注册到路由**
在 `app_pages.dart` 的目标 `GetPage` 上加 `middlewares: [AuthMiddleware()]`。

**Step 4 — 自检**

## 5. 输出产物

```
lib/app/routes/middlewares/
├── auth_middleware.dart        — 登录态检查
└── permission_middleware.dart  — 权限检查 (如需)

修改:
- lib/app/routes/app_pages.dart (加 middlewares)
```

## 6. 代码模板

```dart
// lib/app/routes/middlewares/auth_middleware.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/storage/auth_storage.dart';
import '../app_routes.dart';

/// 登录态拦截中间件
///
/// 检查 token 是否存在,不存在则跳转登录页。
/// 用法: GetPage(middlewares: [AuthMiddleware()])
class AuthMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    final token = AuthStorage.getToken();
    if (token == null || token.isEmpty) {
      return const RouteSettings(name: Routes.login);
    }
    return null; // 放行
  }
}
```

**路由注册:**
```dart
GetPage<dynamic>(
  name: Routes.orderCreate,
  page: () => const OrderCreatePage(),
  bindings: [OrderRepositoryBinding(), OrderCreateBinding()],
  middlewares: [AuthMiddleware()],  // ← 加这一行
),
```

## 7. 不做什么 (Boundary)

- ❌ 不生成登录页面 (那是 page-gen 的事)
- ❌ 不实现 token 刷新逻辑
- ❌ 不改 ApiClient 拦截器
- ❌ 不处理 token 过期 (那是 AuthInterceptor 的事)
- ❌ 不自动 commit

## 8. 自检 Checklist

- [ ] Middleware 继承 `GetMiddleware`
- [ ] 有 `priority` getter
- [ ] redirect 返回 `RouteSettings` 或 null
- [ ] 目标路由已加 `middlewares: []`
- [ ] 登录页/公开页不加 middleware (避免死循环)
- [ ] `dart analyze` 0 errors

## 9. 失败处理

**ASK_USER:** 不确定哪些路由需要保护时
**STOP:** AuthStorage 不存在 (项目未初始化鉴权)
**ROLLBACK:** revert app_pages.dart 改动

## 10. 联动

**上游:** flutter-page-gen (生成需要保护的页面)
**下游:** flutter-review (检查所有敏感页面是否加了 guard)
