import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import '../../crypto/aes_dynamic.dart';
import '../../crypto/aes_static.dart';
import '../../error/app_exception.dart';

/// 加密模式
enum EncryptMode {
  /// 动态密钥: requestId + apiKey → HMAC-SHA256 → AES-CBC + GZIP (yc141 原始方案)
  dynamic,

  /// 静态密钥: 固定 secretKey → AES-CBC → Base64 (后端新规范)
  /// - 请求 Content-Type: text/plain
  /// - 请求 Body: Base64 裸密文
  /// - 响应 Body: Base64 裸密文
  /// - 调试: X-Encrypt: 1 跳过加解密
  static,
}

/// 加密拦截器
///
/// 支持两种加密模式:
/// - [EncryptMode.dynamic]: yc141 原始方案 (requestId + GZIP)
/// - [EncryptMode.static]: 后端新规范 (固定 key + Base64)
///
/// 通过 [AppConfig.encryptMode] 控制使用哪种。
/// 调试模式 ([AppConfig.debugEncrypt] = true) 时:
///   - static 模式: 加 X-Encrypt: 1 请求头,Body 传明文 JSON
///   - dynamic 模式: encrypt=false 跳过加解密
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

    // 调试模式
    if (config.debugEncrypt) {
      if (config.encryptMode == EncryptMode.static) {
        options.headers['X-Encrypt'] = '1';
        options.contentType = Headers.jsonContentType;
      }
      handler.next(options);
      return;
    }

    try {
      switch (config.encryptMode) {
        case EncryptMode.dynamic:
          _encryptDynamic(options);
        case EncryptMode.static:
          _encryptStatic(options);
      }
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
    if (!encrypt || config.debugEncrypt) {
      handler.next(response);
      return;
    }

    try {
      switch (config.encryptMode) {
        case EncryptMode.dynamic:
          _decryptDynamic(response);
        case EncryptMode.static:
          _decryptStatic(response);
      }
      handler.next(response);
    } catch (e, s) {
      handler.reject(DioException(
        requestOptions: response.requestOptions,
        error: DecryptException(cause: e, stackTrace: s),
      ));
    }
  }

  // ─── 动态密钥 (yc141) ───

  void _encryptDynamic(RequestOptions options) {
    final requestId = options.extra['_requestId'] as String?;
    if (requestId == null) {
      throw EncryptException(cause: 'Missing requestId in extra');
    }
    final raw = jsonEncode(options.data ?? {});
    options.data = AesDynamicUtil.encryptRaw(raw, requestId, config.apiKey);
  }

  void _decryptDynamic(Response response) {
    final requestId = response.requestOptions.extra['_requestId'] as String?;
    if (requestId == null) {
      throw DecryptException(cause: 'Missing requestId');
    }
    final bytes = response.data as Uint8List;
    if (bytes.isEmpty) {
      response.data = null;
      return;
    }
    final jsonStr = AesDynamicUtil.decryptRaw(bytes, requestId, config.apiKey);
    response.data = jsonDecode(jsonStr);
  }

  // ─── 静态密钥 (后端新规范) ───

  void _encryptStatic(RequestOptions options) {
    final raw = jsonEncode(options.data ?? {});
    final cipher = AesStaticUtil.encrypt(raw, config.staticEncryptKey);
    options.data = cipher; // Base64 裸密文
    options.contentType = 'text/plain'; // 后端要求
  }

  void _decryptStatic(Response response) {
    final data = response.data;
    String base64Cipher;

    if (data is Uint8List) {
      base64Cipher = utf8.decode(data);
    } else if (data is String) {
      base64Cipher = data;
    } else {
      throw DecryptException(cause: 'Unexpected response type: ${data.runtimeType}');
    }

    if (base64Cipher.isEmpty) {
      response.data = null;
      return;
    }

    final jsonStr = AesStaticUtil.decrypt(base64Cipher, config.staticEncryptKey);
    response.data = jsonDecode(jsonStr);
  }
}
