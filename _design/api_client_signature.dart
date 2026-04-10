// ═══════════════════════════════════════════════════════════════════════════
// ApiClient 接口契约 (signature only, no implementation)
// ───────────────────────────────────────────────────────────────────────────
// 这是 flutter-skills 项目核心库 ApiClient 的对外契约。
//
// 用途:
//   1. B (api-gen 作者) 写 SKILL.md 代码模板时,严格按这里的方法签名引用
//   2. 你 (lead) 实现 lib/core/network/api_client.dart 时,按这里的签名实现
//   3. C (page-gen 作者) 写 controller 模板时,知道 repository 调什么方法
//
// 约束:
//   - 所有方法 ctx-aware (cancelToken 可传)
//   - 所有方法支持 mock 分流 (mockKey 必填)
//   - 所有方法用 fromJson 转模型,不返回 Map
//   - 所有方法可能抛 AppException (sealed class, 见 app_exception.dart)
//   - 加密/签名/重试/日志由 interceptor 处理,业务层不感知
//
// 设计原则:
//   - 业务层不直接 new Dio() / 不直接 import package:dio
//   - 业务层只 import 'package:app/core/network/api_client.dart'
//   - 测试时可注入 MockApiClient (实现同接口)
// ═══════════════════════════════════════════════════════════════════════════

import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart' show CancelToken; // 仅 type re-export
import 'package:get/get.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 配套类型
// ═══════════════════════════════════════════════════════════════════════════

/// 分页请求基类。所有列表接口的请求 DTO 应继承此类。
class PageReq {
  final int page;
  final int pageSize;

  const PageReq({this.page = 1, this.pageSize = 20});

  Map<String, dynamic> toJson() => {
        'page': page,
        'pageSize': pageSize,
      };

  PageReq copyWith({int? page, int? pageSize}) => PageReq(
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
      );
}

/// 分页响应基类。所有列表接口的响应自动包装。
class PageResp<T> {
  final List<T> list;
  final int total;
  final int page;
  final int pageSize;

  const PageResp({
    required this.list,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  bool get hasMore => page * pageSize < total;
  bool get isEmpty => list.isEmpty;
  bool get isNotEmpty => list.isNotEmpty;
  int get currentCount => list.length;
}

/// 上传响应。
class UploadResp {
  final String url;
  final String? key;
  final int sizeBytes;

  const UploadResp({
    required this.url,
    this.key,
    required this.sizeBytes,
  });
}

/// HTTP 方法枚举(可选,可用 String)。
enum HttpMethod { get, post, put, delete, patch }

// ═══════════════════════════════════════════════════════════════════════════
// ApiClient 主接口
// ═══════════════════════════════════════════════════════════════════════════

/// 全局 API 客户端。
///
/// 必须用 GetxService 单例,在 main.dart 启动时:
/// ```dart
/// await Get.putAsync(() => ApiClient().init());
/// ```
///
/// 业务层调用:
/// ```dart
/// final api = Get.find<ApiClient>();
/// final resp = await api.postJson<MyResp>(...);
/// ```
abstract class ApiClient extends GetxService {
  // ─────────────────────────────────────────────────────────────────────
  // 生命周期
  // ─────────────────────────────────────────────────────────────────────

  /// 初始化 Dio + 注册 6 个拦截器。
  /// 必须在 App 启动时调用一次。
  Future<ApiClient> init();

  /// 取消所有正在进行的请求(切换路由时调用)。
  void cancelAll();

  // ─────────────────────────────────────────────────────────────────────
  // GET — 查询类接口
  // ─────────────────────────────────────────────────────────────────────

  /// GET 请求,返回单个对象。
  ///
  /// [path] 接口路径(相对或绝对 URL)
  /// [query] URL query 参数
  /// [mockKey] mock 数据 key (mock/{module}/{key}.json)
  /// [fromJson] 响应解析函数
  /// [cancelToken] 取消令牌
  /// [encrypt] 是否加密响应(默认 true)
  Future<T> get<T>({
    required String path,
    Map<String, dynamic>? query,
    required String mockKey,
    required T Function(dynamic) fromJson,
    CancelToken? cancelToken,
    bool encrypt = true,
  });

  // ─────────────────────────────────────────────────────────────────────
  // POST — 提交类接口
  // ─────────────────────────────────────────────────────────────────────

  /// POST JSON 请求(content-type: application/json)。
  ///
  /// 适用于大多数业务接口。
  Future<T> postJson<T>({
    required String path,
    required Map<String, dynamic> data,
    required String mockKey,
    required T Function(dynamic) fromJson,
    CancelToken? cancelToken,
    bool encrypt = true,
  });

  /// POST Form 请求(content-type: application/x-www-form-urlencoded)。
  ///
  /// 适用于兼容老式后端。yc141 默认走这个。
  Future<T> postForm<T>({
    required String path,
    required Map<String, dynamic> data,
    required String mockKey,
    required T Function(dynamic) fromJson,
    CancelToken? cancelToken,
    bool encrypt = true,
  });

  // ─────────────────────────────────────────────────────────────────────
  // 列表 — 自动分页处理
  // ─────────────────────────────────────────────────────────────────────

  /// 列表请求(自动包装 PageResp)。
  ///
  /// 后端响应必须是 `{list: [...], total: N, page: N, pageSize: N}` 结构。
  /// 不符合此结构的列表用 postJson 自行处理。
  Future<PageResp<T>> getList<T>({
    required String path,
    required PageReq pageReq,
    Map<String, dynamic>? extraParams,
    required String mockKey,
    required T Function(dynamic) fromJson,
    CancelToken? cancelToken,
    bool encrypt = true,
  });

  // ─────────────────────────────────────────────────────────────────────
  // DELETE
  // ─────────────────────────────────────────────────────────────────────

  Future<T> delete<T>({
    required String path,
    Map<String, dynamic>? data,
    required String mockKey,
    required T Function(dynamic) fromJson,
    CancelToken? cancelToken,
    bool encrypt = true,
  });

  // ─────────────────────────────────────────────────────────────────────
  // 文件上传 — 三端兼容(用 XFile 不用 dart:io File)
  // ─────────────────────────────────────────────────────────────────────

  /// 单文件上传。
  ///
  /// [file] 用 cross_file.XFile,Web 端是 Blob,移动端是 File。
  /// [onProgress] 上传进度回调(sent/total bytes)
  Future<UploadResp> upload({
    required String path,
    required XFile file,
    Map<String, dynamic>? extraParams,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  });

  /// 多文件上传。
  Future<List<UploadResp>> uploadMultiple({
    required String path,
    required List<XFile> files,
    Map<String, dynamic>? extraParams,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  });

  // ─────────────────────────────────────────────────────────────────────
  // 文件下载 — 三端兼容
  // ─────────────────────────────────────────────────────────────────────

  /// 下载文件。
  ///
  /// 移动端: 写入指定路径(用 path_provider 拿)
  /// Web 端: 触发浏览器下载
  Future<void> download({
    required String url,
    required String savePath,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  });

  // ─────────────────────────────────────────────────────────────────────
  // 调试/诊断
  // ─────────────────────────────────────────────────────────────────────

  /// 当前是否在 mock 模式(编译期决定)。
  bool get isMockEnabled;

  /// 当前 base URL(可能因线路切换变化)。
  String get currentBaseUrl;

  /// 切换线路(用于 NORMAL_LINES → BACKUP_LINES 容灾)。
  void switchLine(String lineCode);
}

// ═══════════════════════════════════════════════════════════════════════════
// Repository 调用示例 (B 写 api-gen 时的代码模板基础)
// ═══════════════════════════════════════════════════════════════════════════

/*
// 示例: features/announce/data/repositories/announce_repository.dart

import 'package:get/get.dart';
import 'package:app/core/network/api_client.dart';
import 'package:app/core/error/app_exception.dart';
import '../models/announce.model.dart';

class AnnounceRepository extends GetxService {
  final ApiClient _api = Get.find();

  /// 公告列表
  Future<PageResp<Announce>> getList({
    required PageReq pageReq,
    String? keyword,
    CancelToken? cancelToken,
  }) async {
    return await _api.getList<Announce>(
      path: '/api/announce/list',
      pageReq: pageReq,
      extraParams: keyword != null ? {'keyword': keyword} : null,
      mockKey: 'announce/list',
      fromJson: (json) => Announce.fromJson(json as Map<String, dynamic>),
      cancelToken: cancelToken,
    );
  }

  /// 公告详情
  Future<Announce> getDetail({
    required String id,
    CancelToken? cancelToken,
  }) async {
    return await _api.get<Announce>(
      path: '/api/announce/detail',
      query: {'id': id},
      mockKey: 'announce/detail',
      fromJson: (json) => Announce.fromJson(json as Map<String, dynamic>),
      cancelToken: cancelToken,
    );
  }

  /// 标记已读
  Future<void> markRead({
    required String id,
    CancelToken? cancelToken,
  }) async {
    await _api.postJson<void>(
      path: '/api/announce/markRead',
      data: {'id': id},
      mockKey: 'announce/markRead',
      fromJson: (_) {},
      cancelToken: cancelToken,
    );
  }
}

// 使用方:
// final repo = Get.find<AnnounceRepository>();
// try {
//   final resp = await repo.getList(pageReq: PageReq());
// } on NetworkException catch (e) {
//   // 网络层错误
// } on BusinessException catch (e) {
//   // 业务错误码
// } on AppException catch (e) {
//   // 兜底
// }
*/
