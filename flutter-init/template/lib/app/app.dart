// ════════════════════════════════════════════════════════════════════
//  主壳 - 底部 Tab 导航
// ────────────────────────────────────────────────────────────────────
//  数据驱动:Tab 配置在 lib/app/tabs.dart
//  加减 Tab 不要动这个文件,改 tabs.dart
//
//  自动适应 0/1/N 个 Tab:
//   - 0 个: 显示空 Scaffold (建议直接跳业务首页)
//   - 1 个: 隐藏 BottomNavigationBar
//   - 2-N 个: 显示 BottomNavigationBar
// ════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import 'tabs.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // 0 个 tab → 空 scaffold
    if (tabs.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No tabs configured. Edit lib/app/tabs.dart')),
      );
    }

    // 1 个 tab → 隐藏底部栏,直接显示
    if (tabs.length == 1) {
      return Scaffold(body: tabs[0].page);
    }

    // N 个 tab → 标准 BottomNavigationBar
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: tabs.map((t) => t.page).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: tabs
            .map(
              (t) => BottomNavigationBarItem(
                icon: Icon(t.icon),
                activeIcon: Icon(t.activeIcon),
                label: t.label,
              ),
            )
            .toList(),
      ),
    );
  }
}
