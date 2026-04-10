// ApiClient - 全局网络客户端
// 改造自 yc141 lib/core/http/http_api.dart
//
// 区别:
//   1. 改成 GetxService 可注入(yc141 用 static)
//   2. 拆出 6 个 Interceptor (yc141 都塞在 request())
//   3. 加 MockInterceptor (yc141 没有)
//   4. catch AppException 不抛字符串
//   5. 防 2002 死循环 (yc141 直接递归)
//
// 详细接口契约见 _design/api_client_signature.dart

import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide FormData, MultipartFile, Response;

import '../config/app_config.dart';
import '../error/app_exception.dart';
import '../mock/mock_loader.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/encrypt_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/log_interceptor.dart' as my_log;
import 'interceptors/mock_interceptor.dart';
import 'interceptors/sign_interceptor.dart';
import 'models/page_req.dart';
import 'models/page_resp.dart';

class ApiClient extends GetxService {
  late Dio _dio;
  late AppConfig _config;
  late MockLoader _mockLoader;

  Future<ApiClient> init() async {
    _config = Get.find<AppConfig>();
    _mockLoader = Get.find<MockLoader>();

    _dio = Dio(BaseOptions(
      baseUrl: _config.currentLine.url + _config.apiPrefix,
      contentType: Headers.formUrlEncodedContentType,
      responseType: ResponseType.bytes, // ★ 关键: 响应是加密的二进制
      validateStatus: (status) => true,
      sendTimeout: const Duration(seconds: 10),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    // 6 个 Interceptor 顺序: log → mock → auth → sign → encrypt → error
    _dio.interceptors.addAll([
      my_log.LogInterceptor(),
      MockInterceptor(_mockLoader), // ★ 我们的增量 (yc141 没有)
      AuthInterceptor(_config),
      SignInterceptor(_config),
      EncryptInterceptor(_config),
      ErrorInterceptor(),
    ]);

    return this;
  }

  /// 取消所有进行中的请求
  void cancelAll() {
    _dio.close(force: false);
  }

  // ─────────────────────────────────────────────────────
  // GET
  // ─────────────────────────────────────────────────────

  Future<T> get<T>({
    required String path,
    Map<String, dynamic>? query,
    required String mockKey,
    required T Function(dynamic) fromJson,
    CancelToken? cancelToken,
    bool encrypt = true,
  }) async {
    try {
      final resp = await _dio.get(
        path,
        queryParameters: query,
        cancelToken: cancelToken,
        options: Options(
          extra: {'mockKey': mockKey, 'encrypt': encrypt},
        ),
      );
      return fromJson(resp.data);
    } on AppException {
      rethrow;
    } catch (e, s) {
      throw UnknownException(message: e.toString(), cause: e, stackTrace: s);
    }
  }

  // ─────────────────────────────────────────────────────
  // POST JSON
  // ─────────────────────────────────────────────────────

  Future<T> postJson<T>({
    required String path,
    required Map<String, dynamic> data,
    required String mockKey,
    required T Function(dynamic) fromJson,
    CancelToken? cancelToken,
    bool encrypt = true,
  }) async {
    try {
      final resp = await _dio.post(
        path,
        data: data,
        cancelToken: cancelToken,
        options: Options(
          contentType: Headers.jsonContentType,
          extra: {'mockKey': mockKey, 'encrypt': encrypt},
        ),
      );
      return fromJson(resp.data);
    } on AppException {
      rethrow;
    } catch (e, s) {
      throw UnknownException(message: e.toString(), cause: e, stackTrace: s);
    }
  }

  // ─────────────────────────────────────────────────────
  // POST Form (yc141 默认走这个)
  // ─────────────────────────────────────────────────────

  Future<T> postForm<T>({
    required String path,
    required Map<String, dynamic> data,
    required String mockKey,
    required T Function(dynamic) fromJson,
    CancelToken? cancelToken,
    bool encrypt = true,
  }) async {
    try {
      final resp = await _dio.post(
        path,
        data: data,
        cancelToken: cancelToken,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          extra: {'mockKey': mockKey, 'encrypt': encrypt},
        ),
      );
      return fromJson(resp.data);
    } on AppException {
      rethrow;
    } catch (e, s) {
      throw UnknownException(message: e.toString(), cause: e, stackTrace: s);
    }
  }

  // ─────────────────────────────────────────────────────
  // List (自动包装 PageResp)
  // ─────────────────────────────────────────────────────

  Future<PageResp<T>> getList<T>({
    required String path,
    required PageReq pageReq,
    Map<String, dynamic>? extraParams,
    required String mockKey,
    required T Function(dynamic) fromJson,
    CancelToken? cancelToken,
    bool encrypt = true,
  }) async {
    final data = {...pageReq.toJson(), ...?extraParams};
    final raw = await postJson<Map<String, dynamic>>(
      path: path,
      data: data,
      mockKey: mockKey,
      fromJson: (json) => json as Map<String, dynamic>,
      cancelToken: cancelToken,
      encrypt: encrypt,
    );
    return PageResp<T>.fromJson(raw, fromJson);
  }

  // ─────────────────────────────────────────────────────
  // Delete
  // ─────────────────────────────────────────────────────

  Future<T> delete<T>({
    required String path,
    Map<String, dynamic>? data,
    required String mockKey,
    required T Function(dynamic) fromJson,
    CancelToken? cancelToken,
    bool encrypt = true,
  }) async {
    try {
      final resp = await _dio.delete(
        path,
        data: data,
        cancelToken: cancelToken,
        options: Options(extra: {'mockKey': mockKey, 'encrypt': encrypt}),
      );
      return fromJson(resp.data);
    } on AppException {
      rethrow;
    } catch (e, s) {
      throw UnknownException(message: e.toString(), cause: e, stackTrace: s);
    }
  }

  // ─────────────────────────────────────────────────────
  // Upload (用 XFile 三端兼容)
  // ─────────────────────────────────────────────────────

  Future<UploadResp> upload({
    required String path,
    required XFile file,
    Map<String, dynamic>? extraParams,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final formData = FormData.fromMap({
        ...?extraParams,
        'file': MultipartFile.fromBytes(
          await file.readAsBytes(),
          filename: file.name,
        ),
      });

      final resp = await _dio.post<Map<String, dynamic>>(
        path,
        data: formData,
        cancelToken: cancelToken,
        onSendProgress: onProgress,
      );

      // 后端约定: 上传成功后返回 { url: '...', key: '...' }
      // 不同后端字段不同,业务方可在 Repository 层包装
      final data = resp.data ?? {};
      return UploadResp(
        url: (data['url'] as String?) ?? '',
        key: data['key'] as String?,
        sizeBytes: await file.length(),
      );
    } on AppException {
      rethrow;
    } catch (e, s) {
      throw UnknownException(message: e.toString(), cause: e, stackTrace: s);
    }
  }

  // ─────────────────────────────────────────────────────
  // Diagnostics
  // ─────────────────────────────────────────────────────

  bool get isMockEnabled => MockLoader.enabled;
  String get currentBaseUrl => _dio.options.baseUrl;
}

class UploadResp {
  final String url;
  final String? key;
  final int sizeBytes;

  const UploadResp({required this.url, this.key, required this.sizeBytes});
}
