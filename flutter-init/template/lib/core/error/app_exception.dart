// AppException 异常体系
// 所有业务代码只 catch AppException 或其子类,不 catch String
//
// 详细设计见 _design/app_exception.dart (skill 仓库)

/// 应用异常基类。所有 catch 应至少 catch 这个。
sealed class AppException implements Exception {
  String get userMessage;
  String get devMessage;
  int get code;
  Object? get cause;
  StackTrace? get stackTrace;

  @override
  String toString() => 'AppException($code): $devMessage';
}

// ───────────────────────────────────────────────────────────
// 1. 网络层异常 (10000-19999)
// ───────────────────────────────────────────────────────────

abstract class NetworkException extends AppException {}

class ConnectTimeoutException extends NetworkException {
  @override
  final int code = 10001;
  @override
  final Object? cause;
  @override
  final StackTrace? stackTrace;

  ConnectTimeoutException({this.cause, this.stackTrace});

  @override
  String get userMessage => '网络连接超时,请检查网络';
  @override
  String get devMessage => 'Connection timeout';
}

class ReceiveTimeoutException extends NetworkException {
  @override
  final int code = 10002;
  @override
  final Object? cause;
  @override
  final StackTrace? stackTrace;

  ReceiveTimeoutException({this.cause, this.stackTrace});

  @override
  String get userMessage => '响应超时,请重试';
  @override
  String get devMessage => 'Receive timeout';
}

class HttpStatusException extends NetworkException {
  final int httpCode;
  @override
  int get code => 10003;
  @override
  final Object? cause;
  @override
  final StackTrace? stackTrace;

  HttpStatusException({required this.httpCode, this.cause, this.stackTrace});

  @override
  String get userMessage => '服务器异常 ($httpCode)';
  @override
  String get devMessage => 'HTTP $httpCode';
}

class NoNetworkException extends NetworkException {
  @override
  final int code = 10004;
  @override
  final Object? cause;
  @override
  final StackTrace? stackTrace;

  NoNetworkException({this.cause, this.stackTrace});

  @override
  String get userMessage => '当前无网络连接';
  @override
  String get devMessage => 'No network';
}

// ───────────────────────────────────────────────────────────
// 2. 业务层异常 (20000-29999)
// ───────────────────────────────────────────────────────────

class BusinessException extends AppException {
  final int bizCode;
  final String bizMsg;

  @override
  int get code => 20000 + bizCode;
  @override
  final Object? cause;
  @override
  final StackTrace? stackTrace;

  BusinessException({
    required this.bizCode,
    required this.bizMsg,
    this.cause,
    this.stackTrace,
  });

  @override
  String get userMessage => bizMsg;
  @override
  String get devMessage => 'Business error: $bizCode - $bizMsg';
}

// ───────────────────────────────────────────────────────────
// 3. 鉴权异常 (30000-39999)
// ───────────────────────────────────────────────────────────

class AuthException extends AppException {
  @override
  final int code = 30001;
  @override
  final Object? cause;
  @override
  final StackTrace? stackTrace;

  AuthException({this.cause, this.stackTrace});

  @override
  String get userMessage => '请先登录';
  @override
  String get devMessage => 'Authentication required';
}

class TokenExpiredException extends AppException {
  @override
  final int code = 30002;
  @override
  final Object? cause;
  @override
  final StackTrace? stackTrace;

  TokenExpiredException({this.cause, this.stackTrace});

  @override
  String get userMessage => '登录已过期,请重新登录';
  @override
  String get devMessage => 'Token expired';
}

// ───────────────────────────────────────────────────────────
// 4. 加密层异常 (40000-49999)
// ───────────────────────────────────────────────────────────

class EncryptException extends AppException {
  @override
  final int code = 40001;
  @override
  final Object? cause;
  @override
  final StackTrace? stackTrace;

  EncryptException({this.cause, this.stackTrace});

  @override
  String get userMessage => '请求异常';
  @override
  String get devMessage => 'Encryption failed';
}

class DecryptException extends AppException {
  @override
  final int code = 40002;
  @override
  final Object? cause;
  @override
  final StackTrace? stackTrace;

  DecryptException({this.cause, this.stackTrace});

  @override
  String get userMessage => '响应异常';
  @override
  String get devMessage => 'Decryption failed';
}

// ───────────────────────────────────────────────────────────
// 5. 数据解析异常 (50000-59999)
// ───────────────────────────────────────────────────────────

class ParseException extends AppException {
  final String? field;

  @override
  final int code = 50001;
  @override
  final Object? cause;
  @override
  final StackTrace? stackTrace;

  ParseException({this.field, this.cause, this.stackTrace});

  @override
  String get userMessage => '数据格式错误';
  @override
  String get devMessage =>
      field != null ? 'Parse failed: field=$field' : 'Parse failed';
}

// ───────────────────────────────────────────────────────────
// 6. 取消异常 (60000)
// ───────────────────────────────────────────────────────────

class CancelException extends AppException {
  @override
  final int code = 60001;
  @override
  final Object? cause;
  @override
  final StackTrace? stackTrace;

  CancelException({this.cause, this.stackTrace});

  @override
  String get userMessage => '';
  @override
  String get devMessage => 'Request cancelled';
}

// ───────────────────────────────────────────────────────────
// 7. 未知异常 (99999)
// ───────────────────────────────────────────────────────────

class UnknownException extends AppException {
  final String message;

  @override
  final int code = 99999;
  @override
  final Object? cause;
  @override
  final StackTrace? stackTrace;

  UnknownException({
    required this.message,
    this.cause,
    this.stackTrace,
  });

  @override
  String get userMessage => '未知错误';
  @override
  String get devMessage => 'Unknown: $message';
}
