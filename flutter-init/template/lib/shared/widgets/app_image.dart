import 'package:flutter/material.dart';

// 条件导出: IO 端走 _io.dart (dart:io + AES), Web 端走 _web.dart (JS + IndexedDB)
import '../../core/media/network_image/_network_image.dart' as app_network;

/// 统一图片组件
///
/// 自动处理:
/// - 加密图片解密 (URL 含 `.bnc` 时自动走 AES 解密)
/// - 普通图片正常加载
/// - 磁盘/IndexedDB 缓存
/// - 加载占位 + 错误回退
/// - 圆角裁剪
/// - 三端兼容 (Android/iOS/Web)
///
/// 用法:
/// ```dart
/// // 普通图片
/// AppImage(url: 'https://example.com/photo.jpg', width: 120, height: 80)
///
/// // 加密图片 (URL 含 .bnc,自动解密)
/// AppImage(url: 'https://cdn.example.com/photo.bnc', decryptKey: dynamicKey)
///
/// // 带圆角
/// AppImage(url: item.avatar, width: 48, height: 48, borderRadius: 24)
/// ```
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.decryptKey = '',
    this.cache = true,
    this.placeholder,
    this.errorWidget,
  });

  /// 图片 URL
  ///
  /// - 普通图片: `https://example.com/photo.jpg`
  /// - 加密图片: `https://cdn.example.com/photo.bnc` (含 .bnc 后缀自动解密)
  final String url;

  /// 宽度,null 时自适应
  final double? width;

  /// 高度,null 时自适应
  final double? height;

  /// 填充方式
  final BoxFit fit;

  /// 圆角半径
  final double borderRadius;

  /// 加密图片的解密 key
  ///
  /// 仅在 URL 含 `.bnc` 时使用。
  /// 留空则使用底层 NetworkImage 的默认 key。
  final String decryptKey;

  /// 是否启用磁盘缓存 (默认 true)
  final bool cache;

  /// 自定义加载占位 Widget
  final Widget? placeholder;

  /// 自定义错误 Widget
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    Widget image = Image(
      image: app_network.NetworkImage(
        url,
        key: decryptKey,
        cache: cache,
      ),
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ?? _defaultPlaceholder();
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? _defaultError();
      },
    );

    if (borderRadius > 0) {
      image = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: image,
      );
    }

    return image;
  }

  Widget _defaultPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _defaultError() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }
}
