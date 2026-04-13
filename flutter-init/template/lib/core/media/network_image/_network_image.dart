/// 加密/普通网络图片 — 条件导出入口
///
/// - IO 端 (Android/iOS): 走 dart:io HttpClient + AES 解密 + 磁盘缓存
/// - Web 端: 走 JS fetchImage + IndexedDB 缓存
///
/// 用法:
/// ```dart
/// import 'package:{app}/core/media/network_image/_network_image.dart' as app_network;
///
/// Image(image: app_network.NetworkImage(url, key: decryptKey, cache: true))
/// ```
///
/// 加密判断: URL 含 `.bnc` 后缀自动走 AES 解密,否则正常加载。
export '_io.dart' if (dart.library.js_interop) '_web.dart';
