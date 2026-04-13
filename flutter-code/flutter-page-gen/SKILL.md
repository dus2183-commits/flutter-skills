---
name: flutter-page-gen
description: |
  生成 GetX 三件套（View + Controller + Binding）。
  支持 4 种页面类型：列表/详情/表单/自定义。
  触发场景：用户说"生成一个公告列表页"、"做一个登录表单"、"生个 XX 详情页"。
type: skill
stage: 4
model: opus
priority: P1
version: 1.0.0
owner: @lead
category: generator
---

# 页面生成 (flutter-page-gen)

## 1. 触发场景
- "生成一个公告列表页"
- "做一个登录表单"
- "做 XX 的详情页"
- "生成用户信息页面"
- "做一个商品列表"

## 2. 前置必读
- `docs/_context/conventions.md`
- `docs/_context/tech-stack.md`
- `_governance/checklists/getx-usage.md`
- `flutter-init/template/lib/core/` (核心组件)
- `flutter-init/template/lib/app/` (路由配置)

## 3. 输入

**必填:**
- 页面需求描述（自然语言）：页面名称、类型、主要功能

**可选:**
- `type`: 列表 / 详情 / 表单 / 自定义（不指定则询问）
- `module`: 模块名（用于目录结构）
- `withBinding`: 是否生成 Binding（默认 true）

## 4. 工作流程

**Step 1 — 识别页面类型**

根据用户描述判断:
- 显示多条数据 + 分页？→ **列表型**
- 显示单条数据 + ID 参数？→ **详情型**
- 有输入框/表单提交？→ **表单型**
- 都不是或组合 → **自定义型**

**Step 2 — 确认信息**

与用户澄清:
- 页面路由名称
- 主要数据模型
- 关键交互（下拉刷新/搜索/筛选等）

**Step 3 — 生成三件套**

根据类型生成:
1. `{module}_{type}_page.dart` (View)
2. `{module}_{type}_controller.dart` (Controller)
3. `{module}_{type}_binding.dart` (Binding)

详见下方各种类型的模板。

**Step 4 — 生成路由配置**

生成需要添加到 `app/routes/app_pages.dart` 和 `app/routes/app_routes.dart` 的代码片段。

**Step 5 — 提示目录结构**

告诉用户把文件放到哪里。

## 5. 输出产物

生成 3 个 .dart 文件 + 路由配置代码片段。

**目录结构:**
```
lib/features/{module}/presentation/pages/{page_type}/
├── {module}_{page_type}_page.dart        # View
├── {module}_{page_type}_controller.dart  # Controller
└── {module}_{page_type}_binding.dart     # Binding
```

## 6. 模板示例

### 类型 1: 列表型页面（下拉刷新 + 上拉加载 + 分页）

```dart
// lib/features/announcement/presentation/pages/announcement_list/announcement_list_page.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'announcement_list_controller.dart';
import 'announcement_list_binding.dart';

class AnnouncementListPage extends GetView<AnnouncementListController> {
  const AnnouncementListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('公告列表'),
        centerTitle: true,
      ),
      body: Obx(() {
        // 加载态
        if (controller.isLoading.value && controller.announcements.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        // 错误态
        if (controller.hasError.value && controller.announcements.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('加载失败'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: controller.reload,
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        // 空态
        if (controller.announcements.isEmpty) {
          return const Center(
            child: Text('暂无公告'),
          );
        }

        // 正常态：列表
        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView.builder(
            itemCount: controller.announcements.length +
                (controller.isLoadingMore.value ? 1 : 0),
            itemBuilder: (context, index) {
              // 加载更多的 loading 指示
              if (index == controller.announcements.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final announcement = controller.announcements[index];
              return _announcementCard(announcement);
            },
            onEndReached: () => controller.loadMore(),
          ),
        );
      }),
    );
  }

  Widget _announcementCard(dynamic announcement) {
    return GestureDetector(
      onTap: () => Get.toNamed(
        '/announcement-detail',
        arguments: {'id': announcement.id},
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 分类标签 + 标题
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A73E8).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      announcement.category,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1A73E8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      announcement.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 发布时间
              Text(
                announcement.createdAt.toString().split('.')[0],
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// lib/features/announcement/presentation/pages/announcement_list/announcement_list_controller.dart

import 'package:get/get.dart';

class AnnouncementListController extends GetxController {
  // 数据
  final announcements = <dynamic>[].obs;

  // 状态
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final hasError = false.obs;
  final errorMessage = ''.obs;

  // 分页
  int _currentPage = 0;
  static const int _pageSize = 20;

  @override
  void onInit() {
    super.onInit();
    _loadAnnouncements();
  }

  /// 初始加载
  Future<void> _loadAnnouncements() async {
    isLoading.value = true;
    hasError.value = false;
    _currentPage = 0;

    try {
      // 调用 Repository 获取数据
      // announcements.value = await repository.getAnnouncements(
      //   skip: 0,
      //   limit: _pageSize,
      // );
      announcements.value = []; // 示例：用空列表代替
    } catch (e) {
      hasError.value = true;
      errorMessage.value = '加载失败: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// 下拉刷新
  Future<void> refresh() async {
    _currentPage = 0;
    await _loadAnnouncements();
  }

  /// 上拉加载更多
  Future<void> loadMore() async {
    if (isLoadingMore.value) return;

    isLoadingMore.value = true;
    try {
      _currentPage++;
      // 调用 Repository 获取下一页
      // final newData = await repository.getAnnouncements(
      //   skip: _currentPage * _pageSize,
      //   limit: _pageSize,
      // );
      // announcements.addAll(newData);
    } catch (e) {
      _currentPage--; // 失败则回退
      hasError.value = true;
    } finally {
      isLoadingMore.value = false;
    }
  }

  /// 重试
  Future<void> reload() async {
    await _loadAnnouncements();
  }

  @override
  void onClose() {
    super.onClose();
    // 释放资源（如 Timer、StreamSubscription 等）
  }
}

// ─────────────────────────────────────────
// lib/features/announcement/presentation/pages/announcement_list/announcement_list_binding.dart

import 'package:get/get.dart';
import 'announcement_list_controller.dart';

class AnnouncementListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => AnnouncementListController());
  }
}
```

**注册到路由 (app_pages.dart 和 app_routes.dart):**

```dart
// lib/app/routes/app_routes.dart
abstract class AppRoutes {
  static const String announcementList = '/announcement-list';
  static const String announcementDetail = '/announcement-detail';
}

// lib/app/routes/app_pages.dart
final appPages = [
  // ... 其他页面 ...
  GetPage(
    name: AppRoutes.announcementList,
    page: () => const AnnouncementListPage(),
    binding: AnnouncementListBinding(),
  ),
  GetPage(
    name: AppRoutes.announcementDetail,
    page: () => const AnnouncementDetailPage(),
    binding: AnnouncementDetailBinding(),
  ),
];
```

---

### 类型 2: 详情型页面（接收 ID 参数，加载单条数据）

```dart
// lib/features/announcement/presentation/pages/announcement_detail/announcement_detail_page.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'announcement_detail_controller.dart';
import 'announcement_detail_binding.dart';

class AnnouncementDetailPage extends GetView<AnnouncementDetailController> {
  const AnnouncementDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('公告详情'),
        centerTitle: true,
      ),
      body: Obx(() {
        // 加载态
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        // 错误态
        if (controller.hasError.value) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('加载失败'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: controller.reload,
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        // 正常态
        final announcement = controller.announcement.value;
        if (announcement == null) {
          return const Center(child: Text('无数据'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Text(
                announcement.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // 元信息：分类、时间
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A73E8).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      announcement.category,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1A73E8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    announcement.createdAt.toString().split('.')[0],
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 关键内容：正文
              Text(
                announcement.content,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────
// lib/features/announcement/presentation/pages/announcement_detail/announcement_detail_controller.dart

import 'package:get/get.dart';

class AnnouncementDetailController extends GetxController {
  // 参数
  late String announcementId;

  // 数据
  final announcement = Rxn<dynamic>();

  // 状态
  final isLoading = false.obs;
  final hasError = false.obs;
  final errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    announcementId = Get.arguments['id'] ?? '';
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    isLoading.value = true;
    hasError.value = false;

    try {
      // announcement.value = await repository.getAnnouncementDetail(announcementId);
      announcement.value = null; // 示例
    } catch (e) {
      hasError.value = true;
      errorMessage.value = '加载失败: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> reload() async {
    await _loadDetail();
  }

  @override
  void onClose() {
    super.onClose();
  }
}

// ─────────────────────────────────────────
// lib/features/announcement/presentation/pages/announcement_detail/announcement_detail_binding.dart

import 'package:get/get.dart';
import 'announcement_detail_controller.dart';

class AnnouncementDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => AnnouncementDetailController());
  }
}
```

---

### 类型 3: 表单型页面（用户输入 + 提交）

```dart
// lib/features/auth/presentation/pages/login/login_page.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'login_controller.dart';
import 'login_binding.dart';

class LoginPage extends GetView<LoginController> {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题
            const Text(
              '欢迎登录',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),

            // 用户名输入
            TextField(
              controller: controller.usernameEditor,
              decoration: InputDecoration(
                labelText: '用户名',
                hintText: '请输入用户名',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 密码输入
            Obx(() => TextField(
              controller: controller.passwordEditor,
              obscureText: controller.isPasswordVisible.isFalse,
              decoration: InputDecoration(
                labelText: '密码',
                hintText: '请输入密码',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    controller.isPasswordVisible.value
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: controller.togglePasswordVisibility,
                ),
              ),
            )),
            const SizedBox(height: 24),

            // 登录按钮
            Obx(() => ElevatedButton(
              onPressed: controller.isLoading.value ? null : controller.login,
              child: controller.isLoading.value
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('登录'),
            )),

            // 错误提示
            Obx(() => controller.hasError.value
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      controller.errorMessage.value,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// lib/features/auth/presentation/pages/login/login_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LoginController extends GetxController {
  final usernameEditor = TextEditingController();
  final passwordEditor = TextEditingController();

  final isPasswordVisible = false.obs;
  final isLoading = false.obs;
  final hasError = false.obs;
  final errorMessage = ''.obs;

  void togglePasswordVisibility() {
    isPasswordVisible.toggle();
  }

  Future<void> login() async {
    // 验证
    if (usernameEditor.text.isEmpty || passwordEditor.text.isEmpty) {
      hasError.value = true;
      errorMessage.value = '用户名或密码不能为空';
      return;
    }

    isLoading.value = true;
    hasError.value = false;

    try {
      // 调用登录接口
      // await authService.login(
      //   username: usernameEditor.text,
      //   password: passwordEditor.text,
      // );
      // Get.offAllNamed(AppRoutes.home);
    } catch (e) {
      hasError.value = true;
      errorMessage.value = '登录失败: $e';
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    usernameEditor.dispose();
    passwordEditor.dispose();
    super.onClose();
  }
}

// ─────────────────────────────────────────
// lib/features/auth/presentation/pages/login/login_binding.dart

import 'package:get/get.dart';
import 'login_controller.dart';

class LoginBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => LoginController());
  }
}
```

---

### 类型 4: 自定义型页面（用户完全自主定义）

对自定义型页面，提供一个**最小骨架**，用户自行扩展：

```dart
// lib/features/{module}/presentation/pages/{page_name}/{page_name}_page.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '{page_name}_controller.dart';
import '{page_name}_binding.dart';

class {PageName}Page extends GetView<{PageName}Controller> {
  const {PageName}Page({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('{页面标题}'),
        centerTitle: true,
      ),
      body: Center(
        child: Obx(() {
          // TODO: 实现你的 UI
          return const Text('待实现');
        }),
      ),
    );
  }
}

// lib/features/{module}/presentation/pages/{page_name}/{page_name}_controller.dart

import 'package:get/get.dart';

class {PageName}Controller extends GetxController {
  // TODO: 添加你的状态变量
  
  @override
  void onInit() {
    super.onInit();
    // TODO: 初始化逻辑
  }

  @override
  void onClose() {
    super.onClose();
    // TODO: 释放资源
  }
}

// lib/features/{module}/presentation/pages/{page_name}/{page_name}_binding.dart

import 'package:get/get.dart';
import '{page_name}_controller.dart';

class {PageName}Binding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => {PageName}Controller());
  }
}
```

## 7. 不做什么

- ❌ 不生成 Model 或 Repository (博龙的事)
- ❌ 不生成接口调用代码 (需要用户自己在 Repository 中实现)
- ❌ 不修改已有文件 (只生成新文件)
- ❌ 不自动注册路由 (给出代码片段，用户手动添加)
- ❌ 不自动 commit

## 8. 自检 Checklist

- [ ] 生成了 View + Controller + Binding 三个文件
- [ ] View 继承 `GetView<T>`
- [ ] Controller 继承 `GetxController`
- [ ] 所有状态变量使用 `.obs` / `Rxn<T>` / `RxList<T>`
- [ ] Binding 使用 `Get.lazyPut`
- [ ] 包含 loading / error / empty 三态处理
- [ ] 页面使用 `AppText` / `AppButton` 等项目组件
- [ ] `onClose()` 中正确释放资源 (TextEditingController / StreamSubscription 等)
- [ ] 给出了路由注册代码片段

## 9. 失败处理

**页面类型不确定时:**
> ASK_USER "这个页面是 (列表型) / (详情型) / (表单型) / (自定义)？"

**缺少必要信息时:**
> "需要补充以下信息才能生成代码:
> - 主数据模型名称
> - 是否需要分页
> - 关键交互有哪些"

## 10. 联动

**成功后:**
> "✅ 页面代码已生成。
> - 文件: lib/features/{module}/presentation/pages/{page}/
> - 路由: 需要添加到 app_pages.dart 和 app_routes.dart
> - 下一步: 
>   1. 确认文件位置和内容
>   2. 用 `flutter-review` 检查代码规范
>   3. 在 Repository 中实现接口调用"

**上游:**
- flutter-spec (需求文档)
- flutter-api-doc (接口文档)

**下游:**
- flutter-review (代码评审)
- flutter-lint-fix (代码格式化)
