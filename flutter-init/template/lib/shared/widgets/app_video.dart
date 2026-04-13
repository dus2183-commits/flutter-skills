import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../core/media/player/adapter/player_adapter.dart';
import '../../core/media/player/player_config.dart';

/// 统一视频播放组件
///
/// IO 和 Web 共用同一套 UI（手势/进度条/按钮），
/// 差异通过 [PlayerAdapter] 抽象层屏蔽。
///
/// 手势控制:
/// - 单击: 显示/隐藏 UI
/// - 双击: 播放/暂停
/// - 左右滑: 进度
/// - 左上下滑: 亮度 (仅 IO)
/// - 右上下滑: 音量
/// - 长按: 3x 加速 (仅 IO)
class AppVideo extends StatefulWidget {
  final PlayerConfig config;
  final PlayerRenderer renderer;
  final VoidCallback? onComplete;
  final ValueChanged<Duration>? onPosition;

  const AppVideo({
    super.key,
    required this.config,
    this.renderer = PlayerRenderer.horizontal,
    this.onComplete,
    this.onPosition,
  });

  @override
  State<AppVideo> createState() => _AppVideoState();
}

class _AppVideoState extends State<AppVideo>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late PlayerAdapter _adapter;
  VideoPlayerController? _ioController; // 仅 IO 端

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
    _initPlayer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uiTimer?.cancel();
    _refreshTimer?.cancel();
    _uiAnim.dispose();
    _adapter.dispose();
    _ioController?.dispose();
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
      if (url.startsWith('file:')) {
        _ioController = VideoPlayerController.file(File(url.replaceFirst('file:', '')));
      } else {
        _ioController = VideoPlayerController.networkUrl(Uri.parse(url));
      }
      _adapter = createAdapter(controller: _ioController);
    }

    try {
      await _adapter.initPlayer();
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
    if (_verticalPos == 'left') {
      final b = await ScreenBrightness.instance.application;
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
      await ScreenBrightness.instance.setApplicationScreenBrightness(val);
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

    Widget content = GestureDetector(
      onTap: _onTap,
      onDoubleTap: _onDoubleTap,
      onHorizontalDragStart: _onHDragStart,
      onHorizontalDragUpdate: _onHDragUpdate,
      onHorizontalDragEnd: _onHDragEnd,
      onVerticalDragStart: _onVDragStart,
      onVerticalDragUpdate: _onVDragUpdate,
      onVerticalDragEnd: _onVDragEnd,
      onLongPressStart: _onLongPressStart,
      onLongPressEnd: _onLongPressEnd,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. 视频画面
          videoSurface,

          // 2. 播放/暂停 (随 UI 动画)
          FadeTransition(
            opacity: _uiAnim,
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
        // 迷你进度条 (UI 隐藏时)
        FadeTransition(
          opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_uiAnim),
          child: Container(
            height: 3,
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ),
        // 完整控制栏
        SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(_uiAnim),
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
                // 播放/暂停
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
              ],
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
