import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'dart:ui_web' as ui_web;

import 'player_adapter.dart';

/// JS 全局对象 GPPlayer — Web 端视频播放器
///
/// 由 web/js/video_player.js 提供 (需要从 yc141 迁移)
/// 功能:
/// - 全局共用一个 <video> DOM 元素 (避免多实例冲突)
/// - HLS.js 支持 m3u8 流
/// - 加密视频: 下载 + AES 解密 → Blob URL
/// - 浏览器 autoplay 策略处理 (静音自动播放回退)
@JS('GPPlayer')
external GPPlayerJS? get _gpPlayer;

extension type GPPlayerJS(JSObject _) implements JSObject {
  external JSObject init();
  external void setSource(String url);
  external JSPromise<JSAny?> play();
  external void pause();
  external void unmute();
  external void seekTo(num seconds);
  external void setVolume(num volume);
  external void setRate(num rate);
  external _GPState getState();
}

extension type _GPState(JSObject _) implements JSObject {
  external JSNumber get position;
  external JSNumber get duration;
  external JSNumber get buffered;
  external JSBoolean get playing;
  external JSBoolean get ended;
  external JSNumber get width;
  external JSNumber get height;
  external JSNumber get volume;
  external JSNumber get rate;
  external JSAny? get error;
  external JSBoolean get buffering;
  external JSBoolean get forceMuted;
}

/// Web 端播放器适配器
///
/// 底层复用同一个全局 <video> DOM 元素,解决浏览器 autoplay 策略限制。
/// 通过 GPPlayer JS 对象与 Dart 交互,100ms 轮询同步状态。
class WebPlayerAdapter extends PlayerAdapter {
  static WebPlayerAdapter? _activeInstance;
  static const String _videoId = '__global_video_player__';
  static bool _viewRegistered = false;
  static bool _isUserActivated = false;

  String? _errorDescription;
  double _videoWidth = 0;
  double _videoHeight = 0;
  double _volume = 1.0;
  bool _isForceMuted = false;
  bool _isPlaying = false;
  bool _isCompleted = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffer = Duration.zero;
  Timer? _syncTimer;

  bool get _isActive => identical(_activeInstance, this);

  WebPlayerAdapter() {
    _ensureViewFactory();
  }

  static void _ensureViewFactory() {
    if (_viewRegistered || _gpPlayer == null) return;
    _viewRegistered = true;
    ui_web.platformViewRegistry.registerViewFactory(
      _videoId,
      (int viewId) => _gpPlayer!.init(),
    );
  }

  @override
  String? get errorDescription => _errorDescription;

  @override
  double get videoAspectRatio =>
      (_videoWidth > 0 && _videoHeight > 0) ? _videoWidth / _videoHeight : 16 / 9;

  @override
  double get volume => _volume;

  @override
  bool get isPlaying => _isPlaying;

  @override
  bool get isCompleted => _isCompleted;

  @override
  Duration get position => _position;

  @override
  Duration get duration => _duration;

  @override
  Duration get buffer => _buffer;

  /// 用户是否已通过手势激活 (激活后可有声自动播放)
  bool get isUserActivated => _isUserActivated;

  /// 是否因 autoplay 策略被强制静音
  bool get isForceMuted => _isForceMuted;

  @override
  Future<void> initPlayer() async {
    if (_gpPlayer == null) return;
    if (isInitialized) return;
    isInitialized = true;
    _startSyncState();

    // 等待视频加载
    final completer = Completer<void>();
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_gpPlayer == null) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete();
        return;
      }
      final s = _gpPlayer!.getState();
      final dur = s.duration.toDartDouble;
      final err = s.error;

      if (dur > 0) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete();
      } else if (err != null && err.isA<JSString>()) {
        timer.cancel();
        _errorDescription = (err as JSString).toDart;
        if (!completer.isCompleted) completer.completeError(_errorDescription!);
      }
      if (timer.tick > 300) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete();
      }
    });
    return completer.future;
  }

  @override
  Future<void> playOrPause() async {
    if (_gpPlayer == null || disposed) return;
    _activeInstance = this;
    if (_isPlaying) {
      _gpPlayer?.pause();
    } else {
      await _gpPlayer?.play().toDart;
      final s = _gpPlayer!.getState();
      _isForceMuted = s.forceMuted.toDart;
      if (!_isForceMuted) _isUserActivated = true;
    }
  }

  @override
  Future<void> seek(Duration pos) async {
    if (_gpPlayer == null || disposed || !_isActive) return;
    _gpPlayer?.seekTo(pos.inMilliseconds / 1000.0);
  }

  @override
  void setRate(double rate) {
    if (_gpPlayer == null || disposed || !_isActive) return;
    _gpPlayer?.setRate(rate);
  }

  @override
  void setVolume(double vol) {
    if (_gpPlayer == null || disposed || !_isActive) return;
    _gpPlayer?.setVolume(vol);
  }

  @override
  void pause() {
    if (disposed || !_isActive) return;
    _gpPlayer?.pause();
  }

  /// 取消强制静音 (用户点击取消静音按钮)
  void unmute() {
    if (_gpPlayer == null || disposed || !_isActive) return;
    _gpPlayer?.unmute();
    _isForceMuted = false;
    _isUserActivated = true;
  }

  @override
  Future<void> setSource(String url) async {
    if (_gpPlayer == null) return;
    _activeInstance = this;
    _gpPlayer?.setSource(url);
    _errorDescription = null;
    isInitialized = false;
    _videoWidth = 0;
    _videoHeight = 0;
    _isPlaying = false;
    _isCompleted = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    initUIState = PlayerInitUIState.init;
  }

  @override
  void dispose() {
    if (disposed) return;
    disposed = true;
    _syncTimer?.cancel();
    if (_activeInstance == this) {
      _gpPlayer?.pause();
      _activeInstance = null;
    }
  }

  /// 获取 HtmlElementView (在 Widget 树中嵌入 video 元素)
  Widget videoWidget() {
    if (_gpPlayer == null || disposed) return const SizedBox();
    return HtmlElementView(viewType: _videoId);
  }

  void _startSyncState() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (disposed || _gpPlayer == null) return;
      final s = _gpPlayer!.getState();

      _position = Duration(milliseconds: (s.position.toDartDouble * 1000).round());
      _duration = Duration(milliseconds: (s.duration.toDartDouble * 1000).round());
      _buffer = Duration(milliseconds: (s.buffered.toDartDouble * 1000).round());
      _isPlaying = s.playing.toDart;
      _videoWidth = s.width.toDartDouble;
      _videoHeight = s.height.toDartDouble;
      _volume = s.volume.toDartDouble;
      _isForceMuted = s.forceMuted.toDart;

      final ended = s.ended.toDart;
      _isCompleted = ended ||
          (_duration > Duration.zero && _position >= _duration - const Duration(milliseconds: 300));

      final err = s.error;
      _errorDescription = (err != null && err.isA<JSString>()) ? (err as JSString).toDart : null;
    });
  }
}

/// 工厂方法
PlayerAdapter createAdapter({dynamic controller}) {
  return WebPlayerAdapter();
}
