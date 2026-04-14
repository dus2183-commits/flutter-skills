# 编码规范

> 本文件定义编码规范。所有代码必须遵守。
> 修改需经组长同意。

---

## 1. 注释规范

### 1.1 Public API 必须有 doc 注释

```dart
/// 用户登录服务。
///
/// 调用示例:
/// ```dart
/// final user = await authService.login(phone, code);
/// ```
class AuthService { }
```

### 1.2 复杂逻辑用单行注释解释 why,不解释 what

```dart
// ✅ 解释为什么
// 业务方要求第一次失败时静默重试一次,避免用户看到瞬时网络抖动
if (retryCount == 0 && err is NetworkException) {
  return retry();
}

// ❌ 解释做了什么 (代码已经说明了)
// 把 page+1
page++;
```

### 1.3 TODO 必须带人名和日期

```dart
// TODO(zhangsan, 2026-04-15): 接入新的支付接口
```

### 1.4 不要写过期注释

宁愿不写,也不要写错的。

---

## 2. Widget 拆分阈值

**强制拆分条件(任一满足):**
- `build` 方法超过 **80 行**
- 嵌套超过 **5 层**
- 一个文件超过 **300 行**
- 同一个 Widget 在多处用了 **2 次以上**

**拆分后命名:**
- 拆出的 Widget 用 PascalCase
- 私有 Widget 加 `_` 前缀放同文件下方
- 复用 Widget 单独文件,放 `lib/shared/widgets/` 或 `features/{m}/presentation/widgets/`

---

## 3. GetX 使用规范

### 3.1 Controller
- **必须**继承 `GetxController`,不用 `ChangeNotifier`
- 响应式变量用 `.obs`,不混用 `setState`
- 一个页面一个 Controller(复杂页面可拆多个)

```dart
class AnnounceListController extends GetxController {
  final list = <Announce>[].obs;
  final loading = false.obs;
  final error = Rxn<AppException>();
  
  @override
  void onInit() {
    super.onInit();
    loadData();
  }
  
  Future<void> loadData() async { ... }
}
```

### 3.2 View
- **必须**用 `GetView<Controller>`,不用 `StatelessWidget`
- 响应式 UI 用 `Obx(() => ...)`
- 不在 `build` 方法里 `Get.find`

```dart
class AnnounceListPage extends GetView<AnnounceListController> {
  const AnnounceListPage({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() {
        if (controller.loading.value) return const AppLoading();
        return ListView.builder(...);
      }),
    );
  }
}
```

### 3.3 DI
- **必须**在 `binding` 文件中 `Get.put` / `Get.lazyPut`
- **禁止**在 controller / view 里散落注册

```dart
class AnnounceListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => AnnounceListController(
      repo: Get.find<AnnounceRepository>(),
    ));
  }
}
```

### 3.4 路由
- **必须**用 `Get.toNamed('/route')`,不用 `Navigator.push`
- 路由名定义在 `app/routes/app_routes.dart`
- 路由表注册在 `app/routes/app_pages.dart`

---

## 4. 网络请求规范

### 4.1 必须走 ApiClient
```dart
// ✅ 正确
class AnnounceRepository extends GetxService {
  final ApiClient _api = Get.find();
  Future<Announce> getDetail(String id) async {
    return await _api.get<Announce>(
      path: '/api/announce/detail',
      query: {'id': id},
      mockKey: 'announce/detail',
      fromJson: Announce.fromJson,
    );
  }
}

// ❌ 错误
final dio = Dio();  // 禁止
final resp = await dio.get('/api/announce/detail');
```

### 4.2 必须传 cancelToken
- 在 controller 里持有 `CancelToken`
- 页面 `onClose` 时 `cancelToken.cancel()`

### 4.3 错误必须 catch AppException
```dart
try {
  await api.postJson(...);
} on CancelException {
  // 静默
} on AuthException {
  Get.toNamed('/login');
} on AppException catch (e) {
  Get.snackbar('提示', e.userMessage);
}
```

**禁止 `catch (e) { print(e); }`**

---

## 5. 列表性能

- **必须**用 `ListView.builder` / Sliver,**禁止**`ListView(children:)`
- 不变 widget **必须** `const` 修饰
- 图片**必须**用 `AppNetworkImage`(封装了 cache + placeholder + error)
- 列表 item 必须有 `key`(避免 rebuild 错乱)

---

## 6. 错误处理

- 所有可能失败的 async **必须** try-catch
- 业务错误抛 `BusinessException`
- 网络错误抛 `NetworkException`
- UI 层只 catch `AppException` 基类
- **禁止** `throw '错误信息字符串'`

---

## 7. 国际化

- **禁止**硬编码中文字符串
- 用 `'announce.title'.tr` 取文案
- key 命名: `{module}.{key}` snake_case
- 临时占位用 `// i18n: TODO` 标记

---

## 8. 多平台兼容(强制)

### 8.1 禁止直接 import 'dart:io'
任何用到 File / Directory / Platform 的代码必须放在条件导入文件中。
违反会导致 web 编译失败。

### 8.2 所有 core/ 库必须三端可用
core 层不允许出现 platform-specific 代码。
需要分流的能力放 `core/{cap}/io.dart` 和 `core/{cap}/web.dart`,然后用条件导出:
```dart
// storage.dart
export 'storage_io.dart' if (dart.library.html) 'storage_web.dart';
```

### 8.3 图片必须给 fallback
`AppImage` 必须处理 web CORS 问题,提供 `errorWidget`。

### 8.4 路由必须支持 web URL
GetX 路由不允许用纯参数传递大对象,必须用 query string 或 storage 中转,
否则 web 刷新页面会崩。

### 8.5 媒体限制
- 视频: 上线前 web 端必须实测;HLS 不支持
- 相机: web 端用 image_picker 降级
- 蓝牙/NFC: 必须 platform 检查,web 提示"暂不支持"

### 8.6 字体大小
web 默认字号会被浏览器影响,必须用 MediaQuery + textScaleFactor 做归一化。

### 8.7 滚动手势
web 端鼠标滚轮和移动端手势行为不一样,长列表必须测试。

### 8.8 CI 必须三端编译
PR 必须 pass: `flutter build apk`, `flutter build ios --no-codesign`, `flutter build web`

---

## 9. 提交规范

```
feat:     新功能
fix:      bug 修复
refactor: 重构
docs:     文档
test:     测试
chore:    杂项 (依赖升级 / 配置)
style:    格式 (不影响代码逻辑)
perf:     性能优化
```

示例:
```
feat(announce): add list page with pull-to-refresh
fix(network): cancel token not propagated in upload
refactor(crypto): split aes_util to dynamic and static
```

---

## 10. 文件组织

### 10.1 import 顺序

```dart
// 1. dart:
import 'dart:async';
import 'dart:convert';

// 2. flutter:
import 'package:flutter/material.dart';

// 3. 第三方包:
import 'package:get/get.dart';
import 'package:dio/dio.dart' show CancelToken;

// 4. 项目内 (绝对路径):
import 'package:app/core/network/api_client.dart';
import 'package:app/features/announce/data/models/announce.model.dart';

// 5. 相对路径 (同 feature 内):
import '../models/announce.model.dart';
```

### 10.2 一个文件一个 public class
私有 class 可以同文件,public class 必须独立文件。

---

## 11. 资源文件命名规范

### 11.1 图片命名（强制）

**格式：** `{前缀}_{模块}_{名称}.{扩展名}`

| 前缀 | 用途 | 例 |
|------|------|-----|
| `ic_` | 图标（Icon） | `ic_home_bell.png` / `ic_common_arrow_right.svg` |
| `bg_` | 背景图 | `bg_login.png` / `bg_home_banner.jpg` |
| `btn_` | 按钮图片 | `btn_primary_pressed.png` |
| `img_` | 插图/大图 | `img_empty_list.png` |
| `avatar_` | 头像 | `avatar_default.png` |
| `logo_` | Logo | `logo_app.png` / `logo_brand.svg` |

**规则：**
- **全小写**，下划线分隔
- **禁止**驼峰 `iconHome.png` ❌
- **禁止**中文 `首页图标.png` ❌
- **禁止**空格/特殊字符
- 模块名和文件名用 snake_case

### 11.2 倍图目录

Flutter 标准约定（Flutter 自动按 `devicePixelRatio` 选倍数）：

```
assets/image/
├── {module}/              ← 1x 原图（可选）
│   └── ic_home.png
├── 2.0x/{module}/         ← 2x
│   └── ic_home.png
└── 3.0x/{module}/         ← 3x（推荐默认,一套覆盖所有设备）
    └── ic_home.png
```

**推荐策略：** 只导 3x（Flutter runtime 自动降级到 2x/1x 设备），省空间。

### 11.3 Figma 切图自动下载规则

`flutter-design-to-code` / `flutter-mcp` 自动下载 Figma 切图时,**必须**遵守：

1. 默认导 3x，保存到 `assets/image/3.0x/{module}/`
2. 文件名按 11.1 的前缀规则重命名（Figma 原名通常不合规）
3. 如 Figma 原名含中文，必须翻译或音译为英文
4. 更新 `pubspec.yaml` 的 `assets:` 段

### 11.4 pubspec.yaml 注册

```yaml
flutter:
  assets:
    - assets/image/common/       # 通用图片(不分模块)
    - assets/image/3.0x/common/  # 通用 3x
    - assets/image/3.0x/home/    # home 模块 3x
    - assets/image/3.0x/mine/    # mine 模块 3x
```
