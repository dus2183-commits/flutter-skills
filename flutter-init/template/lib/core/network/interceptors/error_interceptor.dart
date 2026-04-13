import 'dart:convert';

import 'package:dio/dio.dart';

import '../../error/app_exception.dart';

/// 错误拦截器
/// - 新格式: {code: 0, data: {...}, msg: "ok"} → 提取 data / 抛 BusinessException
/// - 旧格式: {status: 'y'/'n', data: {...}} → 兼容保留
/// - dio 异常 → AppException 子类
class ErrorInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    var data = response.data;

    // DEBUG_ENCRYPT=true + static 模式时响应体是 String，先 JSON decode
    if (data is String) {
      if (data.isEmpty) {
        handler.next(response);
        return;
      }
      try {
        data = jsonDecode(data);
      } catch (_) {
        // 非 JSON 字符串，直接透传
        handler.next(response);
        return;
      }
    }

    if (data is Map<String, dynamic>) {
      // 新格式: {code: int, data: any, msg: string}
      if (data.containsKey('code') && data.containsKey('msg')) {
        final code = data['code'] as int? ?? -1;
        if (code != 0) {
          final msg = data['msg'] as String? ?? '业务异常';
          handler.reject(DioException(
            requestOptions: response.requestOptions,
            error: BusinessException(bizCode: code, bizMsg: msg),
          ));
          return;
        }
        response.data = data['data'];
        handler.next(response);
        return;
      }

      // 旧格式: {status: 'y'/'n', data: any} (yc141 约定)
      if (data['status'] == 'n') {
        final code = data['errorCode'] as int? ?? -1;
        final msg = data['error'] as String? ?? '业务异常';
        handler.reject(DioException(
          requestOptions: response.requestOptions,
          error: BusinessException(bizCode: code, bizMsg: msg),
        ));
        return;
      }
      if (data.containsKey('status')) {
        response.data = data['data'];
      }
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
