/// 分页请求基类
///
/// 支持不同后端的分页字段名约定:
/// - 有的后端用 `pageNum` + `pageSize`
/// - 有的后端用 `page` + `pageSize`
/// - 有的后端用 `page` + `size`
///
/// 通过 [pageField] 和 [sizeField] 配置字段名,
/// 一个项目统一设一次即可。默认 `pageNum` + `pageSize`。
///
/// 用法:
/// ```dart
/// // 大多数后端 (pageNum/pageSize)
/// const PageReq()  // → {"pageNum": 1, "pageSize": 20}
///
/// // 如果后端用 page/pageSize,在 AppConfig 初始化时设一次:
/// PageReq.pageField = 'page';
/// // 之后所有 PageReq() → {"page": 1, "pageSize": 20}
/// ```
class PageReq {
  /// 页码字段名 (项目级统一配置)
  /// 默认 'pageNum',如果后端用 'page' 改这里即可
  static String pageField = 'pageNum';

  /// 每页条数字段名 (项目级统一配置)
  static String sizeField = 'pageSize';

  final int page;
  final int pageSize;

  const PageReq({this.page = 1, this.pageSize = 20});

  Map<String, dynamic> toJson() => {
        pageField: page,
        sizeField: pageSize,
      };

  PageReq copyWith({int? page, int? pageSize}) => PageReq(
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
      );
}
