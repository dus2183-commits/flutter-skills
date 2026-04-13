---
name: flutter-module
description: 用于本项目 Flutter 功能模块的 GetX 分层架构设计，包括 Controller、Binding、Route 和 Service 的标准写法。触发场景：用户说"新建 XX 功能模块"、"设计 XX 页面架构"。
---

# GetX 分层架构（flutter-module）

## 概述

为本项目（Flutter + GetX）的功能模块定义标准分层结构，输出 Controller、Binding、Route、View 和 Service 的标准模板，确保模块间结构一致。

## 前置信息确认

开始前询问：
- 模块名称（英文，如 `login`、`home`、`profile`）
- 是否需要独立 Service（跨模块共享逻辑时才需要）
- 页面数量（单页 / 多页，多页时需设计子路由）

## 标准模块结构

```
lib/features/[module]/
├── views/
│   ├── [module]_view.dart          # 主页面
│   └── widgets/                    # 页面专属组件（可选）
├── controllers/
│   └── [module]_controller.dart    # 业务逻辑
├── models/
│   └── [module]_model.dart         # 数据模型
└── bindings/
    └── [module]_binding.dart       # 依赖注入
```

## 输出内容

### 1. Controller（controllers/[module]_controller.dart）

```dart
import 'package:get/get.dart';
import 'package:your_app/api/repositories/[module]_repository.dart';
import '../models/[module]_model.dart';

class [Module]Controller extends GetxController {
  final _repository = Get.find<[Module]Repository>();

  // 状态变量
  final isLoading = false.obs;
  final data = Rxn<[Module]Model>();
  final list = <[Module]Model>[].obs;

  @override
  void onInit() {
    super.onInit();
    // 初始化逻辑，如加载首屏数据
    fetchData();
  }

  @override
  void onReady() {
    super.onReady();
    // 页面首帧渲染完成后触发，适合做弹窗、新手引导等
  }

  @override
  void onClose() {
    // 释放资源：TextEditingController、StreamSubscription、Timer 等
    super.onClose();
  }

  Future<void> fetchData() async {
    isLoading.value = true;
    try {
      data.value = await _repository.fetchDetail();
    } on DioException catch (e) {
      debugPrint('[Module] fetchData error: $e');
    } finally {
      isLoading.value = false;
    }
  }
}
```

**规则：**
- Controller 只做业务逻辑，不直接调用 `Dio`，通过 Repository 获取数据
- 响应式变量统一用 `.obs` / `Rxn<T>()` / `RxList<T>` 声明在类顶部
- 资源释放必须在 `onClose()` 中处理，避免内存泄漏
- 不在 Controller 中直接操作 UI（如 `showDialog`），通过回调或 Service 解耦

### 2. Binding（bindings/[module]_binding.dart）

```dart
import 'package:get/get.dart';
import 'package:your_app/api/repositories/[module]_repository.dart';
import '../controllers/[module]_controller.dart';

class [Module]Binding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<[Module]Repository>(() => [Module]Repository());
    Get.lazyPut<[Module]Controller>(() => [Module]Controller());
  }
}
```

**规则：**
- 统一使用 `Get.lazyPut`（按需实例化），页面未打开时不占用内存
- Repository 在 Binding 中注册，Controller 通过 `Get.find<T>()` 获取
- 全局单例 Service 在 `main.dart` 中用 `Get.putAsync` 初始化，不在 Binding 中重复注册

### 3. Route 注册

```dart
// routes/app_routes.dart — 路由名称常量
abstract class AppRoutes {
  static const login = '/login';
  static const home = '/home';
  static const [module] = '/[module]';
}

// routes/app_pages.dart — 路由页面表
import 'package:get/get.dart';
import 'package:your_app/features/[module]/bindings/[module]_binding.dart';
import 'package:your_app/features/[module]/views/[module]_view.dart';

class AppPages {
  static final pages = [
    GetPage(
      name: AppRoutes.[module],
      page: () => const [Module]View(),
      binding: [Module]Binding(),
    ),
  ];
}
```

**规则：**
- 路由名称统一在 `AppRoutes` 中定义为常量，禁止在业务代码中硬编码字符串
- 每个页面必须绑定对应的 `Binding`
- 路由跳转统一使用：
  - `Get.toNamed(AppRoutes.xxx)` — 跳转并保留栈
  - `Get.offNamed(AppRoutes.xxx)` — 替换当前页
  - `Get.offAllNamed(AppRoutes.xxx)` — 清空栈后跳转（如退出登录回首页）

### 4. View（views/[module]_view.dart）

```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/[module]_controller.dart';

class [Module]View extends GetView<[Module]Controller> {
  const [Module]View({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('[Module]')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildContent();
      }),
    );
  }

  Widget _buildContent() {
    return const SizedBox.shrink(); // 替换为实际内容
  }
}
```

**规则：**
- 页面继承 `GetView<T>`，自动获取 `controller` 实例，无需手动 `Get.find`
- `Obx` 只包裹需要响应的最小范围，不整个 `build` 都套 `Obx`
- 复杂页面拆分为私有方法（`_buildHeader`、`_buildList`）或独立 Widget 文件
- 纯展示区域用 `const`，避免不必要重建

### 5. 全局 Service（common/services/[name]_service.dart）

跨模块共享状态或逻辑时使用：

```dart
import 'package:get/get.dart';
import 'package:your_app/routes/app_routes.dart';

/// 全局用户认证 Service
///
/// 在 main.dart 中通过 Get.putAsync 初始化，生命周期与 App 相同。
class AuthService extends GetxService {
  final isLoggedIn = false.obs;
  final currentUser = Rxn<UserModel>();
  String? token;

  Future<AuthService> init() async {
    // 读取本地持久化的登录态（如 SharedPreferences）
    return this;
  }

  void logout() {
    isLoggedIn.value = false;
    currentUser.value = null;
    token = null;
    Get.offAllNamed(AppRoutes.login);
  }
}

// main.dart 中注册（App 启动时）
await Get.putAsync<AuthService>(() => AuthService().init());
```

**规则：**
- `GetxService` 生命周期与 App 相同，不因页面销毁而释放
- 跨模块读取：`Get.find<AuthService>().currentUser.value`
- 不要用 Service 代替 Controller 处理单页面业务逻辑

## 完成后联动

> "模块架构设计完成。可使用 `flutter-widget` skill 设计该模块的组件拆分方案，或使用 `flutter-api` skill 设计对应的数据层。"
