---
name: flutter-api-gen
description: 接口契约 → Repository 类(GetX 风格) + Mock JSON 数据。用户说"生成接口请求"、"生成 repository"或 model-gen 完成后触发。严格调用 ApiClient,自动 catch AppException,生成 GetX binding,产出可直接用的 data 层。
type: skill
stage: 4
model: sonnet
priority: P0
version: 1.0.0
owner: @b
category: generator
---

# 接口请求生成 (flutter-api-gen)

> ⚠️ **博龙的样板 v1** — 这是 ApiClient 接口的"使用层",**严格按 _design/api_client_signature.dart 生成代码**。

---

## 1. 触发场景

- "生成 XX 模块的 repository"
- "生成接口请求代码"
- "生成 api 调用"
- model-gen 完成后 workflow 自动触发

---

## 2. 前置必读

- `docs/_context/tech-stack.md`
- `docs/_context/conventions.md`
- `docs/api/{module}.md` ★ 必须 (上游契约)
- `lib/features/{module}/data/models/*.dart` ★ 必须 (上游 model)
- `_design/api_client_signature.dart` ★ **博龙的圣经,一定要读**
- `_design/app_exception.dart` (异常体系)

---

## 3. 输入

**必填:**
- `module_name` (string) — 与 docs/api/{module}.md 文件名一致

**自动从上游读:**
- 接口列表 (从 docs/api/{m}.md)
- mock keys (从 docs/api/{m}.md)
- model 类名 (从 lib/features/{m}/data/models/)
- 错误码段位 (从 docs/api/{m}.md)

---

## 4. 工作流程

### Step 1 — 读上下文 + 接口契约 + 已生成的 model
- 必须先确认 `lib/features/{m}/data/models/` 已存在 (否则 STOP,提示先跑 model-gen)

### Step 2 — 解析每个接口
对每个接口提取:
- HTTP 方法 (POST / GET / DELETE)
- 路径
- mock key
- 请求字段 (用什么 model)
- 响应字段 (用什么 model)
- 是否分页 (是否继承 PageReq/PageResp)

### Step 3 — 选择 ApiClient 方法
| 接口特征 | 用哪个 ApiClient 方法 |
|---|---|
| GET 单对象 | `api.get<T>()` |
| POST JSON 单对象 | `api.postJson<T>()` |
| POST Form 单对象 | `api.postForm<T>()` |
| 列表分页 | `api.getList<T>()` |
| DELETE | `api.delete<T>()` |
| 文件上传 | `api.upload()` |

⚠️ **不允许直接 `new Dio()` 或 import 'package:dio/dio.dart' 业务级**

### Step 4 — 生成 Repository 类
按段 6 模板,Repository:
- 继承 `GetxService`
- 字段: `final ApiClient _api = Get.find();`
- **每个接口一个方法**(契约里有几个接口,Repository 就要有几个方法 — 不要漏!)
- 方法签名包含 `CancelToken? cancelToken`
- 必须传 `mockKey` 参数
- 用 `fromJson` 转 model
- **path 不带 `/api` 前缀** ★(baseUrl 已含 apiPrefix)

### Step 5 — 生成 Binding
用于 GetX 路由注册时把 Repository 注入到 controller。
**Binding 用 tearoff:** `Get.lazyPut<XxxRepository>(XxxRepository.new, fenix: true);`

### Step 6 — 更新 pubspec.yaml 注册 mock 子目录 ★ 关键!

**Flutter assets 不递归子目录**,只声明 `mock/` 不包括 `mock/announce/`。
必须在 pubspec.yaml 的 assets 段加该模块的 mock 目录:

```yaml
flutter:
  assets:
    - mock/
    - mock/announce/   # ← 必须显式加这一行!
```

操作:
1. 读 pubspec.yaml
2. 找 `assets:` 段
3. 检查是否已有 `- mock/{module}/`,如无则加
4. 保持其他 assets 不变

**漏这一步的后果:**
```
Error while trying to load an asset: Flutter Web engine failed to fetch
"assets/mock/announce/list.json". HTTP request succeeded, but the server
responded with HTTP status 404.
```

### Step 7 — 检查 mock JSON 数据
读 `mock/{module}/*.json`,确保每个接口对应的文件存在且数据符合 model 字段。
**不存在或字段不符 → 标记 ⚠️ 警告(不阻断)**。

### Step 8 — 写入文件

### Step 9 — 自检 (跑段 8 checklist)

### Step 10 — 联动
建议下一步用 `flutter-page-gen` 生成页面。

---

## 5. 输出产物

```
lib/features/{module}/data/repositories/
├── {module}_repository.dart            主 Repository
└── {module}_repository.binding.dart    GetX binding
```

示例:
```
lib/features/announce/data/repositories/
├── announce_repository.dart
└── announce_repository.binding.dart
```

---

## 6. 代码模板 (v1 基础版)

### 6.1 Repository 类

```dart
import 'package:dio/dio.dart' show CancelToken;
import 'package:get/get.dart';

import 'package:swift/core/network/api_client.dart';
import 'package:swift/core/network/models/page_req.dart';
import 'package:swift/core/network/models/page_resp.dart';

import '../models/announce.model.dart';

// 注意: 不要 import app_exception.dart!Repository 不 catch 异常,
// 让 controller 上层 catch。引了不用会触发 unused_import lint。

/// 公告模块 Repository
///
/// 数据访问层,封装对 ApiClient 的调用。
/// 自动走加密 + Mock 拦截器,业务层不感知。
///
/// ⚠️ path 规则:**不要带 /api 前缀**
///   - ApiClient 的 baseUrl 已经是 `https://host.com/api`(含 apiPrefix)
///   - Repository 的 path 只写**业务部分** `/announce/list`
///   - 错误示例: `/api/announce/list` → 实际请求 `/api/api/announce/list` 404
class AnnounceRepository extends GetxService {
  final ApiClient _api = Get.find();

  /// 公告列表 (分页)
  Future<PageResp<Announce>> getList({
    required PageReq pageReq,
    CancelToken? cancelToken,
  }) async {
    return _api.getList<Announce>(
      path: '/announce/list',  // ⚠️ 不带 /api
      pageReq: pageReq,
      mockKey: 'announce/list',
      fromJson: (json) => Announce.fromJson(json as Map<String, dynamic>),
      cancelToken: cancelToken,
    );
  }

  /// 公告详情
  Future<Announce> getDetail({
    required String id,
    CancelToken? cancelToken,
  }) async {
    return _api.get<Announce>(
      path: '/announce/detail',  // ⚠️ 不带 /api
      query: {'id': id},
      mockKey: 'announce/detail',
      fromJson: (json) => Announce.fromJson(json as Map<String, dynamic>),
      cancelToken: cancelToken,
    );
  }

  /// 标记已读
  Future<void> markRead({
    required String id,
    CancelToken? cancelToken,
  }) async {
    await _api.postJson<void>(
      path: '/announce/markRead',  // ⚠️ 不带 /api
      data: {'id': id},
      mockKey: 'announce/markRead',
      fromJson: (_) {},
      cancelToken: cancelToken,
    );
  }
}
```

### 6.2 Binding

```dart
import 'package:get/get.dart';

import 'announce_repository.dart';

/// AnnounceRepository 注入 binding
///
/// 在路由配置中使用:
/// ```dart
/// GetPage(
///   name: Routes.announceList,
///   page: () => const AnnounceListPage(),
///   binding: AnnounceRepositoryBinding(),
/// )
/// ```
class AnnounceRepositoryBinding extends Bindings {
  @override
  void dependencies() {
    // 用 tearoff 而非 lambda (避免 unnecessary_lambdas lint)
    Get.lazyPut<AnnounceRepository>(AnnounceRepository.new, fenix: true);
  }
}
```

### 6.3 业务层调用示例(写在注释里给用户参考)

```dart
// 在 controller 或其他 service 中:
final repo = Get.find<AnnounceRepository>();

try {
  final resp = await repo.getList(pageReq: const PageReq());
  // 处理 resp.list / resp.total / resp.hasMore
} on CancelException {
  // 静默,不提示
} on AuthException {
  Get.toNamed('/login');
} on BusinessException catch (e) {
  Get.snackbar('提示', e.userMessage);
} on AppException catch (e) {
  Get.snackbar('错误', e.userMessage);
}
```

---

## 7. 不做什么

- ❌ **不直接 `new Dio()`** — 必须 `Get.find<ApiClient>()`
- ❌ **不直接 import `package:dio/dio.dart`** (除了 type re-export 如 `show CancelToken`)
- ❌ 不在 Repository 内 catch 异常 (让上层 catch)
- ❌ 不在 Repository 内调 `Get.snackbar` (那是 UI 的事)
- ❌ 不写业务逻辑 (Repository 只做数据访问,业务在 controller)
- ❌ 不修改 model 文件
- ❌ 不修改 lib/core/network/
- ❌ 不自动跑路由注册 (那是 page-gen 的事)
- ❌ 不直接读 .json 文件 (mock 是 ApiClient 内部的事)
- ❌ 不 throw String

---

## 8. 自检 Checklist

- [ ] **path 不带 `/api` 前缀** ★ (baseUrl 已含 apiPrefix,重复会 /api/api/)
- [ ] **必须更新 pubspec.yaml 注册 mock 子目录** ★ — 加 `- mock/{module}/`(Flutter assets 不递归)
- [ ] **必须生成完整方法**(spec 里的所有接口都要,不能漏 markRead 等)
- [ ] Repository extends GetxService
- [ ] 字段用 `final ApiClient _api = Get.find();`
- [ ] 每个方法都传 `mockKey` 参数
- [ ] 每个方法都传 `cancelToken` 参数
- [ ] 用了 `fromJson:` 而非 `as Map`
- [ ] 没有 try-catch (让上层处理)
- [ ] 没有直接 `new Dio()`
- [ ] 没有 `package:dio/dio.dart` 直接 import (除 type)
- [ ] **没有 import `app_exception.dart`** (Repository 不 catch,引了会触发 unused_import)
- [ ] **Binding 用 tearoff** (`AnnounceRepository.new` 而非 `() => AnnounceRepository()`)
- [ ] Binding 文件存在
- [ ] 路径正确: `lib/features/{m}/data/repositories/`
- [ ] 文件名 snake_case + `.dart` 后缀
- [ ] dart analyze 0 errors

---

## 9. 失败处理

**ASK_USER 时机:**
- model 不存在 (应该先跑 model-gen)
- 接口契约里有字段类型推断不出
- mock JSON 与 model 字段不匹配 (是否要修 mock?)

**STOP 时机:**
- docs/api/{m}.md 不存在
- lib/features/{m}/data/models/ 不存在
- ApiClient 接口签名变了 (检测 _design/api_client_signature.dart 变更)

**ROLLBACK:**
- 自检失败时删除生成的 .repository.dart 和 .binding.dart

---

## 10. 联动

**成功后建议:**
> "Repository 生成完成: lib/features/{m}/data/repositories/
>   - {N} 个方法
>   - GetX binding 已生成
>   - 用 mock 数据可立即跑通
>
> 下一步: 用 flutter-page-gen 生成页面"

**上游:** flutter-model-gen
**下游:** flutter-page-gen

---

## 11. 🚧 给博龙: 扩展路线图

**v1 (渡已写) — 基础够用:**
- ✅ 5 个 ApiClient 方法的封装 (get / postJson / postForm / getList / delete)
- ✅ Repository extends GetxService
- ✅ Binding 自动生成
- ✅ cancelToken 透传
- ✅ mockKey 自动注入
- ✅ fromJson 转 model

**v2 (你应该加) — 第二周做:**
- ⏳ **upload 方法封装** — 文件上传 (调 `api.upload()`,接收 XFile,带 onProgress)
- ⏳ **下载方法** — `api.download()` 调用
- ⏳ **多个 model 接口聚合** — 一个 Repository 里的方法跨多个 model
- ⏳ **接口分组** — 一个 Repository 太多方法时,自动拆成多个(`AnnounceListRepository` / `AnnounceDetailRepository`)
- ⏳ **错误码自动 import** — 从 docs/api/{m}.md 读出错误码列表,生成 enum 常量(避免硬编码 21001 这种 magic number)
- ⏳ **接口注释** — 从契约文档读"用途"字段,生成 `///` 注释
- ⏳ **必填字段强校验** — 在方法签名上加 `required` 关键字

**v3 (可选高级) — 后续迭代:**
- 💡 **Cache 层封装** — 默认 5 分钟内存 cache(`flutter_cache_manager` 或自实现),GET 接口自动 cache
- 💡 **重试策略** — 网络异常自动重试 N 次(可配置)
- 💡 **接口聚合 (Aggregator)** — 一个方法调多个接口然后合并(并行)
- 💡 **Stream 接口** — SSE / WebSocket 包装成 Stream
- 💡 **分页加载状态机** — 把 page/pageSize/loading/hasMore 自动管理
- 💡 **取消令牌全局管理** — 切路由时自动 cancel 该路由的所有请求
- 💡 **Mock 数据热更新** — 不需要重启,改 mock JSON 立即生效(运行时读取)
- 💡 **生成 unit test** — 用 mocktail 自动写 Repository 测试
- 💡 **OpenAPI / Swagger 导入** — 直接读 swagger.json 生成 contract + repository

**完全不要做的:**
- ❌ 不要绕过 ApiClient (那是核心库)
- ❌ 不要在 Repository 内做缓存(v1 没有,v3 才考虑,v1 做了破坏分层)
- ❌ 不要 catch 异常(让 controller 处理)
- ❌ 不要自动跑 build_runner

---

## 给博龙的具体提示

1. **第一件事:** 跑一遍 v1,生成 announce 模块的 repository,看代码是否能 `flutter analyze` 通过

2. **测试方法:**
   ```bash
   # 在 /tmp/flutter_skills_test/ 跑
   bash scripts/run.sh -d chrome
   # 写一个临时按钮调 repo.getList(),看 mock 数据能不能取出来
   ```

3. **最常见的坑:**
   - 忘了 `Get.lazyPut(... fenix: true)` 的 fenix 参数 → 切路由后实例被销毁,再次进入崩
   - `fromJson` 用错(应该传 `Announce.fromJson`,不是 `(json) => Announce.fromJson(json as Map)`)
   - mockKey 拼错(必须与 docs/api/{m}.md 完全一致)

4. **v2 优先级:** upload > 错误码 enum > 接口聚合 > 重试

5. **改完 SKILL.md 后:** version 字段递增(v1.0.0 → v1.1.0)
