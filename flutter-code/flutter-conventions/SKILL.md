---
name: flutter-conventions
description: 用于本项目 Flutter 基础规范，包括命名、注释、import 排序和目录组织。触发场景：用户说"新建功能模块"、"检查命名规范"或项目初始化时。
---

# 基础规范（flutter-conventions）

## 概述

为本项目（Flutter + GetX）定义统一的基础编码规范，涵盖命名、注释、import 排序和目录结构，确保团队代码风格一致。

## 命名规则

### 文件与目录

全部使用 **snake_case**，文件名后缀体现内容类型：

| 类型 | 文件名示例 |
|------|-----------|
| 页面/视图 | `login_view.dart` |
| 控制器 | `login_controller.dart` |
| 数据模型 | `user_model.dart` |
| 绑定 | `login_binding.dart` |
| 组件 | `custom_button.dart` |
| 服务 | `auth_service.dart` |
| 工具类 | `date_util.dart` |
| 常量 | `app_colors.dart` |

### 类名

使用 **PascalCase**，后缀反映类型：

```dart
class LoginView extends GetView<LoginController> {}
class LoginController extends GetxController {}
class UserModel {}
class LoginBinding extends Bindings {}
class AuthService extends GetxService {}
```

### 变量与方法

- 使用 **camelCase**
- 私有成员加下划线前缀：`_privateField`
- GetX 响应式变量用 `.obs` / `Rxn<T>` 声明：

```dart
final count = 0.obs;
final userInfo = Rxn<UserModel>();
final isLoading = false.obs;
final list = <UserModel>[].obs;
```

### 常量

- 应用级常量放 `common/constants/`，字段名使用 **camelCase**，以 `k` 开头：

```dart
const kDefaultPadding = 16.0;
const kApiTimeout = 30; // seconds
```

- 颜色/字体等 Theme Token 放 `common/theme/`，用静态常量：

```dart
class AppColors {
  static const primary = Color(0xFF1A73E8);
  static const background = Color(0xFFF5F5F5);
}
```

## 注释规范

### 文档注释（`///`）

用于**公开的类、方法、属性**，必须写：

```dart
/// 用户登录控制器
///
/// 负责处理登录表单验证、接口调用和页面跳转逻辑。
class LoginController extends GetxController {

  /// 执行用户登录
  ///
  /// [username] 用户名
  /// [password] 密码（明文，加密在 service 层处理）
  Future<void> login(String username, String password) async {}
}
```

### 行内注释（`//`）

用于**解释非显而易见的逻辑**，描述"为什么"而非"做什么"：

```dart
// 延迟 300ms 等待键盘收起，避免路由动画卡顿
await Future.delayed(const Duration(milliseconds: 300));
```

### 禁止

- 不写无意义注释：`// 设置用户名` 紧跟在 `username = name` 后
- 不留注释掉的废代码，直接删除

## Import 排序

按以下顺序分组，组与组之间空一行：

```dart
// 1. Dart SDK
import 'dart:async';
import 'dart:io';

// 2. Flutter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 3. 第三方包
import 'package:get/get.dart';
import 'package:dio/dio.dart';

// 4. 项目内部（绝对路径）
import 'package:your_app/common/theme/app_colors.dart';
import 'package:your_app/features/login/controllers/login_controller.dart';
```

> 推荐使用 VS Code Dart 插件的 **Organize Imports** 自动排序（`⌥ + Shift + O`）。

## 目录结构规范

```
lib/
├── features/                    # 功能模块（每个模块独立）
│   └── [feature_name]/
│       ├── views/               # 页面及页面级子 Widget
│       │   └── widgets/         # 本页面专属组件（可选）
│       ├── controllers/         # GetxController
│       ├── models/              # 数据模型（仅本模块使用）
│       └── bindings/            # GetX Binding
├── common/
│   ├── widgets/                 # 全局复用组件
│   ├── services/                # 全局 GetxService
│   ├── utils/                   # 工具函数
│   ├── theme/                   # 颜色、字体、间距 Token
│   └── constants/               # 全局常量
├── api/
│   ├── http_client.dart         # Dio 单例封装
│   ├── interceptors/            # 拦截器
│   └── repositories/            # 各模块 Repository
└── routes/
    ├── app_pages.dart           # 路由页面表
    └── app_routes.dart          # 路由名称常量
```

**规则：**
- 模块内的 model / widget 不放 `common/`，除非确认被多个模块复用
- 禁止跨模块直接 import 对方的 controller，跨模块通信通过 `GetxService` 实现
- 每个功能模块目录对应一个独立业务功能，不拆散到多个目录

## 完成后联动

> "基础规范确认后，可使用 `flutter-architecture` skill 设计具体功能模块的 GetX 分层结构。"
