import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:uuid/uuid.dart';

import '../../config/app_config.dart';
import '../../crypto/hash_util.dart';

/// 签名拦截器
/// 计算 sign = hash(apiHeaderKey | sessionId | requestId | time | url)
class SignInterceptor extends Interceptor {
  SignInterceptor(this.config);

  final AppConfig config;
  static const _uuid = Uuid();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final requestId = _uuid.v4();
    final time = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final url = options.uri.toString();

    final signRaw = '${config.apiHeaderKey}|${config.sessionId}|$requestId|$time|$url';
    final sign = '${HashUtil.hash(signRaw)}-$time';

    options.headers.addAll({
      'version': config.apiVersion,
      'deviceType': _platform(),
      'time': time,
      'sign': sign,
      'requestId': requestId,
      'sessionId': config.sessionId,
    });

    // 把 requestId 存到 extra,加密拦截器要用
    options.extra['_requestId'] = requestId;

    handler.next(options);
  }

  String _platform() {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'android';
  }
}
