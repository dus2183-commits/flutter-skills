---
name: flutter-test-gen
description: 给一段 Dart 代码,生成 mocktail 单元测试。用户说"生成测试"、"写单测"、"加测试"、"生成 unit test"、"给 XX 写测试"、"测试覆盖"、"补测试"时触发。每个方法覆盖成功/异常/边界三场景,用 mocktail。
type: skill
stage: 5
model: sonnet
priority: P0
version: 1.0.0
owner: @b
category: validator
---

# 单元测试生成 (flutter-test-gen)

## 1. 触发场景

- "给这个类生成单测" / "写单元测试"
- "生成 XX 的 mocktail 测试"
- "给这段代码写 test"
- "生成 Repository 的测试"
- "帮我测试这个 Controller"

## 2. 前置必读

- `docs/_context/tech-stack.md`
- `docs/_context/conventions.md`
- `docs/_context/decisions.md`
- `docs/_context/glossary.md`
- `_design/api_client_signature.dart`（了解 ApiClient 方法签名，用于 mock）
- `_design/app_exception.dart`（了解异常类型，用于异常路径测试）

## 3. 输入

**必填参数：**
- `source` (string) — 要测试的代码（文件路径或代码片段）

**可选参数：**
- `output_path` (string, default `test/`) — 测试文件输出目录
- `force_overwrite` (bool, default false) — 是否覆盖已有测试文件

**输入分流：**

| 形式 | 识别特征 | 解析方式 |
|---|---|---|
| 文件路径 | 以 `/` 或 `./` 开头，或 `.dart` 后缀 | Read 文件，解析代码结构 |
| 代码片段 | 包含 `class` 关键字的 Dart 代码 | 直接解析代码结构 |

## 4. 工作流程

**Pipeline:** 输入 → 解析代码结构 → 识别依赖 → 生成 Mock + 测试用例 → dry-run → 写入

**Step 1 — 读 context**
读取段 2 列出的所有前置文件。

**Step 2 — 解析输入，分析代码结构**
按段 3 的输入分流规则判断输入形式：
- 文件路径 → Read 文件
- 代码片段 → 直接解析

提取以下信息：

    类名: MessageRepository
    父类: GetxService
    依赖:
      - {name: _api, type: ApiClient, 获取方式: Get.find()}
    public 方法:
      - {name: getList, 返回类型: Future<PageResp<Message>>, 参数: [{name: pageReq, type: PageReq, required: true}, {name: cancelToken, type: CancelToken?, required: false}]}

**Step 3 — 生成 Mock 类清单 + 测试用例清单**

**Mock 类生成规则：**
- 每个依赖生成一个 Mock 类: `class MockXxx extends Mock implements Xxx {}`
- 如果依赖是 ApiClient → `class MockApiClient extends Mock implements ApiClient {}`
- 如果有 Mock JSON 文件（`mock/{module}/{action}.json`），读取作为测试数据源；如果不存在，生成内联测试数据
- 零依赖类：跳过 Mock 生成，直接测试输入输出
- 多依赖类：每个依赖各生成一个 Mock 类，`setUp` 中逐个 `Get.put` 注入
- 必须在 `setUpAll` 中为所有自定义类型调用 `registerFallbackValue`（mocktail 要求）

**测试用例生成规则（每个 public 方法 3 类）：**

| 类型 | 命名模式 | 验证内容 |
|---|---|---|
| 成功路径 | `should return {Type} when {method} succeeds` | mock 返回正常数据，验证返回值类型和内容 |
| 异常路径 | `should rethrow AppException when {method} fails` | mock 抛 AppException，验证异常传播 |
| 边界值 | `should handle empty result when {method} returns empty` | 空列表、null data 等边界场景；void 方法用边界输入值（如空字符串 id）验证 |

**Step 4 — Dry-run (AskUser)**
列出将生成的测试文件路径 + Mock 类清单 + 每个方法的测试用例清单。

使用 AskUserQuestion 提供三个选项：
1. **确认生成** — 进入 Step 5
2. **不要生成** — stop
3. **补充其他项** — 用户补充测试场景后重新 dry-run

**Step 5 — 写入测试文件**
按段 6 的代码模板生成测试文件。

**Step 6 — 自检**
跑段 8 checklist，逐项验证。

**Step 7 — 提示运行测试**
提示用户执行：
```bash
flutter test test/{test_file_name}
```

## 5. 输出产物

    {output_path}/                          — 默认 test/
    └── {class_name_snake_case}_test.dart   — 测试文件（如 message_repository_test.dart）

## 6. 代码模板

以 MessageRepository 为例（getList 方法）：

`````dart
// test/message_repository_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart' show CancelToken;
// ⚠️ package name 从 pubspec.yaml 的 name 字段读取,以下用 {package} 示意
import 'package:{package}/core/network/api_client.dart';
import 'package:{package}/core/network/models/page_req.dart';
import 'package:{package}/core/network/models/page_resp.dart';
import 'package:{package}/core/error/app_exception.dart';
import 'package:{package}/features/message/data/models/message.model.dart';
import 'package:{package}/features/message/data/repositories/message_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MessageRepository sut;
  late MockApiClient mockApi;

  setUpAll(() {
    // 为所有在 any(named:) 中使用的自定义类型注册 fallback
    registerFallbackValue(const PageReq());
    registerFallbackValue(CancelToken());
    // 按需追加: registerFallbackValue(OtherCustomType());
  });

  setUp(() {
    mockApi = MockApiClient();
    Get.put<ApiClient>(mockApi);
    sut = MessageRepository();
  });

  tearDown(() => Get.reset());

  group('getList', () {
    // 相对于项目根目录（flutter test 默认 CWD）
    final mockJson = jsonDecode(
      File('mock/message/list.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final mockData = mockJson['data'] as Map<String, dynamic>;
    final mockResp = PageResp<Message>(
      list: (mockData['list'] as List)
          .map((e) => Message.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: mockData['total'] as int,
      page: mockData['page'] as int,
      pageSize: mockData['pageSize'] as int,
    );

    test('should return PageResp<Message> when api call succeeds', () async {
      // given
      when(() => mockApi.getList<Message>(
            path: '/message/list',  // ⚠️ 不带 /api（baseUrl 已含 apiPrefix）
            pageReq: any(named: 'pageReq'),
            extraParams: any(named: 'extraParams'),
            mockKey: 'message/list',
            fromJson: any(named: 'fromJson'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => mockResp);

      // when
      final result = await sut.getList(pageReq: const PageReq());

      // then
      expect(result, isA<PageResp<Message>>());
      expect(result.list.length, mockResp.list.length);
      verify(() => mockApi.getList<Message>(
            path: '/message/list',  // ⚠️ 不带 /api（baseUrl 已含 apiPrefix）
            pageReq: any(named: 'pageReq'),
            extraParams: any(named: 'extraParams'),
            mockKey: 'message/list',
            fromJson: any(named: 'fromJson'),
            cancelToken: any(named: 'cancelToken'),
          )).called(1);
    });

    test('should rethrow AppException when api call fails', () async {
      // given
      when(() => mockApi.getList<Message>(
            path: '/message/list',  // ⚠️ 不带 /api（baseUrl 已含 apiPrefix）
            pageReq: any(named: 'pageReq'),
            extraParams: any(named: 'extraParams'),
            mockKey: 'message/list',
            fromJson: any(named: 'fromJson'),
            cancelToken: any(named: 'cancelToken'),
          )).thenThrow(ConnectTimeoutException());

      // when & then
      expect(
        () => sut.getList(pageReq: const PageReq()),
        throwsA(isA<AppException>()),
      );
    });

    test('should handle empty list when api returns no data', () async {
      // given
      final emptyResp = PageResp<Message>(
        list: [],
        total: 0,
        page: 1,
        pageSize: 20,
      );
      when(() => mockApi.getList<Message>(
            path: '/message/list',  // ⚠️ 不带 /api（baseUrl 已含 apiPrefix）
            pageReq: any(named: 'pageReq'),
            extraParams: any(named: 'extraParams'),
            mockKey: 'message/list',
            fromJson: any(named: 'fromJson'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => emptyResp);

      // when
      final result = await sut.getList(pageReq: const PageReq());

      // then
      expect(result.list, isEmpty);
      expect(result.total, 0);
    });
  });
}
`````

以下为其他 ApiClient 方法的测试模板片段：

`````dart
// get<T> 方法测试（单对象返回）
group('getDetail', () {
  test('should return Announce when api call succeeds', () async {
    // given
    final mockAnnounce = Announce.fromJson(jsonDecode(
      File('mock/announce/detail.json').readAsStringSync(),
    )['data'] as Map<String, dynamic>);
    when(() => mockApi.get<Announce>(
          path: '/announce/detail',
          query: any(named: 'query'),
          mockKey: 'announce/detail',
          fromJson: any(named: 'fromJson'),
          cancelToken: any(named: 'cancelToken'),
        )).thenAnswer((_) async => mockAnnounce);

    // when
    final result = await sut.getDetail(id: 'xxx');

    // then
    expect(result, isA<Announce>());
  });
});

// postJson<void> 方法测试（void 返回）
group('markRead', () {
  test('should complete without error when api call succeeds', () async {
    // given
    when(() => mockApi.postJson<void>(
          path: '/announce/markRead',
          data: any(named: 'data'),
          mockKey: 'announce/markRead',
          fromJson: any(named: 'fromJson'),
          cancelToken: any(named: 'cancelToken'),
        )).thenAnswer((_) async {});

    // when & then
    await expectLater(sut.markRead(id: 'xxx'), completes);
  });
});
`````

> **注意：** 以上补充片段仅展示成功路径。异常路径和边界值测试与 getList 示例模式相同——替换对应的空值/异常值即可（如 `get<T>` 异常用 `thenThrow(ConnectTimeoutException())`，边界用 `null` 返回值；`postJson<void>` 异常同理）。

**各 ApiClient 方法 `when()` 参数清单：**

| 方法 | when() 中必须包含的参数 |
|---|---|
| `getList<T>` | path, pageReq, extraParams, mockKey, fromJson, cancelToken |
| `get<T>` | path, query, mockKey, fromJson, cancelToken |
| `postJson<T/void>` | path, data, mockKey, fromJson, cancelToken |
| `postForm<T>` | path, data, mockKey, fromJson, cancelToken |
| `delete<T/void>` | path, data, mockKey, fromJson, cancelToken |

> ⚠️ **注意:** 只有 `getList<T>` 有 `extraParams` 参数。其他方法没有,when() 里写了会编译报错。`delete` 用 `data` 不是 `query`。

**模板规则：**
- 使用 `mocktail`（不是 mockito）
- 每个依赖一个 Mock 类: `class MockXxx extends Mock implements Xxx {}`
- `setUpAll` 中为自定义类型调用 `registerFallbackValue`（如 PageReq）
- `setUp` 中用 `Get.put` 注入 mock，`tearDown` 中 `Get.reset()`
- 多依赖类：每个依赖各 `Get.put` 注入
- SUT（System Under Test）命名为 `sut`
- 测试数据优先从 Mock JSON 文件读取（`mock/{module}/{action}.json`）；不存在时用内联数据
- 每个 test 遵循 given-when-then 注释结构
- 成功路径: `when(...).thenAnswer(...)` + `verify(...).called(1)`
- 异常路径: `when(...).thenThrow(AppException 具体子类)` + `throwsA(isA<AppException>())`（throwsA 用 `isA<AppException>()` 验证 rethrow 行为，when 中用具体子类如 `ConnectTimeoutException()`）
- 异常子类必须用 `app_exception.dart` 中的具体类（如 `ConnectTimeoutException()`、`BusinessException(bizCode:, bizMsg:)`），不能实例化抽象类
- 边界值: 空列表、零值、null 等
- `when()` 中 path/mockKey 用字面值，其余参数用 `any(named: 'xxx')`
- `when()` 必须包含被测方法调用的所有参数（含可选参数如 extraParams）
- **path 不带 `/api` 前缀** — Repository 的 path 不含 /api,测试里 when() 的 path 必须与 Repository 一致
- **package name 从 pubspec.yaml 读取** — import 路径不要硬编码 `package:app`,要读 pubspec.yaml 的 `name` 字段

> ⚠️ **高频错误警告:**
> - `when()` 里的 path 必须和 Repository 实际调用的 path 完全一致,不带 `/api`
> - `AppException` 是 sealed class,不能直接 `AppException(message: ...)`,用具体子类如 `ConnectTimeoutException()`
> - `registerFallbackValue` 必须放 `setUpAll` 里,不是 `setUp`

## 7. 不做什么

- ❌ 不自动运行测试（用户手动 `flutter test`）
- ❌ 不修改被测代码
- ❌ 不修改 pubspec.yaml
- ❌ 不生成集成测试（只生成单元测试）
- ❌ 不生成 Widget 测试（只测业务逻辑）
- ❌ 不覆盖已有测试文件（除非用户明确要求）

## 8. 自检 Checklist

- [ ] 使用 `mocktail`（非 mockito）
- [ ] 每个依赖有对应的 Mock 类
- [ ] `setUpAll` 中为每个 `any(named:)` 使用的自定义类型调用 `registerFallbackValue`
- [ ] `setUp` 注入 mock，`tearDown` 调用 `Get.reset()`
- [ ] 每个 public 方法有成功/异常/边界值三类测试
- [ ] 异常路径 `throwsA` 使用 `isA<AppException>()` 或其子类
- [ ] 异常子类使用 `app_exception.dart` 中的具体类，非抽象类
- [ ] `when()` 中 path/mockKey 用字面值匹配
- [ ] `when()` 包含所有参数（含可选参数如 extraParams）
- [ ] Mock JSON 文件存在时用作测试数据源
- [ ] given-when-then 注释结构完整
- [ ] import 路径正确

## 9. 失败处理

**何时 ask user：**
- 依赖类型不确定如何 mock 时
- 检测到将覆盖已有测试文件时
- 代码结构复杂，无法自动识别依赖时

**何时 stop：**
- 文件路径不存在
- 代码片段无法解析（非 Dart 代码）
- 被测类无 public 方法

**何时 rollback：**
- 自检失败 → 删除本次新增的测试文件
- 写入中失败 → 删除不完整文件

## 10. 联动

**成功后建议：**
> "测试文件生成完成。运行 `flutter test test/{file}` 验证。"

**失败后回退：**
> "生成失败。请检查被测代码结构，确保类有 public 方法和可识别的依赖。"

**上游：** flutter-api-gen / flutter-page-gen
**下游：** 无（流水线终点）
