import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Public API
// ═══════════════════════════════════════════════════════════════════════════

/// 单个短视频数据配置
class ShortVideoConfig {
  /// 唯一标识，用于 Widget key（可传业务 id）
  final String id;

  /// 视频播放地址（http/https）
  final String videoUrl;

  /// 封面图地址
  final String coverUrl;

  const ShortVideoConfig({
    required this.id,
    required this.videoUrl,
    required this.coverUrl,
  });
}

/// 短视频上下滑动播放组件（可复用）
///
/// 功能:
/// - 垂直 PageView 切换视频
/// - **不** 拦截竖向手势（PageView 可正常上下滑）
/// - Controller 预加载池：当前页 ± 2 提前 initialize，秒开
/// - AutomaticKeepAliveClientMixin：已访问页保活，无需重新 initialize
/// - 单击视频：播放 / 暂停
/// - 底部缓冲进度条 + 播放进度条
///
/// 用法:
/// ```dart
/// ShortVideoFeed(
///   videos: [
///     ShortVideoConfig(id: '1', videoUrl: 'https://...', coverUrl: 'https://...'),
///   ],
///   onLoadMore: _loadMore,
///   onPageChanged: (index) => setState(() => _currentPage = index),
///   overlayBuilder: (context, index, video) {
///     // 在视频上方叠加自定义 UI（点赞 / 评论 / 信息等）
///     return Stack(children: [
///       Positioned(bottom: 80, left: 16, child: Text('标题')),
///       Positioned(right: 10, bottom: 100, child: _ActionButtons()),
///     ]);
///   },
/// )
/// ```
class ShortVideoFeed extends StatefulWidget {
  /// 视频列表
  final List<ShortVideoConfig> videos;

  /// 起始索引（默认 0）
  final int initialIndex;

  /// 页面切换回调
  final ValueChanged<int>? onPageChanged;

  /// 加载更多回调（滑到倒数 [loadMoreThreshold] 个时触发）
  final VoidCallback? onLoadMore;

  /// 触发加载更多的阈值，默认倒数第 3 个
  final int loadMoreThreshold;

  /// 自定义叠加层 Builder
  ///
  /// 叠加在视频画面上方，用于实现点赞 / 评论 / 分享 / 标题等业务 UI。
  /// 返回的 Widget 与视频 Widget 一起放入 [Stack]，推荐用 [Positioned] 定位。
  /// - [context] BuildContext
  /// - [index]   当前视频在列表中的索引
  /// - [video]   当前视频配置
  final Widget Function(
    BuildContext context,
    int index,
    ShortVideoConfig video,
  )? overlayBuilder;

  const ShortVideoFeed({
    super.key,
    required this.videos,
    this.initialIndex = 0,
    this.onPageChanged,
    this.onLoadMore,
    this.loadMoreThreshold = 3,
    this.overlayBuilder,
  });

  @override
  State<ShortVideoFeed> createState() => _ShortVideoFeedState();
}

// ═══════════════════════════════════════════════════════════════════════════
// Feed State — 控制器池 + PageView
// ═══════════════════════════════════════════════════════════════════════════

class _ShortVideoFeedState extends State<ShortVideoFeed> {
  late final PageController _pageController;
  int _currentPage = 0;

  /// VideoPlayerController 预加载池（仅 iOS / Android）
  ///
  /// key = videoUrl，value = 已调用 initialize() 的 controller。
  /// 保持 currentPage ± 2 范围内的 controller 存活，其余 dispose 释放内存。
  final Map<String, VideoPlayerController> _pool = {};

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex.clamp(
      0,
      (widget.videos.length - 1).clamp(0, double.maxFinite.toInt()),
    );
    _pageController = PageController(initialPage: _currentPage);
    if (!kIsWeb) _preload(_currentPage);
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

  // ── 预加载逻辑 ──────────────────────────────────────────────────────────

  /// 预初始化 [from] ~ [from+2] 的 controller，释放 [from-3] 以远的
  void _preload(int from) {
    // 预加载 from ~ from+2
    for (var i = from; i <= from + 2 && i < widget.videos.length; i++) {
      final url = widget.videos[i].videoUrl;
      if (url.isEmpty || _pool.containsKey(url)) continue;
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      _pool[url] = ctrl;
      ctrl.initialize().catchError((_) {});
    }

    // 释放过远的 controller（from-3 之前）
    final stale = <String>[];
    for (final entry in _pool.entries) {
      final idx = widget.videos.indexWhere((v) => v.videoUrl == entry.key);
      if (idx >= 0 && idx < from - 2) {
        entry.value.dispose();
        stale.add(entry.key);
      }
    }
    for (final url in stale) _pool.remove(url);
  }

  /// 取池中已预加载的 controller（可能仍在 initializing，_SvPlayer 会等待）
  VideoPlayerController? _pooled(int index) {
    if (index < 0 || index >= widget.videos.length) return null;
    return _pool[widget.videos[index].videoUrl];
  }

  // ── 页面切换 ────────────────────────────────────────────────────────────

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    widget.onPageChanged?.call(index);
    if (!kIsWeb) _preload(index);

    if (widget.onLoadMore != null &&
        index >= widget.videos.length - widget.loadMoreThreshold) {
      widget.onLoadMore!();
    }
  }

  // ── 构建 ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) return const SizedBox.shrink();

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: widget.videos.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (ctx, index) {
        final video = widget.videos[index];
        final isActive = index == _currentPage;
        final isNear = (index - _currentPage).abs() <= 1;

        return _KeepAliveItem(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 核心播放器（仅 isNear 范围内才渲染视频，节省资源）
              if (isNear)
                _SvPlayer(
                  key: ValueKey('svf_${video.id}'),
                  videoUrl: video.videoUrl,
                  coverUrl: video.coverUrl,
                  autoPlay: isActive,
                  preloadedController: _pooled(index),
                )
              else
                _SvCover(coverUrl: video.coverUrl),

              // 业务叠加层（点赞 / 评论 / 信息等）
              if (widget.overlayBuilder != null)
                widget.overlayBuilder!(ctx, index, video),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _KeepAliveItem — 保持页面 State 存活
// ═══════════════════════════════════════════════════════════════════════════

class _KeepAliveItem extends StatefulWidget {
  final Widget child;
  const _KeepAliveItem({required this.child});

  @override
  State<_KeepAliveItem> createState() => _KeepAliveItemState();
}

class _KeepAliveItemState extends State<_KeepAliveItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _SvPlayer — 轻量视频播放器（只注册 onTap，不拦截垂直滑动）
// ═══════════════════════════════════════════════════════════════════════════

class _SvPlayer extends StatefulWidget {
  const _SvPlayer({
    super.key,
    required this.videoUrl,
    required this.coverUrl,
    required this.autoPlay,
    this.preloadedController,
  });

  final String videoUrl;
  final String coverUrl;
  final bool autoPlay;

  /// 由上层 Pool 预初始化的 controller
  ///
  /// 若提供，本 Widget 不再调用 initialize()，也不负责 dispose（由 Pool 管理）。
  final VideoPlayerController? preloadedController;

  @override
  State<_SvPlayer> createState() => _SvPlayerState();
}

class _SvPlayerState extends State<_SvPlayer> with WidgetsBindingObserver {
  VideoPlayerController? _ctrl;

  /// 是否由本 State 负责 dispose（外部传入时不负责）
  bool _ownsCtrl = true;

  bool _initialized = false;
  bool _userPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) _initController();
  }

  @override
  void didUpdateWidget(_SvPlayer old) {
    super.didUpdateWidget(old);
    if (old.autoPlay == widget.autoPlay) return;
    final ctrl = _ctrl;
    if (ctrl == null || !_initialized) return;
    if (widget.autoPlay && !_userPaused) {
      ctrl.play();
    } else {
      ctrl.pause();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _ctrl;
    if (ctrl == null || !_initialized) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ctrl.pause();
    } else if (state == AppLifecycleState.resumed &&
        widget.autoPlay &&
        !_userPaused) {
      ctrl.play();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsCtrl) {
      _ctrl?.dispose();
    } else {
      _ctrl?.pause(); // 外部 controller 由 Pool 管理，只需暂停
    }
    super.dispose();
  }

  // ── 初始化 ──────────────────────────────────────────────────────────────

  Future<void> _initController() async {
    VideoPlayerController ctrl;

    if (widget.preloadedController != null) {
      ctrl = widget.preloadedController!;
      _ownsCtrl = false;
    } else {
      ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      _ownsCtrl = true;
    }
    _ctrl = ctrl;

    try {
      if (!ctrl.value.isInitialized) {
        await _waitForInit(ctrl);
      }
      await ctrl.setLooping(true);
    } catch (_) {
      // 加载失败时静默处理，显示封面
    }

    if (!mounted) return;
    setState(() => _initialized = true);

    // ★ 补偿竞态：didUpdateWidget 在 _initialized=false 时会跳过 play()。
    //   初始化完成后读最新的 widget.autoPlay 确保状态正确。
    if (widget.autoPlay && !_userPaused) {
      _ctrl?.play();
    }
  }

  /// 等待外部 controller 初始化（监听 ValueNotifier，不重复调用 initialize）
  Future<void> _waitForInit(VideoPlayerController ctrl) async {
    if (ctrl.value.isInitialized || ctrl.value.hasError) return;

    if (_ownsCtrl) {
      await ctrl.initialize();
      return;
    }

    final completer = Completer<void>();
    void listener() {
      if (ctrl.value.isInitialized || ctrl.value.hasError) {
        if (!completer.isCompleted) completer.complete();
      }
    }
    ctrl.addListener(listener);
    await Future.any([
      completer.future,
      Future.delayed(const Duration(seconds: 10)),
    ]);
    ctrl.removeListener(listener);
  }

  // ── 手势 ────────────────────────────────────────────────────────────────

  void _togglePlay() {
    final ctrl = _ctrl;
    if (ctrl == null || !_initialized) return;
    if (ctrl.value.isPlaying) {
      ctrl.pause();
      _userPaused = true;
    } else {
      ctrl.play();
      _userPaused = false;
    }
    setState(() {});
  }

  // ── 构建 ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !_initialized || _ctrl == null) {
      return _SvCoverLoading(
        coverUrl: widget.coverUrl,
        showSpinner: !kIsWeb && !_initialized,
      );
    }

    final ctrl = _ctrl!;
    final size = ctrl.value.size;
    final w = size.width > 0 ? size.width : 9.0;
    final h = size.height > 0 ? size.height : 16.0;

    return GestureDetector(
      onTap: _togglePlay,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 视频画面（BoxFit.cover 铺满屏幕）
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: w,
                height: h,
                child: VideoPlayer(ctrl),
              ),
            ),
          ),

          // 暂停图标
          if (!ctrl.value.isPlaying) const _SvPlayIcon(),

          // 底部进度条
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _SvProgressBar(controller: ctrl),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 内部 UI 组件
// ═══════════════════════════════════════════════════════════════════════════

/// 封面 + 加载 spinner
class _SvCoverLoading extends StatelessWidget {
  const _SvCoverLoading({required this.coverUrl, required this.showSpinner});

  final String coverUrl;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          coverUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black87),
        ),
        if (showSpinner)
          const Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                color: Colors.white54,
                strokeWidth: 2,
              ),
            ),
          ),
      ],
    );
  }
}

/// 纯封面（渲染窗口外使用，无 spinner）
class _SvCover extends StatelessWidget {
  const _SvCover({required this.coverUrl});
  final String coverUrl;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      coverUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black87),
    );
  }
}

/// 暂停图标
class _SvPlayIcon extends StatelessWidget {
  const _SvPlayIcon();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.45),
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }
}

/// 底部双层进度条（缓冲 + 播放，ValueListenableBuilder 驱动，不触发页面 setState）
class _SvProgressBar extends StatelessWidget {
  const _SvProgressBar({required this.controller});
  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (_, value, __) {
        final dur = value.duration.inMilliseconds;
        final pos = value.position.inMilliseconds;
        final progress = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
        final buffer = (value.buffered.isNotEmpty && dur > 0)
            ? (value.buffered.last.end.inMilliseconds / dur).clamp(0.0, 1.0)
            : 0.0;

        return Stack(
          children: [
            LinearProgressIndicator(
              value: buffer,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Colors.white24),
              minHeight: 2,
            ),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              minHeight: 2,
            ),
          ],
        );
      },
    );
  }
}
