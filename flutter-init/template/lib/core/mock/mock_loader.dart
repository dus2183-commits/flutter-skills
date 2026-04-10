// MockLoader - Mock 数据加载器
// 这是 yc141 没有的增量
//
// 用法:
//   1. 编译期开关: --dart-define=USE_MOCK=true
//   2. 业务无感知: ApiClient 内部根据 enabled 自动分流
//   3. mock 数据: assets/mock/{module}/{api}.json
//      pubspec.yaml 注册: assets: - mock/

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';

import 'mock_config.dart';

class MockLoader extends GetxService {
  /// 编译期 mock 开关
  static const bool enabled =
      bool.fromEnvironment('USE_MOCK', defaultValue: false);

  /// 加载 mock JSON
  ///
  /// [key] 形如 "announce/list" 对应 assets/mock/announce/list.json
  Future<Map<String, dynamic>> load(String key) async {
    final path = 'mock/$key.json';
    try {
      final raw = await rootBundle.loadString(path);
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Mock not found: $path');
    }
  }

  /// 模拟延迟 (让 UI loading 看得到)
  Future<void> simulateDelay({
    Duration min = const Duration(milliseconds: 200),
    Duration max = const Duration(milliseconds: 800),
  }) async {
    if (!MockConfig.simulateDelay) return;
    final ms = min.inMilliseconds +
        (DateTime.now().millisecondsSinceEpoch % (max.inMilliseconds - min.inMilliseconds));
    await Future.delayed(Duration(milliseconds: ms));
  }

  /// 是否启用 (供业务代码查询)
  bool get isEnabled => enabled;
}
