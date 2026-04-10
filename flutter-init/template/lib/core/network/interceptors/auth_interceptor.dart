import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import '../../error/app_exception.dart';

/// 鉴权拦截器
/// - 注入 token
/// - 处理 401 / 业务码 2002 (最多重试 1 次,防死循环)
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this.config);

  final AppConfig config;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // TODO: 注入 token
    // final token = Get.find<TokenService>().token;
    // options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 检查重试计数 (extra 中存)
    final retryCount = (err.requestOptions.extra['_authRetryCount'] as int?) ?? 0;

    // 401 或 2002 → 重试 1 次
    final shouldRetry = (err.response?.statusCode == 401) && retryCount == 0;
    if (shouldRetry) {
      // TODO: 刷新 token,然后重发
      // 防死循环: 标记 retry count
      err.requestOptions.extra['_authRetryCount'] = retryCount + 1;
      // 这里简化: 直接抛 AuthException
      handler.reject(DioException(
        requestOptions: err.requestOptions,
        error: AuthException(cause: err),
      ));
      return;
    }

    handler.next(err);
  }
}
