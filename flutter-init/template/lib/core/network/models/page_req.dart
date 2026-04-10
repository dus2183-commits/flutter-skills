/// 分页请求基类
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
