/// 路由名常量。
///
/// 新增路由必须先在这里声明,然后到 app_pages.dart 注册。
///
/// 注意: 5 个 Tab 不是独立路由 — 它们 nested 在 MainScaffold 内,
/// 通过 IndexedStack 切换,不走路由。只有"业务页面"才需要在这里加路由。
///
/// 业务页面命名约定:
///   - 列表页: /xxx-list 或 /xxx
///   - 详情页: /xxx/:id
///   - 表单页: /xxx-form
abstract class Routes {
  Routes._();

  /// 主壳(底部 Tab 容器)
  static const home = '/';

  // ─── 业务页面在下面加 ───
  // static const announceList = '/announce-list';
  // static const announceDetail = '/announce/:id';
  // static const userProfile = '/user/:id';
}
