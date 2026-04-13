---
name: flutter-api-gen
description: 接口契约 → Repository 类(GetX 风格) + Mock JSON 数据。用户说"生成接口请求"、"生成 repository"或 model-gen 完成后触发。严格调用 ApiClient,生成 GetX binding,产出可直接用的 data 层。
type: skill
stage: 4
model: sonnet
priority: P0
version: 2.0.0
owner: @b
category: generator
---

# API 代码生成 (flutter-api-gen)

## 1. 触发场景

- "生成 XX 模块的 Repository" / "生成 api 调用代码"
- "根据接口契约生成代码"
- "把契约文档转成 Repository"
- "这个 URL 的接口转成调用代码"
- "这个 curl 命令生成 Repository"

## 2. 前置必读

- `docs/_context/tech-stack.md`
- `docs/_context/conventions.md`
- `docs/_context/decisions.md`
- `docs/_context/glossary.md`
- `_design/api_client_signature.dart` ★ **必读,一定要读** (ApiClient 方法签名契约)
- `_design/app_exception.dart`（AppException 异常类型）
- `docs/api/{module}.md`（如输入为 .md 契约文档）

## 3. 输入

**必填参数：**
- `module_name` (string) — 模块英文名，snake_case
- `source` (string) — 用户输入（.md 文件路径 / JSON 字符串 / URL / curl 命令）

**可选参数：**
- `force_overwrite` (bool, default false) — 是否覆盖已有 Repository 文件
- `repo_output_path` (string, default `lib/features/{module}/data/repositories/`) — Repository 输出目录
- `mock_output_path` (string, default `mock/{module}/`) — Mock JSON 输出目录

**输入分流：**

| 形式 | 识别特征 | 解析方式 |
|---|---|---|
| .md 契约文档路径 | 以 `/` 或 `./` 开头，或 `.md` 后缀 | Read 文件，提取接口清单 |
| JSON 字符串 | 包含 `{` 和 `}` 的 JSON | 解析 JSON，推断接口结构 |
| curl 命令 | 以 `curl` 开头 | Bash 执行拿到响应 JSON，推断接口 |
| URL | 以 http/https 开头（非 curl） | WebFetch 抓取，按内容类型分流 |

## 4. 工作流程

**Pipeline:** 任何输入 → 解析 → 提取接口清单 → 推断 ApiClient 方法 → 检查 model → dry-run → 生成 Repository + Binding + Mock JSON

**Step 1 — 读 context + 检测 ApiClient 签名**
读取段 2 列出的所有前置文件。重点读 `_design/api_client_signature.dart` 确认方法签名。

⚠️ **ApiClient 签名变更检测：** 将 `_design/api_client_signature.dart` 中的方法签名与段 6 模板中使用的调用方式对比。如果签名已变更（参数增减、类型变化），**STOP** 并提示用户更新 skill 模板后再继续。

**Step 2 — 解析输入，提取接口清单**
按段 3 的输入分流规则判断输入形式：
- .md → Read 文件，提取每个接口的路径、Mock Key、请求字段、响应结构
- JSON → 解析 JSON，推断接口结构
- curl → Bash 执行拿到响应 JSON，推断接口
- URL → fetch 后按内容分流

归一化为接口清单：

    模块名: announce
    实体类名: Announce
    接口清单:
      - 接口名: getList
        路径: POST /announce/list          # ⚠️ 不带 /api（baseUrl 已含 apiPrefix）
        Mock Key: announce/list
        ApiClient 方法: getList
        请求字段: [{name: pageReq, type: PageReq, required: true}, {name: keyword, type: String?, required: false}]
        返回类型: PageResp<Announce>
      - 接口名: getDetail
        路径: GET /announce/detail          # ⚠️ 不带 /api
        Mock Key: announce/detail
        ApiClient 方法: get
        请求字段: [{name: id, type: String, required: true}]
        返回类型: Announce

**Step 3 — 推断 ApiClient 方法**
按以下规则自动推断每个接口对应的 ApiClient 方法：

| 契约特征 | ApiClient 方法 | Repository 返回类型 |
|---|---|---|
| 响应 data 含 `list` + `total` + `page` + `pageSize` | `getList<T>` | `PageResp<T>` |
| HTTP GET + 响应 data 为对象 | `get<T>` | `T` |
| HTTP POST + 响应 `data: null` | `postJson<void>` | `void` |
| HTTP POST + 响应 data 为对象 | `postJson<T>` | `T` |
| HTTP POST + Content-Type 为 `application/x-www-form-urlencoded`（或契约明确标注 form） | `postForm<T>` | `T` |
| HTTP DELETE + 响应 `data: null` | `delete<void>` | `void` |
| HTTP DELETE + 响应 data 为对象 | `delete<T>` | `T` |

⚠️ **不允许直接 `new Dio()` 或 import 'package:dio/dio.dart' 业务级**

> **重要：**
> - 推断结果必须在 Step 5 dry-run 中展示给用户确认。如果推断不确定（如 POST 但不确定用 postJson 还是 postForm），AskUser 确认。
> - 如果响应结构类似分页但字段名非标准（如 `items` 而非 `list`，`count` 而非 `total`），AskUser 确认是否用 `getList`（要求后端严格返回 `{list, total, page, pageSize}` 结构）还是用 `postJson` 自行处理。
> - 如果契约中同一模块引用了多个实体类型，每个方法的 `fromJson` 应引用正确的 model 类，Step 4 需检查所有引用的 model 文件是否存在。

**Step 4 — 检查 model 文件**
检查 `lib/features/{module}/data/models/{entity}.model.dart` 是否存在。
- 存在 → 继续
- 不存在 → 提示用户先运行 `flutter-model-gen` 生成实体类，stop

**Step 5 — Dry-run (AskUser)**
列出将生成的文件路径 + 每个 Repository 方法签名摘要 + Mock 文件列表。

使用 AskUserQuestion 提供三个选项：
1. **确认生成** — 进入 Step 6
2. **不要生成** — stop，不生成文件
3. **补充其他项** — 回到 Step 3，用户修改后重新 dry-run

**Step 6 — 写入 Repository + Binding + Mock JSON**
按段 6 的代码模板生成：
- `{repo_output_path}/{module}_repository.dart` — Repository 类
- `{repo_output_path}/{module}_repository.binding.dart` — GetX Binding
- `{mock_output_path}/{action}.json` — 每个接口一个 Mock 文件

**Step 7 — 更新 pubspec.yaml 注册 mock 子目录** ★ 关键!

**Flutter assets 不递归子目录**，只声明 `mock/` 不包括 `mock/announce/`。
必须在 pubspec.yaml 的 assets 段加该模块的 mock 目录：

```yaml
flutter:
  assets:
    - mock/
    - mock/announce/   # ← 必须显式加这一行!
```

操作：
1. 读 pubspec.yaml
2. 找 `assets:` 段
3. 检查是否已有 `- mock/{module}/`，如无则加
4. 保持其他 assets 不变

**漏这一步的后果：**
```
Error while trying to load an asset: Flutter Web engine failed to fetch
"assets/mock/announce/list.json". HTTP request succeeded, but the server
responded with HTTP status 404.
```

**Step 8 — 自检**
跑段 8 checklist，逐项验证。

**Step 9 — 输出总结**
告诉用户生成了什么 + 建议下一步。

## 5. 输出产物

    {repo_output_path}/                              — 默认 lib/features/{module}/data/repositories/
    ├── {module}_repository.dart                     — Repository 类
    └── {module}_repository.binding.dart             — GetX Binding

    {mock_output_path}/                              — 默认 mock/{module}/
    ├── {action1}.json                               — 接口 1 的 Mock 数据
    ├── {action2}.json                               — 接口 2 的 Mock 数据
    └── ...

## 6. 代码模板

### Repository 模板

以公告模块为例：

`````dart
// announce_repository.dart
import 'package:dio/dio.dart' show CancelToken;
import 'package:get/get.dart';

// ⚠️ package name 从 pubspec.yaml 的 name 字段读取,以下用 {package} 示意
import 'package:{package}/core/network/api_client.dart';
import 'package:{package}/core/network/models/page_req.dart';
import 'package:{package}/core/network/models/page_resp.dart';

import '../models/announce.model.dart';

// 注意: 不要 import app_exception.dart!Repository 不 catch 异常,
// 让 controller 上层 catch。引了不用会触发 unused_import lint。

/// 公告模块 Repository
///
/// 数据访问层,封装对 ApiClient 的调用。
/// 自动走加密 + Mock 拦截器,业务层不感知。
///
/// ⚠️ path 规则:**不要带 /api 前缀**
///   - ApiClient 的 baseUrl 已经是 `https://host.com/api`（含 apiPrefix）
///   - Repository 的 path 只写**业务部分** `/announce/list`
///   - 错误示例: `/api/announce/list` → 实际请求 `/api/api/announce/list` 404
class AnnounceRepository extends GetxService {
  final ApiClient _api = Get.find();

  /// 公告列表（分页）
  Future<PageResp<Announce>> getList({
    required PageReq pageReq,
    String? keyword,
    CancelToken? cancelToken,
  }) async {
    return _api.getList<Announce>(
      path: '/announce/list',  // ⚠️ 不带 /api
      pageReq: pageReq,
      extraParams: keyword != null ? {'keyword': keyword} : null,
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

  /// 提交反馈（postForm 示例）
  Future<void> submitFeedback({
    required String id,
    required String content,
    CancelToken? cancelToken,
  }) async {
    await _api.postForm<void>(
      path: '/announce/feedback',  // ⚠️ 不带 /api
      data: {'id': id, 'content': content},
      mockKey: 'announce/feedback',
      fromJson: (_) {},
      cancelToken: cancelToken,
    );
  }

  /// 删除公告（delete + void 示例）
  Future<void> remove({
    required String id,
    CancelToken? cancelToken,
  }) async {
    await _api.delete<void>(
      path: '/announce/remove',  // ⚠️ 不带 /api
      data: {'id': id},
      mockKey: 'announce/remove',
      fromJson: (_) {},
      cancelToken: cancelToken,
    );
  }
}
`````

### Binding 模板

`````dart
// announce_repository.binding.dart
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
    // 用 tearoff 而非 lambda（避免 unnecessary_lambdas lint）
    Get.lazyPut<AnnounceRepository>(AnnounceRepository.new, fenix: true);
  }
}
`````

### Mock JSON 模板

`````json
// mock/announce/list.json
{
  "status": "y",
  "data": {
    "list": [
      {
        "id": "65f7a8b9c1d2e3f4",
        "title": "系统升级公告",
        "content": "<p>本周日凌晨进行系统升级...</p>",
        "publishAt": "2026-04-10T10:00:00Z",
        "isRead": false
      },
      {
        "id": "65f7a8b9c1d2e3f5",
        "title": "新功能上线",
        "content": "<p>我们新增了 ...</p>",
        "publishAt": "2026-04-08T15:30:00Z",
        "isRead": true
      },
      {
        "id": "65f7a8b9c1d2e3f6",
        "title": "维护通知",
        "content": "<p>本周二晚 22:00 进行 ...</p>",
        "publishAt": "2026-04-05T09:00:00Z",
        "isRead": false
      }
    ],
    "total": 3,
    "page": 1,
    "pageSize": 20
  }
}
`````

`````json
// mock/announce/detail.json
{
  "status": "y",
  "data": {
    "id": "65f7a8b9c1d2e3f4",
    "title": "系统升级公告",
    "content": "<p>详细内容...</p>",
    "publishAt": "2026-04-10T10:00:00Z",
    "isRead": false,
    "author": "运营团队"
  }
}
`````

`````json
// mock/announce/markRead.json
{
  "status": "y",
  "data": null
}
`````

### Upload 方法模板（v2）

```dart
  /// 上传头像
  ///
  /// [file] 文件 (用 XFile 三端兼容)
  /// [onProgress] 上传进度回调
  Future<UploadResp> uploadAvatar({
    required XFile file,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    return _api.upload(
      path: '/user/avatar',  // ⚠️ 不带 /api
      file: file,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }
```

**upload 规则:**
- import `package:cross_file/cross_file.dart` (XFile 三端兼容)
- 返回类型 `UploadResp` (含 url + key)
- 不需要 mockKey (upload 不走 mock)
- 不需要 fromJson (ApiClient.upload 内部处理)
- onProgress 可选,透传给 ApiClient

### Download 方法模板（v2）

```dart
  /// 下载文件
  ///
  /// [savePath] 保存路径
  Future<void> downloadFile({
    required String url,
    required String savePath,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await _api.download(
      urlPath: url,
      savePath: savePath,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }
```

### 带注释的 Repository 方法模板（v2）

```dart
  /// 示例列表（分页）
  ///
  /// 分页查询示例数据,支持按名称/标题/状态筛选。
  /// 来源: docs/api/example.md - 接口 1
  Future<PageResp<ExampleInfo>> getList({
    required PageReq pageReq,
    String? name,
    String? title,
    int? status,
    String? startTime,
    String? endTime,
    CancelToken? cancelToken,
  }) async {
    return _api.getList<ExampleInfo>(
      path: '/example/list',
      pageReq: pageReq,
      extraParams: {
        if (name != null) 'name': name,
        if (title != null) 'title': title,
        if (status != null) 'status': status,
        if (startTime != null) 'startTime': startTime,
        if (endTime != null) 'endTime': endTime,
      },
      mockKey: 'example/list',
      fromJson: (json) => ExampleInfo.fromJson(json as Map<String, dynamic>),
      cancelToken: cancelToken,
    );
  }

  /// 新增示例
  ///
  /// 新增一条示例数据。name 和 title 必填。
  /// 来源: docs/api/example.md - 接口 2
  Future<void> add({
    required String name,
    required String title,
    String? content,
    String? remark,
    int? status,
    CancelToken? cancelToken,
  }) async {
    await _api.postJson<void>(
      path: '/example/add',
      data: {
        'name': name,
        'title': title,
        if (content != null) 'content': content,
        if (remark != null) 'remark': remark,
        if (status != null) 'status': status,
      },
      mockKey: 'example/add',
      fromJson: (_) {},
      cancelToken: cancelToken,
    );
  }
```

**v2 注释规则:**
- 每个方法加 `///` 注释,从契约文档的 summary/description 提取
- 标注来源: `/// 来源: docs/api/{module}.md - 接口 N`
- 必填字段用 `required` 关键字
- 可选筛选字段用 `if (x != null) 'key': x` 模式传入 extraParams/data

### 模板规则

**Repository 规则：**
- 类名 `{Module}Repository extends GetxService`
- `final ApiClient _api = Get.find()` 获取 ApiClient 实例
- 每个方法最后一个参数为 `CancelToken? cancelToken`
- **不 catch 异常** — Repository 不 try-catch，让 controller 上层统一处理
- **不 import `app_exception.dart`** — Repository 不 catch，引了会触发 unused_import lint
- `fromJson` 统一写法: `(json) => Xxx.fromJson(json as Map<String, dynamic>)`
- `void` 返回的接口: `fromJson: (_) {}`
- 列表接口: 分页参数用 `PageReq`，额外请求参数用 `extraParams`
- GET 接口: 请求参数走 `query`
- POST 接口: 请求参数走 `data`
- import 路径: 相对路径引 model (`../models/xxx.model.dart`)
- **path 不带 `/api` 前缀** — baseUrl 已含 apiPrefix，重复会 `/api/api/` 404

**Binding 规则：**
- 类名 `{Module}RepositoryBinding extends Bindings`
- **用 tearoff:** `Get.lazyPut<XxxRepository>(XxxRepository.new, fenix: true)` — 避免 unnecessary_lambdas lint
- `fenix: true` 必须加 — 切路由后实例被销毁，再次进入不会崩
- 文件名 `{module}_repository.binding.dart`

**Mock JSON 规则：**
- 直接复制契约文档中的响应结构示例
- 保持 `status` + `data` 包装结构
- 文件名与 Mock Key 的 action 部分一致（如 `announce/list` → `list.json`）

**ApiClient 方法参数映射：**

| ApiClient 方法 | 必填参数 | 可选参数 |
|---|---|---|
| `get<T>` | path, mockKey, fromJson | query, cancelToken, encrypt |
| `postJson<T>` | path, data, mockKey, fromJson | cancelToken, encrypt |
| `postForm<T>` | path, data, mockKey, fromJson | cancelToken, encrypt |
| `getList<T>` | path, pageReq, mockKey, fromJson | extraParams, cancelToken, encrypt |
| `delete<T>` | path, mockKey, fromJson | data, cancelToken, encrypt |

### 业务层调用示例 (写在注释里给用户参考)

```dart
// 在 controller 中:
final repo = Get.find<AnnounceRepository>();
try {
  final resp = await repo.getList(pageReq: const PageReq());
  // 处理 resp.list / resp.total / resp.hasMoreWith(pageNum:, pageSize:)
} on CancelException {
  // 静默,不提示
} on AuthException {
  Get.toNamed('/login');
} on BusinessException catch (e) {
  Get.snackbar('提示', e.userMessage);
} on AppException catch (e) {
  Get.snackbar('错误', e.userMessage);
} catch (e, s) {
  // 兜底: 非 AppException 包成 UnknownException
  error.value = UnknownException(message: e.toString(), cause: e, stackTrace: s);
} finally {
  loading.value = false;
}
```

## 7. 不做什么 (Boundary)

- ❌ **不直接 `new Dio()`** — 必须 `Get.find<ApiClient>()`
- ❌ **不直接 import `package:dio/dio.dart`** (除了 type re-export 如 `show CancelToken`)
- ❌ 不在 Repository 内 catch 异常 (让上层 catch)
- ❌ 不在 Repository 内调 `Get.snackbar` (那是 UI 的事)
- ❌ 不写业务逻辑 (Repository 只做数据访问,业务在 controller)
- ❌ 不生成 model 实体类（交给 flutter-model-gen）
- ❌ 不生成 Controller / Page（交给 flutter-page-gen）
- ❌ 不修改 model 文件
- ❌ 不修改 lib/core/network/
- ❌ 不自动跑路由注册 (那是 page-gen 的事)
- ❌ 不直接读 .json 文件 (mock 是 ApiClient 内部的事)
- ❌ 不 throw String
- ❌ 不自动 git commit

## 8. 自检 Checklist

- [ ] **path 不带 `/api` 前缀** ★（baseUrl 已含 apiPrefix，重复会 /api/api/ 404）
- [ ] **必须更新 pubspec.yaml 注册 mock 子目录** ★ — 加 `- mock/{module}/`（Flutter assets 不递归）
- [ ] **必须生成完整方法**（契约里的所有接口都要，不能漏）
- [ ] Repository 类继承 `GetxService`
- [ ] 字段用 `final ApiClient _api = Get.find()`
- [ ] 使用 `Get.find<ApiClient>()` 获取实例，未直接 new Dio()
- [ ] 每个方法签名与 `api_client_signature.dart` 一致
- [ ] 每个方法都传 `mockKey` 参数
- [ ] 每个方法都传 `cancelToken` 参数
- [ ] 用了 `fromJson:` 而非 `as Map`
- [ ] **没有 try-catch**（让 controller 上层处理）
- [ ] **没有 import `app_exception.dart`**（Repository 不 catch，引了会触发 unused_import）
- [ ] 没有直接 `new Dio()`
- [ ] 没有 `package:dio/dio.dart` 直接 import（除 `show CancelToken`）
- [ ] `fromJson` 写法统一: `(json) => Xxx.fromJson(json as Map<String, dynamic>)`
- [ ] 列表接口用 `getList`，返回 `PageResp<T>`
- [ ] void 返回的接口 `fromJson: (_) {}`
- [ ] Mock JSON 保持 `{status, data}` 包装结构
- [ ] 每个接口生成了对应的 Mock JSON 文件
- [ ] **Binding 用 tearoff**（`XxxRepository.new` 而非 `() => XxxRepository()`）
- [ ] **Binding 有 `fenix: true`**
- [ ] Binding 文件存在
- [ ] 路径正确: `lib/features/{m}/data/repositories/`
- [ ] 文件名 snake_case，类名 PascalCase
- [ ] import 路径正确（model 用相对路径）
- [ ] 每个方法最后一个命名参数为 `CancelToken? cancelToken`
- [ ] dart analyze 0 errors

## 9. 失败处理

**何时 ask user：**
- ApiClient 方法推断不确定时（如 POST 不确定用 postJson 还是 postForm）
- 检测到将覆盖已有 Repository 文件时
- 输入模糊，无法确定接口数量或字段时

**何时 stop：**
- model 文件不存在（提示先跑 flutter-model-gen）
- .md 文件不存在或内容无法解析
- JSON 格式非法
- URL 抓取失败
- 契约中包含 upload/download 接口但 ApiClient 无对应方法（检查 api_client_signature.dart）
- **ApiClient 接口签名变了**（检测 `_design/api_client_signature.dart` 与模板不一致）

**何时 rollback：**
- 自检失败 → 删除本次新增的文件
- 写入中失败 → 如有 git，`git checkout` 恢复；如无 git，删除不完整文件

## 10. 联动

**成功后建议：**
> "Repository + Mock 生成完成。建议下一步用 `flutter-page-gen` 生成页面。"

**失败后回退：**
> "生成失败。请检查契约文档格式，或回到 `flutter-api-design` 检查契约。"

**上游：** flutter-model-gen
**下游：** flutter-page-gen

## 11. 扩展路线图

**v1 (当前) — 基础够用:**
- ✅ 5 个 ApiClient 方法的封装 (get / postJson / postForm / getList / delete)
- ✅ Repository extends GetxService
- ✅ Binding 自动生成
- ✅ cancelToken 透传
- ✅ mockKey 自动注入
- ✅ fromJson 转 model

**v2 (已完成):**
- ✅ upload 方法封装 — XFile + onProgress + UploadResp
- ✅ download 方法 — savePath + onProgress
- ✅ 接口注释 — 从契约文档的 summary/description 提取 `///` 注释 + 来源标注
- ✅ 必填字段 required — 契约中标 required 的字段在方法签名加 required
- ✅ 错误码 — 已由独立 skill `flutter-error-code-gen` 覆盖

**v3 (可选高级):**
- 💡 Cache 层封装
- 💡 重试策略
- 💡 Stream 接口 (SSE / WebSocket)
- 💡 OpenAPI / Swagger 导入
