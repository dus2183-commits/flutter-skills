// ═══════════════════════════════════════════════════════════════════════════
// AppException 异常体系
// ───────────────────────────────────────────────────────────────────────────
// 全局统一异常类。所有业务代码只 catch AppException 或其子类,不 catch String。
//
// 设计原则:
//   1. sealed class — 所有异常都是子类,switch 时编译器强制 exhaustive
//   2. userMessage — 给用户看的文案(可国际化)
//   3. devMessage — 给开发看的英文/堆栈
//   4. code — 数字错误码(用于 telemetry 和后端对账)
//   5. cause — 原始异常(可选,用于堆栈追溯)
//
// 与 yc141 的区别:
//   yc141 的 HttpApi 用 throw '错误信息字符串',无类型,无层级,无追溯。
//   我们改成 sealed class 体系,业务可以精确 catch 不同类型。
// ═══════════════════════════════════════════════════════════════════════════

/// 应用异常基类。所有 catch 应至少 catch 这个。
sealed class AppException implements Exception {
  /// 给用户看的文案(中文,可国际化)。
  String get userMessage;

  /// 给开发看的英文消息。
  String get devMessage;

  /// 数字错误码。
  int get code;

  /// 原始异常(如有)。
  Object? get cause;

  /// 堆栈(如有)。
  StackTrace? get stackTrace;

  @override
  String toString() => 'AppException($code): $devMessage';
}

// ═══════════════════════════════════════════════════════════════════════════
// 1. 网络层异常 (10000-19999)
// ═══════════════════════════════════════════════════════════════════════════

/// 网络层异常基类。
abstract class NetworkException extends AppException {}

/// 连接超时(无法触达服务器)。
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

/// 接收响应超时。
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

/// HTTP 状态码错误(4xx/5xx)。
class HttpStatusException extends NetworkException {
  final int httpCode;

  @override
  int get code => 10003;
  @override
  final Object? cause;
  @override
  final StackTrace? stackTrace;

  HttpStatusException({
    required this.httpCode,
    this.cause,
    this.stackTrace,
  });

  @override
  String get userMessage => '服务器异常 ($httpCode)';
  @override
  String get devMessage => 'HTTP $httpCode';
}

/// 无网络连接。
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

// ═══════════════════════════════════════════════════════════════════════════
// 2. 业务层异常 (20000-29999) — 后端返回 status:n
// ═══════════════════════════════════════════════════════════════════════════

/// 业务错误(后端 status=n,errorCode=N)。
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

// ═══════════════════════════════════════════════════════════════════════════
// 3. 鉴权异常 (30000-39999)
// ═══════════════════════════════════════════════════════════════════════════

/// 未登录(对应 yc141 的 errorCode 2002)。
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

/// Token 过期。
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

/// 权限不足。
class PermissionDeniedException extends AppException {
  @override
  final int code = 30003;
  @override
  final Object? cause;
  @override
  final StackTrace? stackTrace;

  PermissionDeniedException({this.cause, this.stackTrace});

  @override
  String get userMessage => '没有权限执行此操作';
  @override
  String get devMessage => 'Permission denied';
}

// ═══════════════════════════════════════════════════════════════════════════
// 4. 加密层异常 (40000-49999)
// ═══════════════════════════════════════════════════════════════════════════

/// 加密失败。
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

/// 解密失败。
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

// ═══════════════════════════════════════════════════════════════════════════
// 5. 数据解析异常 (50000-59999)
// ═══════════════════════════════════════════════════════════════════════════

/// JSON 解析失败。
class ParseException extends AppException {
  final String? field;

  @override
  final int code = 50001;
  @override
  final Object? cause;
  @override
  final StackTrace? stackTrace;

  ParseException({
    this.field,
    this.cause,
    this.stackTrace,
  });

  @override
  String get userMessage => '数据格式错误';
  @override
  String get devMessage =>
      field != null ? 'Parse failed: field=$field' : 'Parse failed';
}

// ═══════════════════════════════════════════════════════════════════════════
// 6. 取消异常 (60000) — 不应弹错误,仅用于流程控制
// ═══════════════════════════════════════════════════════════════════════════

/// 用户主动取消(切换路由 / 点取消按钮)。
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

// ═══════════════════════════════════════════════════════════════════════════
// 7. 未知异常 (99999)
// ═══════════════════════════════════════════════════════════════════════════

/// 未分类异常(catch-all)。
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

// ═══════════════════════════════════════════════════════════════════════════
// 业务层 catch 示例
// ═══════════════════════════════════════════════════════════════════════════

/*
try {
  final resp = await api.postJson(...);
} on CancelException {
  // 静默,不弹 toast
} on AuthException {
  // 跳登录
  Get.toNamed('/login');
} on BusinessException catch (e) {
  // 业务错误,弹 e.userMessage
  Get.snackbar('提示', e.userMessage);
} on NetworkException catch (e) {
  // 网络错误,提示重试
  Get.snackbar('网络错误', e.userMessage);
} on AppException catch (e) {
  // 兜底
  Get.snackbar('异常', e.userMessage);
}
*/
