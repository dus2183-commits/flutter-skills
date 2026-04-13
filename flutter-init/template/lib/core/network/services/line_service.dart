import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../config/app_config.dart';

/// 线路测速结果
class SpeedTestResult {
  final Line line;
  final int latencyMs;
  final bool reachable;

  const SpeedTestResult({
    required this.line,
    required this.latencyMs,
    required this.reachable,
  });
}

/// 线路选择服务
///
/// 启动时自动测速,选择最快的线路。
/// 所有线路不可达时,触发 onAllLinesFailed 回调(显示错误页)。
///
/// 用法:
/// ```dart
/// // main.dart 中初始化
/// final lineService = await Get.putAsync(() => LineService().init());
///
/// // 监听线路全挂事件
/// lineService.onAllLinesFailed = () {
///   Get.offAllNamed(Routes.networkError);
/// };
/// ```
class LineService extends GetxService {
  late AppConfig _config;
  late Dio _testDio;

  /// 测速超时 (毫秒)
  static const int _timeoutMs = 5000;

  /// 当前线路的延迟 (毫秒)
  final latency = 0.obs;

  /// 是否正在测速
  final testing = false.obs;

  /// 所有线路全挂时的回调
  VoidCallback? onAllLinesFailed;

  Future<LineService> init() async {
    _config = Get.find<AppConfig>();
    _testDio = Dio(BaseOptions(
      connectTimeout: const Duration(milliseconds: _timeoutMs),
      receiveTimeout: const Duration(milliseconds: _timeoutMs),
    ));

    // 启动时自动测速选线
    await selectBestLine();
    return this;
  }

  /// 对单个线路测速
  ///
  /// 发 HEAD 请求到线路 URL,计算响应时间。
  Future<SpeedTestResult> testLine(Line line) async {
    if (line.url.isEmpty) {
      return SpeedTestResult(line: line, latencyMs: 99999, reachable: false);
    }

    final stopwatch = Stopwatch()..start();
    try {
      await _testDio.head('${line.url}/health');
      stopwatch.stop();
      return SpeedTestResult(
        line: line,
        latencyMs: stopwatch.elapsedMilliseconds,
        reachable: true,
      );
    } catch (_) {
      stopwatch.stop();
      return SpeedTestResult(
        line: line,
        latencyMs: stopwatch.elapsedMilliseconds,
        reachable: false,
      );
    }
  }

  /// 对所有线路测速,选择最快的
  ///
  /// 先测正常线路,全挂则测备用线路。
  /// 全部不可达时触发 [onAllLinesFailed]。
  Future<void> selectBestLine() async {
    testing.value = true;

    try {
      // 1. 并行测正常线路
      final normalResults = await Future.wait(
        _config.normalLines.map(testLine),
      );

      final reachable = normalResults.where((r) => r.reachable).toList()
        ..sort((a, b) => a.latencyMs.compareTo(b.latencyMs));

      if (reachable.isNotEmpty) {
        _config.switchLine(reachable.first.line);
        latency.value = reachable.first.latencyMs;
        debugPrint('[LineService] 选择线路: ${reachable.first.line.url} (${reachable.first.latencyMs}ms)');
        return;
      }

      // 2. 正常线路全挂,测备用线路
      final backupResults = await Future.wait(
        _config.backupLines.map(testLine),
      );

      final backupReachable = backupResults.where((r) => r.reachable).toList()
        ..sort((a, b) => a.latencyMs.compareTo(b.latencyMs));

      if (backupReachable.isNotEmpty) {
        _config.switchLine(backupReachable.first.line);
        latency.value = backupReachable.first.latencyMs;
        debugPrint('[LineService] 备用线路: ${backupReachable.first.line.url} (${backupReachable.first.latencyMs}ms)');
        return;
      }

      // 3. 全部不可达
      debugPrint('[LineService] 所有线路不可达!');
      onAllLinesFailed?.call();
    } finally {
      testing.value = false;
    }
  }

  /// 手动切换线路
  void switchTo(Line line) {
    _config.switchLine(line);
    debugPrint('[LineService] 手动切换: ${line.url}');
  }

  /// 手动重试测速
  Future<void> retry() async {
    await selectBestLine();
  }

  @override
  void onClose() {
    _testDio.close();
    super.onClose();
  }
}
