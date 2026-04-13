import '_player_adapter_io.dart'
    if (dart.library.js_interop) '_player_adapter_web.dart' as impl;

/// 播放器初始化状态
enum PlayerInitUIState {
  /// 初始化中
  init,

  /// 初始化完成,但未开始播放
  ready,

  /// 正常播放中
  success,

  /// 初始化或播放错误
  error,
}

/// 播放器适配器抽象接口
///
/// IO 端 (Android/iOS): 基于 video_player
/// Web 端: 基于 HTML5 video + HLS.js
///
/// ��件导出: _player_adapter_io.dart / _player_adapter_web.dart
abstract class PlayerAdapter {
  bool disposed = false;
  bool isInitialized = false;
  bool isFullscreen = false;
  PlayerInitUIState initUIState = PlayerInitUIState.init;

  /// 视频错误描述 (null 表示无错误)
  String? get errorDescription;

  /// 视频宽高比
  double get videoAspectRatio;

  /// 音量 0.0 ~ 1.0
  double get volume;

  /// 是否正在播放
  bool get isPlaying;

  /// 是否播放完成
  bool get isCompleted;

  /// 当前播放位置
  Duration get position;

  /// 视频总时长
  Duration get duration;

  /// 缓冲位置
  Duration get buffer;

  /// 初始化播放器
  Future<void> initPlayer();

  /// 播放/暂���切换
  Future<void> playOrPause();

  /// 跳转到指定位置
  Future<void> seek(Duration position);

  /// 设置播放速��
  void setRate(double rate);

  /// 设置音量
  void setVolume(double volume);

  /// 暂停
  void pause();

  /// ��放资源
  void dispose();

  /// 切换视频源 (Web 端用)
  Future<void> setSource(String url) async {}

  /// 获取视频渲染 Widget
  ///
  /// IO 端: 返回 VideoPlayer(controller)
  /// Web 端: 返回 HtmlElementView (嵌入 <video> DOM)
  /// 上层不需要判断平台,直接用这个方法
  Widget videoWidget();
}

/// 工厂方法: 创建播放器适配器
PlayerAdapter createAdapter({dynamic controller}) {
  return impl.createAdapter(controller: controller);
}
