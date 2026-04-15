import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/media/player/player_config.dart';
import 'app_video.dart';
/// 短视频 PageView（抖音风格）
///
/// 全屏竖屏，上下滑动切换视频。
/// 底层播放器使用 [AppVideo]，兼容 iOS / Android / Web。
///
/// 缓存策略（仅 iOS / Android）:
/// - 当前页 ±2 的 [VideoPlayerController] 提前 initialize，滑到时无需重新加载
/// - [_KeepAlivePage] 保持相邻页 Widget State 存活，避免重走 initState
/// - [AppVideo] 通过 [AppVideo.preloadedController] 接收预加载控制器，
///   不重复 initialize，且不负责 dispose（由本组件池统一管理）
///
/// Web 端池逻辑自动跳过（kIsWeb），AppVideo 内部走 WebPlayerAdapter。
///
/// 用法:
/// ```dart
/// ShortVideoPageView(
///   videos: [
///     PlayerConfig(link: PlayerLink(url: '...'), cover: '...'),
///   ],
///   onPageChanged: (index) => print('当前第 $index 个'),
///   itemBuilder: (context, config, videoWidget) {
///     return Stack(children: [
///       videoWidget,
///       Positioned(right: 16, bottom: 100, child: _buildActions()),
///     ]);
///   },
/// )
/// ```
class ShortVideoPageView extends StatefulWidget {
  /// 视频配置列表
  final List<PlayerConfig> videos;

  /// 页面切换回调
  final ValueChanged<int>? onPageChanged;

  /// 自定义每个视频页面的构建
  ///
  /// [config] 当前视频配置
  /// [videoWidget] 已配置好的 [AppVideo] Widget（含预加载控制器）
  /// 返回你自定义的页面（通常是 Stack 叠加按钮）
  final Widget Function(
    BuildContext context,
    PlayerConfig config,
    Widget videoWidget,
  )? itemBuilder;

  /// 加载更多回调（滑到倒数第 [loadMoreThreshold] 个时触发）
  final VoidCallback? onLoadMore;

  /// 触发加载更多的阈值（默认倒数第 3 个）
  final int loadMoreThreshold;

  /// 手势配置，默认 [AppVideoGestureConfig.shortVideo]。
  ///
  /// 默认值禁用竖向手势（音量 / 亮度），让 PageView 接管上下滑动。
  /// 若需要在短视频中保留音量调节，可传入自定义配置：
  /// ```dart
  /// gestureConfig: AppVideoGestureConfig(enableVolume: true, enableBrightness: false)
  /// ```
  final AppVideoGestureConfig gestureConfig;

  const ShortVideoPageView({
    super.key,
    required this.videos,
    this.onPageChanged,
    this.itemBuilder,
    this.onLoadMore,
    this.loadMoreThreshold = 3,
    this.gestureConfig = AppVideoGestureConfig.shortVideo,
  });

  @override
  State<ShortVideoPageView> createState() => _ShortVideoPageViewState();
}

class _ShortVideoPageViewState extends State<ShortVideoPageView> {
  late final PageController _pageController;
  int _currentPage = 0;

  /// VideoPlayerController 预加载池（仅 iOS / Android）
  ///
  /// key = 视频 URL，value = 已调用 initialize() 的 controller。
  /// 保持 currentPage ±2 范围内的 controller 存活，其余 dispose 释放内存。
  final Map<String, VideoPlayerController> _pool = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (!kIsWeb) _preload(0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final ctrl in _pool.values) {
      ctrl.dispose();
    }
    _pool.clear();
    super.dispose();
  }

  // ── 预加载 ─────────────────────────────────────────────────────────────────

  /// 预初始化 [from] ~ [from+2] 的 controller，释放 [from-3] 以远的
  void _preload(int from) {
    // 预加载 from ~ from+2
    for (var i = from; i <= from + 2 && i < widget.videos.length; i++) {
      final url = widget.videos[i].link.url;
      // file: 协议无需预加载；已在池中的跳过
      if (url.isEmpty || url.startsWith('file:') || _pool.containsKey(url)) {
        continue;
      }
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      _pool[url] = ctrl;
      ctrl.initialize().catchError((_) {}); // fire & forget，错误由 AppVideo 内部处理
    }

    // 释放过远的 controller（from-3 之前）
    final stale = <String>[];
    for (final entry in _pool.entries) {
      final idx = widget.videos.indexWhere((v) => v.link.url == entry.key);
      if (idx >= 0 && idx < from - 2) {
        entry.value.dispose();
        stale.add(entry.key);
      }
    }
    for (final url in stale) _pool.remove(url);
  }

  /// 取池中已预加载的 controller（可能仍在 initializing，AppVideo 会等待）
  VideoPlayerController? _pooled(int index) {
    if (kIsWeb || index < 0 || index >= widget.videos.length) return null;
    return _pool[widget.videos[index].link.url];
  }

  // ── 页面切换 ────────────────────────────────────────────────────────────────

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    widget.onPageChanged?.call(index);
    if (!kIsWeb) _preload(index);

    if (widget.onLoadMore != null &&
        index >= widget.videos.length - widget.loadMoreThreshold) {
      widget.onLoadMore!();
    }
  }

  // ── 构建 ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.videos.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final config = widget.videos[index];
          final isActive = index == _currentPage;
          final isNear = (index - _currentPage).abs() <= 1;

          Widget videoWidget;
          if (isNear) {
            videoWidget = AppVideo(
              // 稳定 key：autoPlay 变化时走 didUpdateWidget，不重建 State
              key: ValueKey('spv_$index'),
              config: PlayerConfig(
                link: config.link,
                cover: config.cover,
                title: config.title,
                autoPlay: isActive,
                loop: true,
                mute: config.mute,
              ),
              renderer: PlayerRenderer.vertical,
              // 传入预加载控制器：AppVideo 不会重复 initialize，也不负责 dispose
              preloadedController: _pooled(index),
              gestureConfig: widget.gestureConfig,
            );
          } else {
            videoWidget = _buildCoverPlaceholder(config);
          }

          final page = _KeepAlivePage(
            child: widget.itemBuilder != null
                ? widget.itemBuilder!(context, config, videoWidget)
                : _buildDefaultPage(config, videoWidget),
          );

          return page;
        },
      ),
    );
  }

  Widget _buildDefaultPage(PlayerConfig config, Widget videoWidget) {
    return Stack(
      children: [
        videoWidget,
        if (config.title != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: Text(
                config.title!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCoverPlaceholder(PlayerConfig config) {
    final cover = config.cover;
    if (cover != null && cover.isNotEmpty) {
      return Image.network(
        cover,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black87),
      );
    }
    return const ColoredBox(color: Colors.black);
  }
}

// ─── KeepAlive 包裹器 ─────────────────────────────────────────────────────────

/// 让 PageView 中的页面在滑走后保持 Widget State 存活。
///
/// 配合控制器池使用：页面保活 → AppVideo State 不销毁 →
/// 已 initialize 的控制器无需重新走初始化流程。
class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 要求
    return widget.child;
  }
}
