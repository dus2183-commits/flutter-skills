import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../core/media/player/adapter/player_adapter.dart';
import '../../core/media/player/player_config.dart';

/// 外部播放器控制器
///
/// 用于在 [AppVideo] 外部控制播放、暂停、跳转等。
/// 适用于广告插入、片头动画、外部按钮等需要干预播放状态的场景。
///
/// 用法:
/// ```dart
/// final ctrl = AppVideoController();
///
/// AppVideo(config: PlayerConfig(...), controller: ctrl)
///
/// // 外部控制
/// ctrl.pause();
/// ctrl.play();
/// ctrl.seekTo(Duration(seconds: 30));
/// ```
class AppVideoController {
  _AppVideoState? _state;

  void _attach(_AppVideoState s) => _state = s;
  void _detach() => _state = null;

  /// 播放器是否就绪（已初始化完成）
  bool get isReady => _state?._initialized ?? false;

  /// 当前是否正在播放
  bool get isPlaying => _state?._adapter.isPlaying ?? false;

  /// 当前播放位置
  Duration get position => _state?._adapter.position ?? Duration.zero;

  /// 视频总时长
  Duration get duration => _state?._adapter.duration ?? Duration.zero;

  /// 播放（已在播放则忽略）
  void play() {
    final a = _state?._adapter;
    if (a != null && !a.isPlaying) a.playOrPause();
  }

  /// 暂停
  void pause() => _state?._adapter.pause();

  /// 播放 / 暂停切换
  void toggle() => _state?._adapter.playOrPause();

  /// 跳转到指定位置
  void seekTo(Duration position) => _state?._adapter.seek(position);
}

/// 手势开关配置
///
/// 控制 [AppVideo] 响应哪些手势，避免在不同场景下产生冲突。
///
/// 预设：
/// - [AppVideoGestureConfig.full]       全功能（横屏播放器默认）
/// - [AppVideoGestureConfig.shortVideo] 短视频模式，禁用竖向手势，
///   让外层 PageView 接管上下滑动切换视频
class AppVideoGestureConfig {
  /// 横向拖动调整进度
  final bool enableSeek;

  /// 右半屏竖向拖动调整音量
  final bool enableVolume;

  /// 左半屏竖向拖动调整亮度（仅 iOS / Android）
  final bool enableBrightness;

  /// 长按 3× 加速（仅 iOS / Android）
  final bool enableLongPress;

  const AppVideoGestureConfig({
    this.enableSeek = true,
    this.enableVolume = true,
    this.enableBrightness = true,
    this.enableLongPress = true,
  });

  /// 全功能模式（横屏播放器默认值）
  static const full = AppVideoGestureConfig();

  /// 短视频模式 — 禁用竖向手势，PageView 可自由上下滑动切换视频
  static const shortVideo = AppVideoGestureConfig(
    enableVolume: false,
    enableBrightness: false,
  );

  /// 是否需要注册竖向拖动（任一子功能启用即注册）
  bool get _needsVertical => enableVolume || enableBrightness;
}

/// 统一视频播放组件
///
/// IO 和 Web 共用同一套 UI（手势/进度条/按钮），
/// 差异通过 [PlayerAdapter] 抽象层屏蔽。
///
/// 手势控制（可通过 [gestureConfig] 按需开关）:
/// - 单击: 显示/隐藏 UI
/// - 双击: 播放/暂停
/// - 左右滑: 进度（[AppVideoGestureConfig.enableSeek]）
/// - 左上下滑: 亮度，仅 IO（[AppVideoGestureConfig.enableBrightness]）
/// - 右上下滑: 音量（[AppVideoGestureConfig.enableVolume]）
/// - 长按: 3× 加速，仅 IO（[AppVideoGestureConfig.enableLongPress]）
class AppVideo extends StatefulWidget {
  final PlayerConfig config;
  final PlayerRenderer renderer;
  final VoidCallback? onComplete;
  final ValueChanged<Duration>? onPosition;

  /// 预加载的 VideoPlayerController（由上层 Pool 管理生命周期）
  ///
  /// 传入时本 Widget 不会自行创建/dispose controller，避免重复初始化。
  final VideoPlayerController? preloadedController;

  /// 手势开关配置，默认全功能。
  ///
  /// 在竖向 PageView 短视频场景中传入 [AppVideoGestureConfig.shortVideo]
  /// 可禁用竖向拖动，避免与 PageView 手势冲突。
  final AppVideoGestureConfig gestureConfig;

  /// 外部控制器，用于在 Widget 外部控制播放 / 暂停 / 跳转。
  final AppVideoController? controller;

  /// 是否处于全屏模式（由 [AppVideo] 内部全屏路由传入，外部无需设置）。
  ///
  /// true 时底部栏显示"退出全屏"按钮，点击后 pop 当前路由。
  final bool isFullscreen;

  const AppVideo({
    super.key,
    required this.config,
    this.renderer = PlayerRenderer.horizontal,
    this.onComplete,
    this.onPosition,
    this.preloadedController,
    this.gestureConfig = AppVideoGestureConfig.full,
    this.controller,
    this.isFullscreen = false,
  });

  @override
  State<AppVideo> createState() => _AppVideoState();
}

class _AppVideoState extends State<AppVideo>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late PlayerAdapter _adapter;
  VideoPlayerController? _ioController; // 仅 IO 端

  /// 是否使用外部传入的 controller（不由本 State 负责 dispose）
  bool _isExternalController = false;

  bool _initialized = false;

  // UI 控制
  late AnimationController _uiAnim;
  Timer? _uiTimer;
  // 定时刷新 UI（读 adapter 状态）
  Timer? _refreshTimer;

  // 手势
  String _gesture = '';
  Duration _dragPos = Duration.zero;
  double? _prevDx;
  int? _dragPosMs;
  String _verticalPos = '';
  double? _verticalVal;
  bool _verticalInit = false;
  String _longPressPos = '';
  final double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _uiAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    widget.controller?._attach(this);
    _initPlayer();
  }

  @override
  void didUpdateWidget(AppVideo old) {
    super.didUpdateWidget(old);
    // autoPlay 切换时同步播放/暂停（PageView 切换页面时触发）
    if (!kIsWeb && _ioController != null && _initialized) {
      if (widget.config.autoPlay && !old.config.autoPlay) {
        _ioController!.play();
      } else if (!widget.config.autoPlay && old.config.autoPlay) {
        _ioController!.pause();
      }
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    WidgetsBinding.instance.removeObserver(this);
    _uiTimer?.cancel();
    _refreshTimer?.cancel();
    _uiAnim.dispose();
    _adapter.dispose(); // ownsController=false 时不会 dispose _ioController
    // 只有自己创建的 controller 才负责 dispose
    if (!_isExternalController) _ioController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) return;
    if (state != AppLifecycleState.resumed && _adapter.isPlaying) {
      _adapter.pause();
    }
  }

  Future<void> _initPlayer() async {
    final url = widget.config.link.url;

    if (kIsWeb) {
      _adapter = createAdapter();
    } else {
      if (widget.preloadedController != null) {
        // 使用上层 Pool 预加载的 controller
        _ioController = widget.preloadedController;
        _isExternalController = true;
      } else if (url.startsWith('file:')) {
        _ioController = VideoPlayerController.file(File(url.replaceFirst('file:', '')));
      } else {
        _ioController = VideoPlayerController.networkUrl(Uri.parse(url));
      }
      _adapter = createAdapter(controller: _ioController, ownsController: !_isExternalController);
    }

    try {
      if (_isExternalController && _ioController != null) {
        // 预加载 controller 可能仍在初始化中，等它完成而不是重新 initialize
        if (!_ioController!.value.isInitialized) {
          await _waitForControllerInit(_ioController!);
        }
        // 告知 adapter 已初始化完毕
        _adapter.isInitialized = _ioController!.value.isInitialized;
      } else {
        await _adapter.initPlayer();
      }
    } catch (_) {
      // 错误由 adapter.errorDescription 暴露
    }

    if (!kIsWeb && _ioController != null) {
      if (widget.config.loop) _ioController!.setLooping(true);
      if (widget.config.mute) _ioController!.setVolume(0);
      if (widget.config.autoPlay) _ioController!.play();
    }

    // 100ms 刷新 UI
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || _adapter.disposed) return;

      // 播放完成回调
      if (_adapter.isCompleted) widget.onComplete?.call();
      widget.onPosition?.call(_adapter.position);

      setState(() {});
    });

    if (mounted) setState(() => _initialized = true);
  }

  /// 等待外部 controller 初始化完成（监听 ValueNotifier，不重复 initialize）
  Future<void> _waitForControllerInit(VideoPlayerController ctrl) async {
    if (ctrl.value.isInitialized || ctrl.value.hasError) return;
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

  // ═══════════════ 手势 ═══════════════

  void _onTap() {
    if (_uiAnim.isCompleted) {
      _uiAnim.reverse();
    } else {
      _uiAnim.forward();
      _autoHide();
    }
  }

  void _onDoubleTap() async {
    await _adapter.playOrPause();
    _autoHide(seconds: 3);
  }

  void _onHDragStart(DragStartDetails d) {
    _uiTimer?.cancel();
    if (_uiAnim.isDismissed) _uiAnim.forward();
    _prevDx = d.globalPosition.dx;
    _dragPosMs = _adapter.position.inMilliseconds;
  }

  void _onHDragUpdate(DragUpdateDetails d) {
    final dx = d.globalPosition.dx;
    final w = MediaQuery.of(context).size.width;
    final dur = _adapter.duration.inMilliseconds.toDouble();
    if (dur <= 0) return;
    final diff = ((_prevDx ?? dx) - dx).abs();
    final ratio = diff / w;
    final shift = (ratio * dur).toInt();
    final forward = dx > (_prevDx ?? dx);
    var newPos = forward ? (_dragPosMs ?? 0) + shift : (_dragPosMs ?? 0) - shift;
    newPos = newPos.clamp(0, dur.toInt());
    setState(() {
      _gesture = 'horizontal';
      _prevDx = dx;
      _dragPosMs = newPos;
      _dragPos = Duration(milliseconds: newPos);
    });
  }

  void _onHDragEnd(DragEndDetails d) {
    _adapter.seek(_dragPos);
    setState(() => _gesture = '');
    _autoHide();
  }

  void _onVDragStart(DragStartDetails d) async {
    if (kIsWeb) return;
    final w = MediaQuery.of(context).size.width;
    _verticalPos = d.globalPosition.dx > w / 2 ? 'right' : 'left';

    // 根据配置跳过禁用的一侧
    if (_verticalPos == 'left' && !widget.gestureConfig.enableBrightness) return;
    if (_verticalPos == 'right' && !widget.gestureConfig.enableVolume) return;

    if (_verticalPos == 'left') {
      final b = await ScreenBrightness.instance.current;
      _verticalInit = true;
      setState(() => _verticalVal = b);
    } else {
      _verticalInit = true;
      setState(() => _verticalVal = _adapter.volume);
    }
  }

  void _onVDragUpdate(DragUpdateDetails d) async {
    if (kIsWeb || !_verticalInit) return;
    final up = d.delta.dy < 0;
    var val = (_verticalVal ?? 0) + (up ? 0.02 : -0.02);
    val = val.clamp(0.0, 1.0);
    if (_verticalPos == 'left') {
      await ScreenBrightness.instance.setScreenBrightness(val);
    } else {
      _adapter.setVolume(val);
    }
    setState(() {
      _gesture = 'vertical';
      _verticalVal = val;
    });
  }

  void _onVDragEnd(DragEndDetails d) {
    setState(() {
      _gesture = '';
      _verticalInit = false;
    });
  }

  void _onLongPressStart(LongPressStartDetails d) {
    if (!_adapter.isPlaying || kIsWeb) return;
    setState(() => _longPressPos = 'active');
    _adapter.setRate(3.0);
  }

  void _onLongPressEnd(LongPressEndDetails d) {
    _adapter.setRate(_speed);
    setState(() => _longPressPos = '');
  }

  void _autoHide({int seconds = 5}) {
    _uiTimer?.cancel();
    _uiTimer = Timer(Duration(seconds: seconds), () {
      if (mounted && _uiAnim.isCompleted) _uiAnim.reverse();
    });
  }

  /// 进入全屏
  ///
  /// 1. 暂停当前播放
  /// 2. 强制横屏 + 沉浸式
  /// 3. push [_FullscreenPage]（共享同一个 VideoPlayerController）
  /// 4. 返回时恢复竖屏 + 系统 UI，并恢复播放状态
  Future<void> _enterFullscreen() async {
    if (!mounted || kIsWeb || _ioController == null) return;

    final wasPlaying = _adapter.isPlaying;
    _adapter.pause();

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (!mounted) return;
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => _FullscreenPage(
          config: widget.config,
          preloadedController: _ioController,
          gestureConfig: widget.gestureConfig,
        ),
      ),
    );

    // 退出全屏后恢复
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (mounted && wasPlaying) _adapter.playOrPause();
  }

  // ═══════════════ 构建 ═══════════════

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('app_video_${widget.config.link.url}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction < 0.3 && _adapter.isPlaying) {
          _adapter.pause();
        }
      },
      child: _initialized ? _buildVideoUI() : _buildPlaceholder(),
    );
  }

  /// 统一 UI 层 — IO 和 Web 共用
  Widget _buildVideoUI() {
    // 视频画面 — IO 和 Web 统一通过 adapter.videoWidget()
    final videoSurface = SizedBox.expand(
      child: FittedBox(
        fit: widget.renderer == PlayerRenderer.vertical ? BoxFit.cover : BoxFit.contain,
        child: SizedBox(
          width: kIsWeb ? 1920 : (_ioController?.value.size.width ?? 1920),
          height: kIsWeb ? 1080 : (_ioController?.value.size.height ?? 1080),
          child: _adapter.videoWidget(),
        ),
      ),
    );

    final gc = widget.gestureConfig;
    Widget content = GestureDetector(
      onTap: _onTap,
      onDoubleTap: _onDoubleTap,
      onHorizontalDragStart: gc.enableSeek ? _onHDragStart : null,
      onHorizontalDragUpdate: gc.enableSeek ? _onHDragUpdate : null,
      onHorizontalDragEnd: gc.enableSeek ? _onHDragEnd : null,
      onVerticalDragStart: gc._needsVertical ? _onVDragStart : null,
      onVerticalDragUpdate: gc._needsVertical ? _onVDragUpdate : null,
      onVerticalDragEnd: gc._needsVertical ? _onVDragEnd : null,
      onLongPressStart: gc.enableLongPress ? _onLongPressStart : null,
      onLongPressEnd: gc.enableLongPress ? _onLongPressEnd : null,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. 视频画面
          videoSurface,

          // 2. 播放/暂停中心按钮（随 UI 动画淡入，点击切换播放状态）
          FadeTransition(
            opacity: _uiAnim,
            child: GestureDetector(
              // ★ 独立 GestureDetector：点击圆形按钮直接切换播放，
              //   不触发外层 onTap（外层负责显示/隐藏 UI）
              onTap: _onDoubleTap,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(16),
                child: Icon(
                  _adapter.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),

          // 3. 进度拖拽提示
          if (_gesture == 'horizontal')
            Positioned(
              top: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_fmt(_dragPos)} / ${_fmt(_adapter.duration)}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),

          // 4. 亮度/音量提示
          if (_gesture == 'vertical' && _verticalVal != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _verticalPos == 'left'
                        ? Icons.wb_sunny_rounded
                        : (_verticalVal! == 0 ? Icons.volume_off : Icons.volume_up),
                    color: Colors.white, size: 20,
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    child: LinearProgressIndicator(
                      value: _verticalVal!,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                ],
              ),
            ),

          // 5. 长按加速提示
          if (_longPressPos.isNotEmpty)
            Positioned(
              top: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fast_forward, color: Colors.white, size: 18),
                    SizedBox(width: 4),
                    Text('3.0x', style: TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
              ),
            ),

          // 6. 底部进度条 (横屏模式)
          if (widget.renderer == PlayerRenderer.horizontal)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildBottomBar(),
            ),
        ],
      ),
    );

    if (widget.renderer == PlayerRenderer.horizontal) {
      return AspectRatio(
        aspectRatio: _adapter.videoAspectRatio,
        child: content,
      );
    }
    return content;
  }

  Widget _buildBottomBar() {
    final pos = _adapter.position;
    final dur = _adapter.duration;
    final progress = dur.inMilliseconds > 0
        ? pos.inMilliseconds / dur.inMilliseconds
        : 0.0;
    final bufProgress = _adapter.buffer.inMilliseconds > 0 && dur.inMilliseconds > 0
        ? _adapter.buffer.inMilliseconds / dur.inMilliseconds
        : 0.0;

    return Stack(
      children: [
        // 完整控制栏（UI 显示时从底部滑入）
        // ★ ClipRect 强制裁剪：SlideTransition 使用 GPU 合成层，
        //   父级 Stack 的 Clip.hardEdge 有时无法裁剪合成层，
        //   导致控制栏在 dismissed 状态下仍部分可见（向下偏移约 30px）。
        //   ClipRect 在合成层边界上强制裁剪，彻底消除溢出。
        ClipRect(
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(_uiAnim),
            child: Container(
              height: 44,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _adapter.playOrPause(),
                    child: Icon(
                      _adapter.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white, size: 28,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_fmt(pos), style: const TextStyle(color: Colors.white, fontSize: 12)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        ),
                        child: Slider(
                          value: progress.clamp(0.0, 1.0),
                          secondaryTrackValue: bufProgress.clamp(0.0, 1.0),
                          onChanged: (v) {
                            final target = Duration(milliseconds: (v * dur.inMilliseconds).round());
                            _adapter.seek(target);
                          },
                          activeColor: Theme.of(context).primaryColor,
                          secondaryActiveColor: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                          inactiveColor: Colors.white24,
                        ),
                      ),
                    ),
                  ),
                  Text(_fmt(dur), style: const TextStyle(color: Colors.white, fontSize: 12)),
                  // 全屏按钮（仅原生端显示）
                  if (!kIsWeb) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: widget.isFullscreen
                          ? () => Navigator.of(context).pop()
                          : _enterFullscreen,
                      child: Icon(
                        widget.isFullscreen
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // 迷你进度条（UI 隐藏时贴在视频最底部）
        // ★ Positioned(bottom:0) 确保始终贴底，不受完整控制栏高度影响
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: FadeTransition(
            opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_uiAnim),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              minHeight: 3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    Widget ph = Container(color: Colors.black);
    if (widget.config.cover != null) {
      ph = Stack(
        alignment: Alignment.center,
        children: [
          Image.network(widget.config.cover!, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
          Container(
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
            padding: const EdgeInsets.all(16),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
          ),
        ],
      );
    }
    return widget.renderer == PlayerRenderer.horizontal
        ? AspectRatio(aspectRatio: 16 / 9, child: ph)
        : ph;
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 全屏播放页（由 AppVideo._enterFullscreen() 内部使用，外部无需直接使用）
// ═══════════════════════════════════════════════════════════════════════════

class _FullscreenPage extends StatefulWidget {
  final PlayerConfig config;
  final VideoPlayerController? preloadedController;
  final AppVideoGestureConfig gestureConfig;

  const _FullscreenPage({
    required this.config,
    this.preloadedController,
    this.gestureConfig = AppVideoGestureConfig.full,
  });

  @override
  State<_FullscreenPage> createState() => _FullscreenPageState();
}

class _FullscreenPageState extends State<_FullscreenPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // 用 MediaQuery.removePadding 消除全屏时 SafeArea 留出的边距
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        child: Center(
          child: AppVideo(
            config: PlayerConfig(
              link: widget.config.link,
              cover: widget.config.cover,
              title: widget.config.title,
              autoPlay: true,
              loop: widget.config.loop,
              mute: widget.config.mute,
            ),
            renderer: PlayerRenderer.horizontal,
            preloadedController: widget.preloadedController,
            gestureConfig: widget.gestureConfig,
            isFullscreen: true, // 触发底部栏显示"退出全屏"按钮
          ),
        ),
      ),
    );
  }
}
