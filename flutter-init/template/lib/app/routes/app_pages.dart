import 'package:get/get.dart';

import '../app.dart';
import 'app_routes.dart';

/// 路由表。所有 GetPage 在这里注册。
abstract class AppPages {
  AppPages._();

  static const initial = Routes.home;

  static final routes = <GetPage>[
    GetPage(
      name: Routes.home,
      page: () => const MainScaffold(),
    ),
    // 新增页面在这里加 GetPage
    // GetPage(
    //   name: Routes.announceList,
    //   page: () => const AnnounceListPage(),
    //   binding: AnnounceListBinding(),
    // ),
  ];
}
