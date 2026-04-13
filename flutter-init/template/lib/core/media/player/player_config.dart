import 'package:flutter/widgets.dart';

/// 播放器渲染模式
enum PlayerRenderer {
  /// 横屏 (16:9) — 正常视频,带进度条/全屏/手势
  horizontal,

  /// 竖屏全屏 — 抖音风格短视频,上下滑动切换
  vertical,

  /// 无 UI 控件 — 纯播放,业务层自定义 UI
  none,
}

/// 视频播放配置
///
/// 用法:
/// ```dart
/// AppVideo(
///   config: PlayerConfig(
///     link: PlayerLink(url: 'https://example.com/video.mp4'),
///     cover: 'https://example.com/cover.jpg',
///     autoPlay: true,
///   ),
///   renderer: PlayerRenderer.horizontal,
/// )
/// ```
class PlayerConfig {
  /// 视频链接信息
  final PlayerLink link;

  /// 封面图 URL
  final String? cover;

  /// 视频标题
  final String? title;

  /// 是否自动播放 (默认 true)
  final bool autoPlay;

  /// 是否循环播��
  final bool loop;

  /// 是否静音
  final bool mute;

  /// 右上角自���义 Widget (如分享/收藏按钮)
  final Widget? topRightWidget;

  const PlayerConfig({
    required this.link,
    this.cover,
    this.title,
    this.autoPlay = true,
    this.mute = false,
    this.loop = false,
    this.topRightWidget,
  });
}

/// 视频链接
///
/// [url] 可以是:
/// - 普通 HTTP URL: `https://cdn.example.com/video.mp4`
/// - 加密视频 URL: `https://cdn.example.com/video.bnc` (含 .bnc 后缀)
/// - HLS 流: `https://cdn.example.com/video/master.m3u8`
/// - 相对路径: `/video/play/123` (会自动拼接 baseUrl)
class PlayerLink {
  /// 视频资源 ID
  String id;

  /// 线路 ID (多线路切换用)
  String lid;

  /// 视频 URL
  String url;

  /// 线路代号
  String code;

  PlayerLink({
    this.id = '',
    this.lid = '',
    required this.url,
    this.code = '',
  });
}
