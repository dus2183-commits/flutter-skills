import 'package:flutter/material.dart';

import '../../core/media/player/player_config.dart';
import 'app_video.dart';

/// 短视频 PageView（抖音风格）
///
/// 全屏竖屏,上下滑动切换视频。
/// 自动播放当前页,暂停其他页。
///
/// 用法:
/// ```dart
/// ShortVideoPageView(
///   videos: [
///     PlayerConfig(link: PlayerLink(url: '...'), cover: '...'),
///     PlayerConfig(link: PlayerLink(url: '...'), cover: '...'),
///   ],
///   onPageChanged: (index) => print('当前第 $index 个'),
///   itemBuilder: (context, config, videoWidget) {
///     // 自定义叠加层 (点赞/评��/分享按钮)
///     return Stack(
///       children: [
///         videoWidget,
///         Positioned(right: 16, bottom: 100, child: _buildActions()),
///       ],
///     );
///   },
/// )
/// ```
class ShortVideoPageView extends StatefulWidget {
  /// ��频配置列表
  final List<PlayerConfig> videos;

  /// 页面切换回调
  final ValueChanged<int>? onPageChanged;

  /// 自定义每个视频页面的构建
  ///
  /// [config] 当前视频配置
  /// [videoWidget] 默认的 AppVideo Widget
  /// 返回你自定义的页面 (通常是 Stack 叠加按钮)
  final Widget Function(BuildContext context, PlayerConfig config, Widget videoWidget)? itemBuilder;

  /// 加载更多回调 (滑到倒数第 N 个时触发)
  final VoidCallback? onLoadMore;

  /// 触发加载更多的阈值 (默认倒数第 3 个)
  final int loadMoreThreshold;

  const ShortVideoPageView({
    super.key,
    required this.videos,
    this.onPageChanged,
    this.itemBuilder,
    this.onLoadMore,
    this.loadMoreThreshold = 3,
  });

  @override
  State<ShortVideoPageView> createState() => _ShortVideoPageViewState();
}

class _ShortVideoPageViewState extends State<ShortVideoPageView> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    widget.onPageChanged?.call(index);

    // 接近底部时触发加载更多
    if (widget.onLoadMore != null &&
        index >= widget.videos.length - widget.loadMoreThreshold) {
      widget.onLoadMore!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.videos.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final config = widget.videos[index];

          // 只有当前页和相邻页才渲染视频 (性能优化)
          final shouldRender = (index - _currentPage).abs() <= 1;

          Widget videoWidget;
          if (shouldRender) {
            videoWidget = AppVideo(
              config: PlayerConfig(
                link: config.link,
                cover: config.cover,
                title: config.title,
                autoPlay: index == _currentPage, // 只有当前页自动播放
                loop: true, // 短视频默认循环
                mute: config.mute,
              ),
              renderer: PlayerRenderer.vertical,
            );
          } else {
            // 非相邻页只显示封面
            videoWidget = _buildCoverPlaceholder(config);
          }

          if (widget.itemBuilder != null) {
            return widget.itemBuilder!(context, config, videoWidget);
          }

          // 默认布局: 视频 + 底部标题
          return Stack(
            children: [
              videoWidget,
              // ���部渐变 + 标题
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
        },
      ),
    );
  }

  Widget _buildCoverPlaceholder(PlayerConfig config) {
    if (config.cover != null) {
      return Image.network(
        config.cover!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return Container(color: Colors.black);
  }
}
