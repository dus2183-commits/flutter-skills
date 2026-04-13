---
name: flutter-api-quick
description: API 规格一键生成全套代码(契约+model+Repository+Binding+Mock+build_runner)。用户说"快速生成接口"、"一键生成 API"、"帮我把这几个接口全生成了"时触发。零交互,粘贴即出。
type: skill
stage: 4
model: sonnet
priority: P0
version: 1.0.0
owner: @b
category: generator
---

# API 快速生成 (flutter-api-quick)

> 合并 flutter-api-design + flutter-model-gen + flutter-api-gen 三步为一步。
> 零交互生成: 契约文档 + freezed model + Repository + Binding + Mock JSON。

---

## 1. 触发场景

- "快速生成 XX 接口" / "一键生成 XX API"
- "帮我把这几个接口全生成了"
- "这是后端给的接口文档,帮我生成代码"
- "根据这个 Swagger 生成全套"
- "curl ... 帮我生成 model 和 repository"
- 用户粘贴了接口路径 + 请求字段 + 响应 JSON

**反例(不该触发):**
- "设计 XX 接口" → `flutter-api-design` (用户想交互式设计)
- "只生成 model" → `flutter-model-gen`
- "只生成 repository" → `flutter-api-gen`
- "评审接口代码" → `flutter-review`

---

## 2. 前置必读

- `docs/_context/tech-stack.md`
- `docs/_context/conventions.md`
- `docs/_context/decisions.md` (检查加密策略等决策)
- `_design/api_client_signature.dart` (ApiClient 方法签名)
- `lib/core/network/interceptors/error_interceptor.dart` (响应剥壳逻辑)
- `docs/api/*.md` (已有契约,避免错误码冲突)
- `pubspec.yaml` (检查 mock assets 注册 + 读取 package name)

---

## 3. 输入

**必填:**
- `api_spec` (text) — 用户粘贴的接口信息(任意格式)

**可选:**
- `module_name` (string) — 未提供时从 API 路径自动推断

**输入路由:**

| 输入形式 | 识别特征 | 常见场景 |
|---|---|---|
| 文字+JSON | 含 `POST\|GET\|PUT\|DELETE /` + JSON 块 | 后端在群里/文档里发的接口定义 |
| curl 命令 | 以 `curl` 开头 | 后端已部署,可实际调用 |
| Swagger/OpenAPI | 顶层含 `openapi` 或 `swagger` 字段 | 后端用 Apifox/Swagger 管理 |
| 多接口批量 | 含 2+ 个 HTTP 方法行,用 `---` 或编号分隔 | 一次性粘贴多个接口 |

**最常见输入示例(文字+JSON):**
```
POST /api/v1/auth/login
请求: email(string), password(string)
响应:
{
  "code": 0,
  "data": { "token": "xxx", "user": { "id": 1, "name": "test" } },
  "msg": "ok"
}
```

---

## 4. 工作流程

### Step 1 — 读 context + 检测响应格式

读段 2 所有前置文件。重点:
- 读 `error_interceptor.dart` 确认剥壳逻辑: 检查 `status == 'n'` 抛 BusinessException,否则 `response.data = data['data']` 提取内层数据
- 读 `pubspec.yaml` 的 `name` 字段获取 package name(用于 import 路径)
- 扫描 `docs/api/*.md` 提取已占用的错误码段位

**响应格式检测:**
- ErrorInterceptor 只关心两件事: ① `data['status'] == 'n'` 判断错误 ② `data['data']` 提取内层
- 用户提供的 JSON 示例可能是 `{code, data, msg}` 或 `{status, data, errorCode, error}` — 两种都能正常剥壳,因为都有 `data` 字段
- Mock JSON 和契约文档中的响应格式应跟随用户提供的实际 JSON 示例,不强制转换

### Step 2 — 解析输入,提取接口清单

按输入路由分别处理,归一化为统一中间态:

```
接口清单:
  - 中文名: 登录
    方法: POST
    路径: /api/v1/auth/login
    请求字段: [{name: email, type: String}, {name: password, type: String}]
    响应JSON: {"code":0, "data": {"token":"xxx", "user":{...}}, "msg":"ok"}
```

**路由 A (文字+JSON):** 提取 HTTP 方法+路径、请求字段描述、响应 JSON 块。
**路由 B (Swagger/OpenAPI):** 详细解析规则:

1. **识别**: 顶层含 `swagger: "2.0"` 或 `openapi: "3.x"`
2. **提取接口**: 遍历 `paths` 对象,每个 path+method 组合 = 一个接口
3. **请求字段**:
   - Swagger 2.0: `parameters[].in == "body"` → 取 `schema.$ref` → 从 `definitions` 解析
   - OpenAPI 3.x: `requestBody.content.application/json.schema.$ref` → 从 `components.schemas` 解析
4. **解析 $ref**: `$ref: "#/definitions/proto.AddExampleReq"` → 找 `definitions["proto.AddExampleReq"]`
   - `properties` → 字段列表
   - `required` 数组 → 标记必填字段
   - `type: "integer"` → int, `type: "string"` → String, `type: "array"` → List
   - 嵌套 `$ref` → 递归解析
5. **响应结构**:
   - Swagger 2.0: `responses.200.schema.$ref` → 从 `definitions` 解析
   - 无 `$ref` 时(如 `type: "string"`) → 简单返回类型
6. **字段说明**: `properties.xxx.description` → 提取为注释
7. **tags**: 用 `tags[0]` 作为模块中文名
8. **summary**: 用 `summary` 作为接口中文名,`description` 作为接口注释

**Swagger 归一化示例**:
```
输入: proto.ExampleListReq (definitions)
  properties: pageNum(int,required), pageSize(int,required), name(string), title(string), status(int), startTime(string), endTime(string)

归一化为:
  请求字段: [{name: pageNum, type: int, required: true, desc: "页数"}, {name: pageSize, type: int, required: true, desc: "条数"}, ...]
```
**路由 C (curl):** 解析 URL(-X 取方法)、-d 取请求体、-H 取 headers。无响应体时 ASK_USER。
**路由 D (多接口):** 按 `---` 或编号拆分,每段走路由 A/C。

### Step 3 — 推断 module_name

从第一个 API 路径提取: `/api/v1/{module}/action` → module。
- 有版本前缀 `/v1/` → 保留在 repository path,但 module_name 取版本后的段
- 例: `/api/v1/auth/login` → module_name = `auth`, repo path = `/v1/auth/login`
- **用户输入路径如含 /api 前缀,生成 Repository path 时必须去掉** (baseUrl 已含 apiPrefix,否则 /api/api/ 404)
- 用户显式指定 module_name 时以用户为准

### Step 4 — 推断字段类型 + ApiClient 方法

**类型推断(从 JSON 值):**

| JSON 值 | Dart 类型 |
|---|---|
| `"abc"` | String |
| `123` | int |
| `12.5` | double |
| `true`/`false` | bool |
| `null` | 标记 nullable,类型从其他接口或字段名推断;无法推断时 ASK_USER |
| ISO 8601 字符串 (`\d{4}-\d{2}-\d{2}T`) | DateTime |
| `[...]` | List&lt;T&gt; (取首元素推断 T) |
| `{...}` 嵌套对象 | 独立 model 类 |

**snake_case 处理:** JSON key 含 `_` → Dart 字段转 camelCase + `@JsonKey(name: 'original_key')`

**ApiClient 方法推断:**

| 特征 | ApiClient 方法 | 返回类型 |
|---|---|---|
| 响应 data 含 list+total+page+pageSize | `getList<T>` | `PageResp<T>` |
| HTTP GET + data 为对象 | `get<T>` | `T` |
| HTTP POST + data 为 null | `postJson<void>` | `void` |
| HTTP POST + data 为对象 | `postJson<T>` | `T` |
| HTTP POST + Content-Type `application/x-www-form-urlencoded` | `postForm<T>` | `T` |
| HTTP DELETE | `delete<T>` | `T` 或 `void` |

**请求 model 生成规则:**
- POST body ≤2 个字段 → 内联 `data: {'field1': value1, 'field2': value2}`
- POST body ≥3 个字段 → 生成 `{action}_req.model.dart`

### Step 5 — 分配错误码

- 格式: `2{XX}{NNN}` — XX 为模块序号(01-99),NNN 为错误序号(001-999)
- 扫描 `docs/api/*.md` 已有段位,取下一个可用序号
- 每个模块预分配常见错误码: 参数错误、不存在、重复、服务异常

### Step 6 — 一次性生成全部产物(零交互)

按以下顺序生成,**不做 dry-run 确认**:

> **为什么跳过 dry-run?** 零交互是本 skill 的核心价值。单独的 flutter-api-gen 有 dry-run 确认步骤,适合需要精细控制的场景。flutter-api-quick 面向"后端刚给了接口文档,赶紧生成代码"的场景,速度优先。如需精细控制,请用分步 skill。

1. **契约文档** `docs/api/{module}.md` — 含 frontmatter + 全局规则 + 每个接口详情 + 错误码表
2. **响应 Model** `lib/features/{module}/data/models/{resp}.model.dart` — freezed 类
3. **嵌套 Model** `lib/features/{module}/data/models/{nested}.model.dart` — 嵌套对象拆文件
4. **请求 Model** `lib/features/{module}/data/models/{action}_req.model.dart` — 仅 ≥3 字段时
5. **Repository** `lib/features/{module}/data/repositories/{module}_repository.dart`
6. **Binding** `lib/features/{module}/data/repositories/{module}_repository.binding.dart`
7. **Mock JSON** `mock/{module}/{action}.json` — 每个接口一个
8. **pubspec.yaml** — 在 assets 段加 `- mock/{module}/`

**响应模型去重:** 多接口共享相同响应结构时只生成一个 model(如 login 和 register 都返回 AuthResp)。

### Step 7 — 执行 build_runner

> **与分步 skill 的区别:** flutter-model-gen 只提示用户手动跑 build_runner,flutter-api-quick 自动执行。这是零交互设计的一部分。

```bash
fvm dart run build_runner build --delete-conflicting-outputs
```

### Step 8 — 自检(段 8 checklist)

### Step 9 — 输出总结

---

## 5. 输出产物

```
docs/api/{module}.md                                    契约文档
lib/features/{module}/data/models/
├── {entity}.model.dart                                  响应实体 model (如 auth.model.dart)
├── {nested_entity}.model.dart                           嵌套对象 model (如 auth_user.model.dart)
└── {action}_req.model.dart                              请求 model (≥3 字段时)
lib/features/{module}/data/repositories/
├── {module}_repository.dart                             Repository
└── {module}_repository.binding.dart                     Binding
mock/{module}/
├── {action1}.json                                       Mock JSON
└── {action2}.json
pubspec.yaml                                             追加 mock/{module}/ 到 assets
```

---

## 6. 代码模板

### 6.1 契约文档

````markdown
---
artifact_type: api
module: {module}
version: 1
created: {date}
created_by: flutter-api-quick
parent_artifact: null
status: draft
owner: @c
---

# {模块中文名} - 接口契约

> 错误码段位: 2{XX}001-2{XX}099

## 全局规则

- **认证:** {JWT / 公开}
- **加密:** 走项目加密通道
- **响应格式:** {从用户 JSON 示例检测到的格式}
- **Mock 路径:** mock/{module}/

## 接口 1: {接口中文名}

**路径:** `{METHOD} {path}`
**Mock Key:** `{module}/{action}`

### 请求字段

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| ... | ... | ... | ... |

### 响应结构

```json
{用户提供的响应 JSON}
```

## 错误码表

| code | 含义 |
|---|---|
| 2{XX}001 | 参数校验失败 |
| 2{XX}002 | 数据不存在 |
| 2{XX}003 | 数据重复 |
| 2{XX}099 | 服务异常 |
````

### 6.2 Freezed Model

```dart
// {entity}.model.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part '{entity}.model.freezed.dart';
part '{entity}.model.g.dart';

@freezed
class {Entity} with _${Entity} {
  const factory {Entity}({
    required String token,
    required {NestedEntity} user,
  }) = _{Entity};

  factory {Entity}.fromJson(Map<String, dynamic> json) =>
      _${Entity}FromJson(json);
}
```

嵌套对象(snake_case 字段示例):

```dart
// {module}_{field}.model.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part '{module}_{field}.model.freezed.dart';
part '{module}_{field}.model.g.dart';

@freezed
class {Module}{Field} with _${Module}{Field} {
  const factory {Module}{Field}({
    required int id,
    required String name,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _{Module}{Field};

  factory {Module}{Field}.fromJson(Map<String, dynamic> json) =>
      _${Module}{Field}FromJson(json);
}
```

请求 model(仅 ≥3 字段时生成):

```dart
// {action}_req.model.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part '{action}_req.model.freezed.dart';
part '{action}_req.model.g.dart';

@freezed
class {Action}Req with _${Action}Req {
  const factory {Action}Req({
    required String email,
    required String password,
    @JsonKey(name: 'password_confirm') required String passwordConfirm,
  }) = _{Action}Req;

  factory {Action}Req.fromJson(Map<String, dynamic> json) =>
      _${Action}ReqFromJson(json);
}
```

### 6.3 Repository

> **import 路径:** `package:{name}` 中的 `{name}` 从 `pubspec.yaml` 的 `name` 字段读取,不要硬编码。

**postJson 示例(最常见):**

```dart
import 'package:dio/dio.dart' show CancelToken;
import 'package:get/get.dart';

import 'package:{package_name}/core/network/api_client.dart';

import '../models/{resp_entity}.model.dart';

/// {模块中文名} Repository
///
/// path 不带 /api 前缀 — baseUrl 已含 apiPrefix
class {Module}Repository extends GetxService {
  final ApiClient _api = Get.find();

  /// {接口中文名}
  Future<{ReturnType}> {methodName}({
    required {ReqType} req,  // 或内联参数
    CancelToken? cancelToken,
  }) async {
    return _api.postJson<{ReturnType}>(
      path: '{path_without_api}',
      data: req.toJson(),  // 或内联 {'field': value}
      mockKey: '{module}/{action}',
      fromJson: (json) => {ReturnType}.fromJson(json as Map<String, dynamic>),
      cancelToken: cancelToken,
    );
  }
}
```

**getList 示例(分页列表):**

```dart
import 'package:{package_name}/core/network/models/page_req.dart';
import 'package:{package_name}/core/network/models/page_resp.dart';

  /// {接口中文名}(分页)
  Future<PageResp<{Entity}>> {methodName}({
    required PageReq pageReq,
    String? keyword,
    CancelToken? cancelToken,
  }) async {
    return _api.getList<{Entity}>(
      path: '{path_without_api}',
      pageReq: pageReq,
      extraParams: keyword != null ? {'keyword': keyword} : null,
      mockKey: '{module}/{action}',
      fromJson: (json) => {Entity}.fromJson(json as Map<String, dynamic>),
      cancelToken: cancelToken,
    );
  }
```

**void 示例(无返回数据):**

```dart
  /// {接口中文名}
  Future<void> {methodName}({
    required String id,
    CancelToken? cancelToken,
  }) async {
    await _api.postJson<void>(
      path: '{path_without_api}',
      data: {'id': id},
      mockKey: '{module}/{action}',
      fromJson: (_) {},
      cancelToken: cancelToken,
    );
  }
```

### 6.4 Binding

```dart
import 'package:get/get.dart';

import '{module}_repository.dart';

class {Module}RepositoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<{Module}Repository>({Module}Repository.new, fenix: true);
  }
}
```

### 6.5 Mock JSON

Mock JSON 必须包含顶层 `data` 字段(ErrorInterceptor 依赖此字段剥壳)。
外层格式跟随用户提供的 JSON 示例:

```json
{
  "code": 0,
  "data": {
    "token": "tk_mock_token_123456",
    "user": {
      "id": 1,
      "name": "Mock用户",
      "email": "mock@example.com",
      "created_at": "2026-04-12T10:00:00Z",
      "updated_at": "2026-04-12T10:00:00Z"
    }
  },
  "msg": "ok"
}
```

void 响应: `{ "code": 0, "data": null, "msg": "ok" }`
列表响应: data 内含 `{ "list": [...], "total": N, "page": 1, "pageSize": 20 }`,至少 3 条数据。

---

## 7. 不做什么

- ❌ 不在常规流程中 AskUser 确认(零交互是核心价值)
- ❌ 不生成 Controller / Page(交给 flutter-page-gen)
- ❌ 不在 Repository 中 catch 异常(让 controller 上层处理)
- ❌ 不 import `app_exception.dart`(Repository 不 catch,引了触发 unused_import)
- ❌ 不在 path 中带 `/api` 前缀(baseUrl 已含 apiPrefix)
- ❌ 不直接 `new Dio()`(只通过 ApiClient)
- ❌ 不生成 upload/download 方法(需 XFile,超出范围)
- ❌ 不硬编码中文字符串到 Dart 代码(用 .tr)
- ❌ 不跳过 pubspec.yaml mock 资源注册
- ❌ 不为响应外层包装生成 model(status/data/code/msg 由拦截器处理)

---

## 8. 自检 Checklist

**契约文档:**
- [ ] `docs/api/{module}.md` 存在且 frontmatter 完整
- [ ] 每个接口有 mockKey、path、method、请求字段、响应 JSON
- [ ] 错误码段位不与已有模块冲突

**Model:**
- [ ] 所有 `.model.dart` 有 `part` 声明(`.freezed.dart` + `.g.dart`)
- [ ] 所有字段有明确类型(无 dynamic、无裸 List)
- [ ] snake_case JSON key 有 `@JsonKey(name: ...)`
- [ ] ISO 8601 字符串映射为 DateTime
- [ ] 嵌套对象拆为独立 `.model.dart`

**Repository:**
- [ ] 继承 `GetxService`
- [ ] `final ApiClient _api = Get.find()`
- [ ] path 不含 `/api` 前缀
- [ ] 每个方法有 `CancelToken? cancelToken`
- [ ] 每个方法有 `mockKey`
- [ ] 不含 try-catch
- [ ] 不含 `import app_exception`
- [ ] `fromJson` 写法: `(json) => Xxx.fromJson(json as Map<String, dynamic>)`
- [ ] void 返回的接口用 `fromJson: (_) {}`
- [ ] 列表接口用 `getList`,返回 `PageResp<T>`,import 了 `page_req.dart` 和 `page_resp.dart`
- [ ] import 路径用 `package:{name}` 而非硬编码(name 从 pubspec.yaml 读取)

**Binding:**
- [ ] 用 tearoff: `{Module}Repository.new`
- [ ] 有 `fenix: true`

**Mock + 注册:**
- [ ] Mock JSON 有顶层 `data` 字段
- [ ] 列表 mock 有 ≥3 条数据
- [ ] `pubspec.yaml` 有 `- mock/{module}/`

**构建:**
- [ ] `fvm dart run build_runner build` 成功
- [ ] `fvm flutter analyze` 生成文件 0 errors

---

## 9. 失败处理

**ASK_USER 时机(仅这些情况才打断零交互):**
- 用户只给了请求字段,没给响应 JSON(无法推断响应 model)
- 字段类型真正歧义(如 `"status": 1` 是 int 还是 enum)
- 将覆盖 `lib/features/{module}/data/` 下已有文件
- 嵌套对象深度 > 2 层

**STOP 时机:**
- 输入无法识别为任何路由(不是文字+JSON、不是 curl、不是 Swagger)
- `lib/features/` 目录不存在(项目未初始化)

**FALLBACK:**
- 输入信息不足以零交互生成时,提示:
  > "输入信息不足,建议分步执行: 1) flutter-api-design 2) flutter-model-gen 3) flutter-api-gen"

**ROLLBACK:**
- build_runner 失败 → 保留 `.model.dart`(model 本身可能是对的,只是 codegen 有问题),提示用户检查错误后手动重跑 `fvm dart run build_runner build --delete-conflicting-outputs`
- 自检失败 → 删除 `lib/features/{module}/data/` 下新增文件,revert pubspec.yaml

---

## 10. 联动

**成功后:**
> "全套接口代码生成完成:
>   - 契约: docs/api/{module}.md ({N} 个接口)
>   - Model: {M} 个 freezed 实体
>   - Repository: {N} 个方法
>   - Mock: {N} 个 JSON 文件
>   - build_runner 已执行
>
> 下一步: 用 `flutter-page-gen` 生成页面"

**失败后:**
> "生成失败。请检查输入格式,或分步执行: flutter-api-design → flutter-model-gen → flutter-api-gen"

**上游:** 用户直接输入(无需上游 skill)
**下游:** flutter-page-gen
**替代:** flutter-api-design + flutter-model-gen + flutter-api-gen(精细控制时使用)
