/// 分页响应基类
///
/// 后端约定:
/// - 响应只包含 `list` + `total`
/// - 不返回 pageNum / pageSize (前端自己维护)
///
/// 因此 hasMore 需要外部传入 pageNum 和 pageSize 来计算,
/// 或者用 `list.length < pageSize` 简化判断。
class PageResp<T> {
  final List<T> list;
  final int total;

  const PageResp({
    required this.list,
    required this.total,
  });

  bool get isEmpty => list.isEmpty;
  bool get isNotEmpty => list.isNotEmpty;
  int get currentCount => list.length;

  /// 是否还有更多数据
  ///
  /// 用法 1: `resp.hasMoreWith(pageNum: 1, pageSize: 20)`
  /// 用法 2: 简化判断 `resp.list.length >= pageSize` (可能多请求一次)
  bool hasMoreWith({required int pageNum, required int pageSize}) {
    return pageNum * pageSize < total;
  }

  factory PageResp.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) itemFromJson,
  ) {
    final listRaw = json['list'] as List? ?? [];
    return PageResp(
      list: listRaw.map((e) => itemFromJson(e)).toList(),
      total: json['total'] as int? ?? 0,
    );
  }
}
