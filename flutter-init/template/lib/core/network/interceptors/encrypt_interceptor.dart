import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import '../../crypto/aes_dynamic.dart';
import '../../error/app_exception.dart';

/// 加密拦截器
/// - 请求 body: JSON → AES-CBC 动态密钥加密
/// - 响应 bytes: AES-CBC 解密 → GZIP 解压 → JSON
class EncryptInterceptor extends Interceptor {
  EncryptInterceptor(this.config);

  final AppConfig config;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final encrypt = options.extra['encrypt'] as bool? ?? true;
    if (!encrypt) {
      handler.next(options);
      return;
    }

    final requestId = options.extra['_requestId'] as String?;
    if (requestId == null) {
      handler.reject(DioException(
        requestOptions: options,
        error: EncryptException(cause: 'Missing requestId in extra'),
      ));
      return;
    }

    try {
      final raw = jsonEncode(options.data ?? {});
      final encrypted = AesDynamicUtil.encryptRaw(raw, requestId, config.apiKey);
      options.data = encrypted;
      handler.next(options);
    } catch (e, s) {
      handler.reject(DioException(
        requestOptions: options,
        error: EncryptException(cause: e, stackTrace: s),
      ));
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final encrypt = response.requestOptions.extra['encrypt'] as bool? ?? true;
    if (!encrypt) {
      handler.next(response);
      return;
    }

    final requestId = response.requestOptions.extra['_requestId'] as String?;
    if (requestId == null) {
      handler.reject(DioException(
        requestOptions: response.requestOptions,
        error: DecryptException(cause: 'Missing requestId'),
      ));
      return;
    }

    try {
      final bytes = response.data as Uint8List;
      if (bytes.isEmpty) {
        response.data = null;
        handler.next(response);
        return;
      }
      final jsonStr = AesDynamicUtil.decryptRaw(bytes, requestId, config.apiKey);
      response.data = jsonDecode(jsonStr);
      handler.next(response);
    } catch (e, s) {
      handler.reject(DioException(
        requestOptions: response.requestOptions,
        error: DecryptException(cause: e, stackTrace: s),
      ));
    }
  }
}
