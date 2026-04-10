import 'package:dio/dio.dart';

import '../../error/app_exception.dart';

/// 错误拦截器
/// - dio 异常 → AppException 子类
/// - 业务错误码 status: 'n' → BusinessException
class ErrorInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final data = response.data;

    // 业务错误码处理 (yc141 约定: status: 'y'/'n')
    if (data is Map<String, dynamic>) {
      if (data['status'] == 'n') {
        final code = data['errorCode'] as int? ?? -1;
        final msg = data['error'] as String? ?? '业务异常';
        handler.reject(DioException(
          requestOptions: response.requestOptions,
          error: BusinessException(bizCode: code, bizMsg: msg),
        ));
        return;
      }

      // status: 'y' → 提取 data 字段
      response.data = data['data'];
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 已经是 AppException 直接放行
    if (err.error is AppException) {
      handler.reject(err);
      return;
    }

    // 转换 DioException → AppException
    AppException exception;
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
        exception = ConnectTimeoutException(cause: err);
        break;
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        exception = ReceiveTimeoutException(cause: err);
        break;
      case DioExceptionType.cancel:
        exception = CancelException(cause: err);
        break;
      case DioExceptionType.connectionError:
        exception = NoNetworkException(cause: err);
        break;
      case DioExceptionType.badResponse:
        exception = HttpStatusException(
          httpCode: err.response?.statusCode ?? 0,
          cause: err,
        );
        break;
      default:
        exception = UnknownException(
          message: err.message ?? 'Unknown error',
          cause: err,
        );
    }

    handler.reject(DioException(
      requestOptions: err.requestOptions,
      error: exception,
      response: err.response,
      type: err.type,
    ));
  }
}
