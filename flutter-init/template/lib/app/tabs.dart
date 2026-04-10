// ════════════════════════════════════════════════════════════════════
//  底部 Tab 配置
// ────────────────────────────────────────────────────────────────────
//  ✅ 加 / 减 / 改 Tab 都只改这个文件,不需要动 app.dart
//
//  支持任意数量的 Tab (1-N):
//    - 1 个 Tab: 适合单页 App,会自动隐藏底部栏
//    - 2-3 个 Tab: 推荐用 BottomNavigationBarType.fixed (默认)
//    - 4-5 个 Tab: 同上
//    - 5 个以上: 建议改用 PageView + 顶部 TabBar,或考虑信息架构是否合理
//
//  ✅ 完全不要 Tab? 把 tabs 改成 [] 空列表,主壳会变成单页(显示 tabs[0]).
//      或者在 main.dart 把 initialRoute 改成业务首页,跳过主壳.
//
//  ✅ 用 Drawer 代替底部栏? 改 app.dart 的 build 方法,用 Drawer 替换 bottomNavigationBar.
// ════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../features/category/presentation/pages/category_page.dart';
import '../features/discover/presentation/pages/discover_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/message/presentation/pages/message_page.dart';
import '../features/mine/presentation/pages/mine_page.dart';

/// 单个 Tab 配置.
class TabConfig {
  const TabConfig({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.page,
  });

  /// Tab 文字 (国际化在外面用 .tr 包装).
  final String label;

  /// 未选中图标.
  final IconData icon;

  /// 选中图标 (未指定则用 icon).
  final IconData activeIcon;

  /// 对应页面 (必须是 const 构造).
  final Widget page;
}

/// ─── 项目的 Tab 列表 ───
///
/// 加 Tab:
///   1. 在 lib/features/{name}/presentation/pages/ 写新页面
///   2. 在这里 import 并加一项
///   3. 重启
///
/// 减 Tab:
///   1. 删掉对应的 const 构造
///   2. (可选) 删除 lib/features/{name}/ 整个目录
///
/// 改顺序: 直接调整数组顺序
const tabs = <TabConfig>[
  TabConfig(
    label: '{{TAB_1_NAME}}',
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
    page: HomePage(),
  ),
  TabConfig(
    label: '{{TAB_2_NAME}}',
    icon: Icons.category_outlined,
    activeIcon: Icons.category,
    page: CategoryPage(),
  ),
  TabConfig(
    label: '{{TAB_3_NAME}}',
    icon: Icons.explore_outlined,
    activeIcon: Icons.explore,
    page: DiscoverPage(),
  ),
  TabConfig(
    label: '{{TAB_4_NAME}}',
    icon: Icons.message_outlined,
    activeIcon: Icons.message,
    page: MessagePage(),
  ),
  TabConfig(
    label: '{{TAB_5_NAME}}',
    icon: Icons.person_outline,
    activeIcon: Icons.person,
    page: MinePage(),
  ),
];
