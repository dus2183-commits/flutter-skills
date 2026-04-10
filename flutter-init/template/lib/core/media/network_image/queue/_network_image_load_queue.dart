import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart' show debugPrint;
import '_network_image_load_queue_io.dart' if (dart.library.html) '_network_image_load_queue_web.dart';
/// 支持并发的图片加载队列（可配置最大并发数）
/// 用法示例:
///   ImageLoadQueue.shared.add(() async { await loadImage(...); });
/// 或先配置:
///   ImageLoadQueue.configure(maxConcurrent: 6);
/// 支持并发和返回值的任务队列
class NetworkImageLoadQueue {

  NetworkImageLoadQueue._();

  /// 单例
  static final NetworkImageLoadQueue get = NetworkImageLoadQueue._();

  /// 默认并发数（可按平台调整）
  final int _maxConcurrent=() {
    return getMaxConcurrent();
  }();

  final Queue<Future<void> Function()> _queue = Queue();

  int _running = 0;

  /// 添加任务，支持返回值
  Future<T> add<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _queue.add(() async {
      try {
        final result = await task();
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      } catch (e, st) {
        if (!completer.isCompleted) {
          completer.completeError(e, st);
        }
      }
    });

    _run();
    return completer.future;
  }

  void _run() {
    debugPrint("[ImageLoadQueue] defaultMax:$_maxConcurrent Queue:${_queue.length}");
    while (_running < _maxConcurrent && _queue.isNotEmpty) {
      final job = _queue.removeFirst();
      _running++;
      () async {
        try {
          await job();
        } finally {
          _running--;
          _run();
        }
      }();
    }
  }

  int get running => _running;
  int get waiting => _queue.length;
}
