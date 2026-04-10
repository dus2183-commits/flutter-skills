// MockConfig - Mock 全局配置

class MockConfig {
  /// 是否模拟网络延迟 (让 loading UI 可见)
  static const bool simulateDelay = true;

  /// 是否打印 mock 命中日志
  static const bool logHits = true;

  /// mock 数据根目录 (assets/mock/)
  static const String mockRoot = 'mock';
}
