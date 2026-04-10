/// 分页响应基类
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

  factory PageResp.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) itemFromJson,
  ) {
    final listRaw = json['list'] as List? ?? [];
    return PageResp(
      list: listRaw.map((e) => itemFromJson(e)).toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 20,
    );
  }
}
