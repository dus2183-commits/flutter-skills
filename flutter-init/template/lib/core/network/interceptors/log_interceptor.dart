import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';

/// 网络日志拦截器
class LogInterceptor extends dio.Interceptor {
  @override
  void onRequest(dio.RequestOptions options, dio.RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('🌐 → ${options.method} ${options.uri}');
      if (options.data != null) {
        debugPrint('   data: ${options.data}');
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(dio.Response response, dio.ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('🌐 ← ${response.statusCode} ${response.requestOptions.uri}');
    }
    handler.next(response);
  }

  @override
  void onError(dio.DioException err, dio.ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('🌐 ✗ ${err.requestOptions.uri}: ${err.message}');
    }
    handler.next(err);
  }
}
