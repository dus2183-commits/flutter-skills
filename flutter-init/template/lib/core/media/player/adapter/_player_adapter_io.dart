import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import 'player_adapter.dart';

/// IO 端 (Android/iOS) 播放器适配器
///
/// 基于 video_player 包,支持:
/// - 普通视频 (http/https/file)
/// - HLS 流 (m3u8)
/// - 位置更新 (100ms 轮询)
/// - 缓冲状态追踪
class IOPlayerAdapter extends PlayerAdapter {
  final VideoPlayerController controller;
  Timer? _positionTimer;

  IOPlayerAdapter(this.controller) {
    controller.addListener(_onUpdate);
  }

  @override
  String? get errorDescription => controller.value.errorDescription;

  @override
  double get videoAspectRatio => controller.value.aspectRatio;

  @override
  double get volume => controller.value.volume;

  @override
  bool get isPlaying => controller.value.isPlaying;

  @override
  bool get isCompleted {
    final v = controller.value;
    if (v.duration <= Duration.zero) return false;
    return v.position >= v.duration - const Duration(milliseconds: 300);
  }

  @override
  Duration get position => controller.value.position;

  @override
  Duration get duration => controller.value.duration;

  @override
  Duration get buffer {
    final ranges = controller.value.buffered;
    if (ranges.isEmpty) return Duration.zero;
    return ranges.last.end;
  }

  @override
  Future<void> initPlayer() async {
    if (isInitialized) return;
    await controller.initialize();
    isInitialized = true;
  }

  @override
  Future<void> playOrPause() async {
    if (disposed) return;
    if (isPlaying) {
      await controller.pause();
      _positionTimer?.cancel();
    } else {
      await controller.play();
      _startPositionTimer();
    }
  }

  @override
  Future<void> seek(Duration pos) async {
    if (disposed) return;
    await controller.seekTo(pos);
  }

  @override
  void setRate(double rate) {
    if (disposed) return;
    controller.setPlaybackSpeed(rate);
  }

  @override
  void setVolume(double vol) {
    if (disposed) return;
    controller.setVolume(vol);
  }

  @override
  void pause() {
    if (disposed) return;
    controller.pause();
    _positionTimer?.cancel();
  }

  @override
  Widget videoWidget() {
    if (disposed) return const SizedBox();
    return VideoPlayer(controller);
  }

  @override
  void dispose() {
    if (disposed) return;
    disposed = true;
    controller.removeListener(_onUpdate);
    _positionTimer?.cancel();
    controller.dispose();
  }

  void _onUpdate() {
    // 状态变化由 controller 的 listener 驱动
    // 上层通过 getter 读取最新状态
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (disposed) return;
      // 触发上层 setState 刷新进度条
    });
  }
}

/// 工厂方法
PlayerAdapter createAdapter({dynamic controller}) {
  if (controller == null) {
    throw ArgumentError.value(
      controller,
      'controller',
      'Non-null VideoPlayerController required on IO platforms.',
    );
  }
  return IOPlayerAdapter(controller as VideoPlayerController);
}
