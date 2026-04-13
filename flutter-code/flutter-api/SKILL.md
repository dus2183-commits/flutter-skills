---
name: flutter-api
description: 用于本项目 Flutter 网络层设计，包括 Dio 封装、拦截器、Repository 模式和错误处理规范。触发场景：用户说"设计网络层"、"封装接口"、"接口联调"、"处理请求错误"。
---

# 网络层设计（flutter-api）

## 概述

为本项目定义基于 Dio 的网络层架构，采用 **HttpClient → Repository → Controller** 三层结构，统一处理认证、错误和日志。

## 整体架构

```
api/
├── http_client.dart              # Dio 单例 + 基础配置
├── interceptors/
│   ├── auth_interceptor.dart     # Token 自动注入 + 401 处理
│   ├── error_interceptor.dart    # 业务错误码 + 网络异常统一处理
│   └── log_interceptor.dart      # 请求/响应日志（仅 debug）
├── repositories/
│   └── [module]_repository.dart  # 模块接口封装
└── models/
    └── api_response.dart         # 通用响应结构
```

## 输出内容

### 1. 通用响应模型（api/models/api_response.dart）

```dart
/// 服务端统一响应结构
///
/// 对应后端格式：{ "code": 0, "msg": "success", "data": {...} }
class ApiResponse<T> {
  final int code;
  final String msg;
  final T? data;

  const ApiResponse({
    required this.code,
    required this.msg,
    this.data,
  });

  bool get isSuccess => code == 0;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json)? fromJsonT,
  ) {
    return ApiResponse<T>(
      code: json['code'] as int,
      msg: json['msg'] as String,
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : null,
    );
  }
}
```

### 2. Dio 单例（api/http_client.dart）

```dart
import 'package:dio/dio.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/log_interceptor.dart';

class HttpClient {
  HttpClient._();

  static final instance = HttpClient._();

  late final Dio dio = _createDio();

  Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        // baseUrl 通过 --dart-define 注入，不硬编码
        baseUrl: const String.fromEnvironment('API_BASE_URL'),
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.addAll([
      AuthInterceptor(),
      AppErrorInterceptor(),
      if (kDebugMode) AppLogInterceptor(),
    ]);

    return dio;
  }
}
```

**规则：**
- `baseUrl` 通过 `--dart-define=API_BASE_URL=xxx` 注入，区分开发/生产环境
- 不在 Repository 中 `new Dio()`，统一使用 `HttpClient.instance.dio`
- 日志拦截器仅在 debug 模式启用

### 3. Auth 拦截器（interceptors/auth_interceptor.dart）

```dart
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:your_app/common/services/auth_service.dart';
import 'package:your_app/routes/app_routes.dart';

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = Get.find<AuthService>().token;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Token 失效，清除登录态并跳回登录页
      Get.find<AuthService>().logout();
    }
    handler.next(err);
  }
}
```

### 4. 错误拦截器（interceptors/error_interceptor.dart）

```dart
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

class AppErrorInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final data = response.data;
    // HTTP 200 但业务 code 非 0，转为 DioException 统一处理
    if (data is Map && (data['code'] as int? ?? 0) != 0) {
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: data['msg'] ?? '请求失败',
        ),
        true,
      );
      return;
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final message = _parseError(err);
    // 全局 Toast 提示，Controller 无需重复处理错误文案
    Get.snackbar('提示', message, snackPosition: SnackPosition.bottom);
    handler.next(err);
  }

  String _parseError(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return '网络超时，请稍后重试';
      case DioExceptionType.badResponse:
        return err.error?.toString() ?? '服务器错误';
      case DioExceptionType.connectionError:
        return '网络连接失败，请检查网络';
      default:
        return '未知错误，请稍后重试';
    }
  }
}
```

### 5. 日志拦截器（interceptors/log_interceptor.dart）

```dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class AppLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('→ ${options.method} ${options.uri}');
    debugPrint('  headers: ${options.headers}');
    if (options.data != null) debugPrint('  body: ${options.data}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('← ${response.statusCode} ${response.requestOptions.uri}');
    debugPrint('  data: ${response.data}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('✗ ${err.requestOptions.uri} — ${err.message}');
    handler.next(err);
  }
}
```

### 6. Repository 模板（api/repositories/[module]_repository.dart）

```dart
import 'package:dio/dio.dart';
import 'package:your_app/api/http_client.dart';
import 'package:your_app/api/models/api_response.dart';
import 'package:your_app/features/[module]/models/[module]_model.dart';

class [Module]Repository {
  final _dio = HttpClient.instance.dio;

  /// 获取列表（分页）
  Future<List<[Module]Model>> fetchList({
    required int page,
    int pageSize = 20,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/[module]/list',
      data: {'page': page, 'pageSize': pageSize},
    );
    final result = ApiResponse<List<[Module]Model>>.fromJson(
      response.data!,
      (json) => (json as List)
          .map((e) => [Module]Model.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    return result.data ?? [];
  }

  /// 获取详情
  Future<[Module]Model?> fetchDetail(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/[module]/detail',
      queryParameters: {'id': id},
    );
    final result = ApiResponse<[Module]Model>.fromJson(
      response.data!,
      (json) => [Module]Model.fromJson(json as Map<String, dynamic>),
    );
    return result.data;
  }

  /// 新增
  Future<void> add([Module]Model model) async {
    await _dio.post('/[module]/add', data: model.toJson());
  }

  /// 更新
  Future<void> update(String id, Map<String, dynamic> fields) async {
    await _dio.post('/[module]/update', data: {'id': id, ...fields});
  }

  /// 删除
  Future<void> delete(String id) async {
    await _dio.delete('/[module]/del', queryParameters: {'id': id});
  }
}
```

**规则：**
- Repository 只负责网络请求和数据反序列化，不处理业务逻辑
- 所有接口路径在 Repository 中定义，不散落在 Controller
- 使用强类型 Model，不用 `Map<String, dynamic>` 直接传递给 Controller
- 分页接口统一使用 `page` + `pageSize` 参数命名

### 7. Controller 中调用规范

```dart
Future<void> loadList({bool refresh = false}) async {
  if (refresh) {
    _currentPage = 1;
    list.clear();
  }

  isLoading.value = true;
  try {
    final result = await _repository.fetchList(page: _currentPage);
    list.addAll(result);
    _currentPage++;
  } on DioException catch (e) {
    // 错误 Toast 已在拦截器处理，这里只处理 UI 状态
    debugPrint('[Module] loadList error: $e');
  } finally {
    isLoading.value = false;
  }
}
```

**规则：**
- 捕获 `DioException`，不 catch 宽泛的 `Exception` 吞掉所有错误
- 全局 Toast/Snackbar 在拦截器中统一处理，Controller 只管 UI 状态
- 网络请求必须在 `try/finally` 中处理 `isLoading` 状态，避免 loading 卡死

## 环境配置

通过 `--dart-define` 区分环境，不使用明文 `.env` 文件：

```bash
# 开发环境
flutter run --dart-define=API_BASE_URL=https://dev-api.example.com

# 生产构建
flutter build apk --dart-define=API_BASE_URL=https://api.example.com
flutter build ipa --dart-define=API_BASE_URL=https://api.example.com
```

也可在 VS Code `launch.json` 中配置：

```json
{
  "configurations": [
    {
      "name": "Dev",
      "request": "launch",
      "type": "dart",
      "args": ["--dart-define=API_BASE_URL=https://dev-api.example.com"]
    }
  ]
}
```

## 完成后联动

> "网络层设计完成。可使用 `flutter-mcp` skill 对接设计稿生成 UI，或使用 `flutter-review` skill 评审整体方案。"
