---
name: flutter-page-gen
description: 生成页面三件套 (View + Controller + Binding)。用户说"生成 XX 页面"、"做列表页"、"做详情页"或 api-gen 完成后触发。GetX 风格,自动 loading/error/empty 三态,用 AppText/AppImage 等公共组件,注册路由。
type: skill
stage: 4
model: sonnet
priority: P0
version: 1.0.0
owner: @c
category: generator
---

# 页面生成 (flutter-page-gen)

> ⚠️ **张和锋的样板 v1** — 渡先实现 2 种页面类型 (列表 / 详情),**你需要扩展另外 2 种**

---

## 1. 触发场景

- "生成 XX 列表页"
- "生成 XX 详情页"
- "做一个 XX 页面"
- "做表单页 / 自定义页"
- api-gen 完成后 workflow 自动触发

---

## 2. 前置必读

- `docs/_context/conventions.md` (GetX 使用规范)
- `docs/specs/{module}.md` (页面 ID + 描述)
- `docs/plans/{module}.md` (页面任务清单)
- `lib/features/{module}/data/repositories/*.dart` (上游 repository)
- `lib/features/{module}/data/models/*.dart` (上游 model)
- `lib/shared/widgets/` (查看公共组件)
- `lib/app/theme/` (查看主题定义)
- `lib/app/routes/app_routes.dart` (路由名约定)
- `_governance/checklists/getx-usage.md` (GetX 红线)

---

## 3. 输入

**必填:**
- `page_name` (string, snake_case) — 如 `announce_list`
- `module_name` (string) — 如 `announce`
- `page_type` (enum) — 4 选 1:
  - **`list`** — 列表型(支持下拉刷新 + 上拉加载)
  - **`detail`** — 详情型(接收 id 参数,加载单条)
  - **`form`** — 表单型(TextField + 校验 + 提交)
  - **`custom`** — 自定义型(空模板)

**可选:**
- `repository` (string) — 关联的 Repository 类名,默认从 module_name 推断

---

## 4. 工作流程

### Step 1 — 读上下文 + spec + repository
- 必须确认 `lib/features/{m}/data/repositories/{m}_repository.dart` 已存在
- 不存在 → STOP,提示先跑 api-gen

### Step 2 — 确认页面类型
若 page_type 没指定,从 spec 第 2 段(涉及页面)推断:
- 描述含"列表 / 浏览 / 查看所有" → list
- 描述含"详情 / 单条 / 信息" → detail
- 描述含"提交 / 编辑 / 表单" → form
- 其他 → ASK_USER

### Step 3 — 生成三件套 (按 page_type 套模板)
- `{page_name}_page.dart` — View
- `{page_name}_controller.dart` — GetxController
- `{page_name}_binding.dart` — DI binding

### Step 4 — 自动注册路由 ★ 关键步骤

**必须做这一步**,否则生成的页面不能跳转。

**⚠️ 高频错误警告:**
- ❌ **跳过 Step 4.3 直接做 4.4** — 你会先想到改 app_pages.dart 加 GetPage,但忘了 app_routes.dart 加常量。结果 `Routes.xxx` 报 undefined_getter。
- ❌ **只改了 1 个文件** — 必须改 2 个: `app_routes.dart` (加常量) + `app_pages.dart` (加 GetPage)
- ❌ **多次 Edit 漏了 Read** — 用 Edit 工具改文件前必须先 Read。

**正确顺序: 4.3 必须在 4.4 之前做**(常量先存在,GetPage 才能引用它)。

#### 4.1 推断路由名(snake_case → camelCase, route 路径 → kebab-case)

| page_name | page_type | 路由常量名 | 路由路径 |
|---|---|---|---|
| announce_list | list | `Routes.announceList` | `/announce-list` |
| announce_detail | detail | `Routes.announceDetail` | `/announce/:id` |
| user_profile | detail | `Routes.userProfile` | `/user/:id` |
| order_create | form | `Routes.orderCreate` | `/order-create` |
| order_edit | form | `Routes.orderEdit` | `/order/:id/edit` |

**规则:**
- list 型 → `/{module}-list` (一般直接用)
- detail 型 → `/{module}/:id` (含路径参数)
- form 型 → `/{module}-create` 或 `/{module}/:id/edit`
- custom 型 → ASK_USER 让用户决定

#### 4.2 检查 lib/app/routes/app_routes.dart 是否已有同名路由

```bash
grep "{routeName}" lib/app/routes/app_routes.dart
```
- 如有 → ASK_USER (是否覆盖)
- 如无 → 继续

#### 4.3 修改 lib/app/routes/app_routes.dart

在 `Routes` 类中加新常量,放在 `// ─── 业务页面 ───` 注释下方:

```dart
abstract class Routes {
  Routes._();

  /// 主壳(底部 Tab 容器)
  static const home = '/';

  // ─── 业务页面 ───
  static const announceList = '/announce-list';      // ← 新增
  static const announceDetail = '/announce/:id';     // ← 新增
}
```

#### 4.4 修改 lib/app/routes/app_pages.dart

加入 import 和 GetPage 注册:

```dart
import '../../features/{module}/data/repositories/{module}_repository.binding.dart';
import '../../features/{module}/presentation/pages/{page_name}/{page_name}_binding.dart';
import '../../features/{module}/presentation/pages/{page_name}/{page_name}_page.dart';
```

在 `routes` 数组里加 GetPage:

```dart
GetPage<dynamic>(
  name: Routes.announceList,
  page: () => const AnnounceListPage(),
  bindings: [AnnounceRepositoryBinding(), AnnounceListBinding()],
),
```

**关键:**
- ⚠️ **`bindings: []`** (复数,数组),不是 `binding:` (单数)
- ⚠️ **第一个 binding 是 Repository,第二个是 Page Controller** — 顺序很重要,Controller 依赖 Repository
- ⚠️ Repository 用 `fenix: true` (在 binding 内,跨页面持久化)
- ⚠️ 如果同一个 Repository 已被前面的页面注册,可以省略;但保险起见**重复声明**(GetX 自动 dedupe)
- ⚠️ `GetPage<dynamic>` 显式泛型(不写会触发 strict_raw_type lint)

#### 4.5 验证

```bash
# 1. dart analyze 应 0 issues
fvm flutter analyze --no-pub

# 2. grep 应找到新路由
grep -n "{routeName}" lib/app/routes/app_routes.dart
grep -n "GetPage<dynamic>(" lib/app/routes/app_pages.dart
```

### Step 5 — 生成 i18n key 占位
在 `lib/app/locales/zh_cn/{module}.dart` 加 key (留 TODO 让后续填充)。

### Step 6 — 自检 (跑段 8 checklist)

### Step 7 — 联动
建议下一步用 `flutter-review` 评审,或运行 `bash scripts/run.sh` 看效果。

---

## 5. 输出产物

```
lib/features/{module}/presentation/pages/{page_name}/
├── {page_name}_page.dart          View (GetView<Controller>)
├── {page_name}_controller.dart    GetxController
└── {page_name}_binding.dart       DI binding

修改的文件:
- lib/app/routes/app_routes.dart   (加路由名常量)
- lib/app/routes/app_pages.dart    (加 GetPage 注册)
- lib/app/locales/zh_cn/{module}.dart  (加 i18n key 占位)
```

---

## 6. 代码模板

### 6.1 列表型 (page_type=list) — v1 已写

**`announce_list_page.dart`:**
```dart
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../shared/widgets/app_empty_view.dart';
import '../../../../../shared/widgets/app_error_view.dart';
import '../../../../../shared/widgets/app_loading.dart';
import 'announce_list_controller.dart';

class AnnounceListPage extends GetView<AnnounceListController> {
  const AnnounceListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('公告')),
      body: Obx(() {
        // loading 三态
        if (controller.loading.value && controller.list.isEmpty) {
          return const AppLoading();
        }
        if (controller.error.value != null) {
          return AppErrorView(
            error: controller.error.value!,
            onRetry: controller.refresh,
          );
        }
        if (controller.list.isEmpty) {
          return const AppEmptyView(message: '暂无公告');
        }

        // 主内容: EasyRefresh 提供下拉刷新 + 上拉加载更多 (替代 RefreshIndicator)
        return EasyRefresh(
          // 中文文案的下拉 header
          header: const ClassicHeader(
            dragText: '下拉刷新',
            armedText: '释放刷新',
            readyText: '刷新中...',
            processingText: '刷新中...',
            processedText: '刷新成功',
            noMoreText: '没有更多了',
            failedText: '刷新失败',
            messageText: '最近更新 %T',
          ),
          // 中文文案的上拉 footer
          footer: const ClassicFooter(
            dragText: '上拉加载',
            armedText: '释放加载',
            readyText: '加载中...',
            processingText: '加载中...',
            processedText: '加载完成',
            noMoreText: '没有更多了',
            failedText: '加载失败',
            messageText: '最近更新 %T',
          ),
          onRefresh: () async {
            await controller.refresh();
          },
          onLoad: () async {
            if (!controller.hasMore.value) {
              return IndicatorResult.noMore;
            }
            await controller.loadMore();
            return controller.hasMore.value
                ? IndicatorResult.success
                : IndicatorResult.noMore;
          },
          child: ListView.builder(
            itemCount: controller.list.length,
            itemBuilder: (context, index) {
              final item = controller.list[index];
              return ListTile(
                title: Text(item.title),
                subtitle: Text(item.summary ?? ''),
                trailing: item.isRead
                    ? null
                    : const Icon(
                        Icons.fiber_manual_record,
                        color: Colors.red,
                        size: 12,
                      ),
                onTap: () => controller.openDetail(item.id),
              );
            },
          ),
        );
      }),
    );
  }
}
```

**注意:** 列表型 `_page.dart` 顶部必须 `import 'package:easy_refresh/easy_refresh.dart';`。

**`announce_list_controller.dart`:**
```dart
import 'package:dio/dio.dart' show CancelToken;
import 'package:get/get.dart';

import '../../../../../core/error/app_exception.dart';
import '../../../../../core/network/models/page_req.dart';
import '../../../data/models/announce.model.dart';
import '../../../data/repositories/announce_repository.dart';

class AnnounceListController extends GetxController {
  AnnounceListController({required this.repo});

  final AnnounceRepository repo;
  final _cancelToken = CancelToken();

  // 响应式状态
  final list = <Announce>[].obs;
  final loading = false.obs;
  final error = Rxn<AppException>();
  final hasMore = true.obs;
  int _page = 1;

  @override
  void onInit() {
    super.onInit();
    refresh();
  }

  @override
  void onClose() {
    _cancelToken.cancel();
    super.onClose();
  }

  // ⚠️ 必须 @override (GetxController 有同名 refresh 方法)
  @override
  Future<void> refresh() async {
    loading.value = true;
    error.value = null;
    try {
      final resp = await repo.getList(
        pageReq: const PageReq(),
        cancelToken: _cancelToken,
      );
      list.assignAll(resp.list);
      hasMore.value = resp.hasMore;
      _page = 1;
    } on CancelException {
      // 静默
    } on AppException catch (e) {
      error.value = e;
    } finally {
      loading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (loading.value || !hasMore.value) return;
    loading.value = true;
    try {
      final resp = await repo.getList(
        pageReq: PageReq(page: _page + 1),
        cancelToken: _cancelToken,
      );
      list.addAll(resp.list);
      hasMore.value = resp.hasMore;
      _page++;
    } on CancelException {
      // 静默
    } on AppException catch (e) {
      error.value = e;
    } finally {
      loading.value = false;
    }
  }

  void openDetail(String id) {
    Get.toNamed('/announce/$id');
  }
}
```

**`announce_list_binding.dart`:**
```dart
import 'package:get/get.dart';

import '../../../data/repositories/announce_repository.dart';
import 'announce_list_controller.dart';

class AnnounceListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => AnnounceListController(repo: Get.find<AnnounceRepository>()),
    );
  }
}
```

### 6.2 详情型 (page_type=detail) — v1 已写

**`announce_detail_page.dart`:**
```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../shared/widgets/app_error_view.dart';
import '../../../../../shared/widgets/app_loading.dart';
import 'announce_detail_controller.dart';

class AnnounceDetailPage extends GetView<AnnounceDetailController> {
  const AnnounceDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('公告详情')),
      body: Obx(() {
        if (controller.loading.value) return const AppLoading();
        if (controller.error.value != null) {
          return AppErrorView(
            error: controller.error.value!,
            onRetry: controller.load,
          );
        }
        final data = controller.data.value;
        if (data == null) return const SizedBox();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                '${data.author ?? ''}  ·  ${data.publishAt}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              // 富文本 (实际项目用 flutter_html 渲染)
              Text(data.content ?? ''),
            ],
          ),
        );
      }),
    );
  }
}
```

**`announce_detail_controller.dart`:**
```dart
import 'dart:async';  // 用于 unawaited()

import 'package:dio/dio.dart' show CancelToken;
import 'package:get/get.dart';

import '../../../../../core/error/app_exception.dart';
import '../../../data/models/announce.model.dart';
import '../../../data/repositories/announce_repository.dart';

class AnnounceDetailController extends GetxController {
  AnnounceDetailController({required this.repo});

  final AnnounceRepository repo;
  final _cancelToken = CancelToken();

  // 路由参数
  String get id => Get.parameters['id'] ?? '';

  final data = Rxn<Announce>();
  final loading = false.obs;
  final error = Rxn<AppException>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    _cancelToken.cancel();
    super.onClose();
  }

  Future<void> load() async {
    loading.value = true;
    error.value = null;
    try {
      final resp = await repo.getDetail(id: id, cancelToken: _cancelToken);
      data.value = resp;
      // 自动标记已读 (fire-and-forget,失败不影响阅读)
      unawaited(_markRead());
    } on CancelException {
      // 静默
    } on AppException catch (e) {
      error.value = e;
    } finally {
      loading.value = false;
    }
  }

  Future<void> _markRead() async {
    try {
      await repo.markRead(id: id, cancelToken: _cancelToken);
    } on AppException {
      // 静默 — 标记失败不影响阅读
    }
  }
}
```

**`announce_detail_binding.dart`:**
```dart
import 'package:get/get.dart';

import '../../../data/repositories/announce_repository.dart';
import 'announce_detail_controller.dart';

class AnnounceDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => AnnounceDetailController(repo: Get.find<AnnounceRepository>()),
    );
  }
}
```

### 6.3 表单型 (page_type=form) — ⏳ v1 暂未实现 (张和锋扩展)

```dart
// TODO(张和锋, v1.1.0): 表单页模板
// 应该支持:
//   - 多个 TextField 字段
//   - 字段校验 (form_field_validator 或自实现)
//   - 提交 loading 状态
//   - 提交成功后跳转
```

### 6.4 自定义型 (page_type=custom) — ⏳ v1 暂未实现

```dart
// TODO(张和锋, v1.2.0): 空 scaffold 模板
// 给用户自由发挥
```

### 6.5 路由注册示例 ★

**修改前 `lib/app/routes/app_routes.dart`:**
```dart
abstract class Routes {
  Routes._();

  static const home = '/';
}
```

**修改后:**
```dart
abstract class Routes {
  Routes._();

  static const home = '/';

  // ─── announce 模块 ───
  static const announceList = '/announce-list';
  static const announceDetail = '/announce/:id';
}
```

**修改前 `lib/app/routes/app_pages.dart`:**
```dart
import 'package:get/get.dart';

import '../app.dart';
import 'app_routes.dart';

abstract class AppPages {
  AppPages._();

  static const initial = Routes.home;

  static final routes = <GetPage<dynamic>>[
    GetPage<dynamic>(
      name: Routes.home,
      page: () => const MainScaffold(),
    ),
  ];
}
```

**修改后(加 import + 加 GetPage):**
```dart
import 'package:get/get.dart';

import '../../features/announce/data/repositories/announce_repository.binding.dart';
import '../../features/announce/presentation/pages/announce_detail/announce_detail_binding.dart';
import '../../features/announce/presentation/pages/announce_detail/announce_detail_page.dart';
import '../../features/announce/presentation/pages/announce_list/announce_list_binding.dart';
import '../../features/announce/presentation/pages/announce_list/announce_list_page.dart';
import '../app.dart';
import 'app_routes.dart';

abstract class AppPages {
  AppPages._();

  static const initial = Routes.home;

  static final routes = <GetPage<dynamic>>[
    GetPage<dynamic>(
      name: Routes.home,
      page: () => const MainScaffold(),
    ),

    // ─── announce 模块 ───
    GetPage<dynamic>(
      name: Routes.announceList,
      page: () => const AnnounceListPage(),
      bindings: [AnnounceRepositoryBinding(), AnnounceListBinding()],
    ),
    GetPage<dynamic>(
      name: Routes.announceDetail,
      page: () => const AnnounceDetailPage(),
      bindings: [AnnounceRepositoryBinding(), AnnounceDetailBinding()],
    ),
  ];
}
```

**导航到这些路由的代码示例(给业务用):**
```dart
// 跳列表
Get.toNamed(Routes.announceList);

// 跳详情(传 id 参数)
Get.toNamed('/announce/65f7a8b9c1d2e3f4');

// 在 controller 内拿参数:
String get id => Get.parameters['id'] ?? '';
```

---

## 7. 不做什么

- ❌ 不用原生 `Text` / `Image` / `ElevatedButton` (用 AppText / AppImage / AppButton)
- ❌ 不用 `StatelessWidget` 没有 controller (用 GetView<Controller>)
- ❌ 不用 `setState` (用 .obs)
- ❌ 不在 build 内 `Get.find` (在 controller 字段)
- ❌ 不在 view 里散落 `Get.put` (在 binding)
- ❌ 不写业务逻辑(在 controller)
- ❌ 不直接调 ApiClient (调 Repository)
- ❌ 不修改 Repository 文件
- ❌ 不修改 model 文件
- ❌ 不删除已有 page

---

## 8. 自检 Checklist

**代码质量:**
- [ ] View 用 `GetView<Controller>`
- [ ] Controller 继承 `GetxController`
- [ ] Binding 文件存在
- [ ] 三态处理完整 (loading / error / empty)
- [ ] 列表用 `ListView.builder`
- [ ] static widget 用 `const`
- [ ] 响应式变量用 `.obs`
- [ ] CancelToken 在 onClose cancel
- [ ] 没有 `setState`
- [ ] 没有 `package:dio/dio.dart` 业务级 import
- [ ] **`refresh()` 方法加 `@override`** (GetxController 有同名方法,常忘)
- [ ] **fire-and-forget Future 用 `unawaited(...)`** (避免 unawaited_futures lint)
- [ ] **如用 `unawaited()` 必须 `import 'dart:async'`**
- [ ] **不要 `AppException(message: ...)`** — sealed class 不能 new,用 `UnknownException(message: ..., cause: e, stackTrace: s)`
- [ ] **不要 `Color.withOpacity()`** — 已 deprecated,改 `Color.withValues(alpha: 0.15)`
- [ ] **不要 `Transform.translate` 让头像浮在父容器外** — Transform 只移视觉,容器没变,会被相邻 widget 覆盖。**用 `Stack + clipBehavior: Clip.none + Positioned`**
- [ ] **catch (e) 兜底**:`} catch (e, s) { error.value = UnknownException(message: e.toString(), cause: e, stackTrace: s); }`,不要空 catch 吞异常

**路由注册 (Step 4):**
- [ ] **先改 app_routes.dart**(加常量,Step 4.3)
- [ ] **后改 app_pages.dart**(加 import + GetPage,Step 4.4)
- [ ] `Routes.{name}` 常量已加(grep 验证)
- [ ] `GetPage<dynamic>` 已加(grep 验证)
- [ ] **`bindings: []` 复数**,不是 `binding:` 单数
- [ ] **第一个 binding 是 Repository**(如有 Repository 依赖)
- [ ] **第二个 binding 是 Page Controller**
- [ ] `GetPage<dynamic>` 显式泛型(避免 strict_raw_type lint)
- [ ] 路由路径符合规范 (`/{module}-list` 或 `/{module}/:id`)
- [ ] 没有路由名冲突 (grep 验证)
- [ ] **跑 dart analyze 验证** — `Routes.xxx` 应能解析

**最终:**
- [ ] dart analyze 0 errors

---

## 9. 失败处理

**ASK_USER 时机:**
- repository 不存在 (要先 api-gen)
- spec 中没有这个 page 的描述
- page_type 推断不出
- 路由名冲突 (已存在同名)

**STOP 时机:**
- lib/features/{m}/data/repositories/ 不存在
- model 不存在

**ROLLBACK:**
- 自检失败时删除生成的三件套 + revert 路由文件改动

---

## 10. 联动

**成功后建议:**
> "页面生成完成: lib/features/{m}/presentation/pages/{page_name}/
>   - 三件套全
>   - 路由已注册: /announce-list, /announce/:id
>
> 跑 `bash scripts/run.sh` 看效果"

**上游:** flutter-api-gen
**下游:** flutter-review

---

## 11. 🚧 给张和锋: 扩展路线图

**v1 (渡已写) — 2 种页面类型 + 自动路由注册 + EasyRefresh,够开工:**
- ✅ **列表型** (list) — 完整模板,含三态/**下拉刷新+上拉加载更多 (EasyRefresh)**/cancelToken
- ✅ **详情型** (detail) — 完整模板,含路由参数解析/自动 markRead
- ✅ GetX 三件套 (View + Controller + Binding)
- ✅ **自动注册路由** ★ (Step 4) — 修改 app_routes.dart + app_pages.dart
- ✅ **多 binding 数组** — Repository + Controller 一起注入
- ✅ 用 AppText / AppLoading / AppEmptyView / AppErrorView
- ✅ **EasyRefresh + 中文文案** ★ (替代 RefreshIndicator,有下拉/上拉)
- ✅ catch AppException

**v2 (你必须加) — 这周做:**
- ⏳ **表单型** (form) — 多字段 + 校验 + 提交 (段 6.3 是 TODO)
- ⏳ **自定义型** (custom) — 空 scaffold 模板 (段 6.4 是 TODO)
- ⏳ **i18n 自动注入** — 把 hardcode 中文(如 "公告") 改成 `'announce.title'.tr`,同时在 locales/zh_cn/{m}.dart 加 key
- ⏳ **从 spec 自动推断 page_type** — Step 2 的推断逻辑要更智能

**v3 (可选高级) — 后续做:**
- 💡 **AppBar 自定义** — 大标题 / 可折叠 / 透明
- 💡 **骨架屏** (shimmer) — 替代 loading 转圈
- 💡 **Hero 动画** — 列表到详情的图片过渡
- 💡 **SliverScrollView 模板** — 复杂滚动场景
- 💡 **TabBar 嵌套** — 二级 tab 页面
- 💡 **空状态自定义图** — 不只是文字
- 💡 **Pull-to-refresh 自定义动画**
- 💡 **下滑隐藏 AppBar / BottomBar**
- 💡 **跨页面通信** — Get.arguments / GetBus / 全局 service
- 💡 **页面级权限** — 进入页面前检查登录态
- 💡 **页面级埋点** — onShow / onHide 自动上报
- 💡 **Route guard** — 拦截非法跳转

**完全不要做的:**
- ❌ 不要在 page-gen 里写业务逻辑(那是 controller 的事)
- ❌ 不要生成跨模块依赖的 page(每个 page 只属于一个 module)
- ❌ 不要支持 StatefulWidget 形式(项目锁定 GetX)
- ❌ 不要硬编码颜色/字号(用 theme)

---

## 给张和锋的具体提示

1. **v1 已能跑通公告列表 + 详情**,你接手后第一件事就是用它生成 announce 模块,看效果。

2. **v2 优先级:** 表单型 > i18n 自动注入 > 自定义型 > easy_refresh

3. **测试方法:**
   ```bash
   cd /tmp/flutter_skills_test
   bash scripts/run.sh -d chrome
   # 跳到 /announce-list 看列表是否正常
   # 点单条跳 /announce/:id 看详情是否正常
   ```

4. **最常见的坑:**
   - 在 `Obx` 外修改 `.value` (UI 不更新)
   - 列表 `ListView` 没用 `.builder`(性能差)
   - `Get.parameters['id']` 没处理 null
   - i18n 忘记加 key,显示 "announce.title" 字符串

5. **跟博龙对接:**
   - 你的 page-gen 依赖博龙的 api-gen
   - Repository 类名变了你要同步改 controller 的 import
   - 协调好 model 字段名(camelCase / snake_case)

6. **改完 SKILL.md 后:** version 字段递增

7. **注意你还有 6 个 SKILL.md 要写:** widget-gen / design-to-code / review / api-doc / theme-design / spec(已有样板)
