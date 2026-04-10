// TODO Implement this library.// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' as image_provider;
import 'package:flutter/painting.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'queue/_network_image_load_queue.dart';

import '../../crypto/aes_util.dart';
import '../../crypto/hash_util.dart';

// Method signature for _loadAsync decode callbacks.
typedef _SimpleDecoderCallback = Future<ui.Codec> Function(
    ui.ImmutableBuffer buffer);

/// The dart:io implementation of [image_provider.NetworkImage].
@immutable
class NetworkImage
    extends image_provider.ImageProvider<image_provider.NetworkImage>
    implements image_provider.NetworkImage {
  /// Creates an object that fetches the image at the given URL.
  const NetworkImage(this.url,
      {this.key = '', this.cache = true, this.scale = 1.0, this.headers});

  @override
  final String url;

  @override
  final double scale;

  @override
  final Map<String, String>? headers;

  final String key;

  final bool cache;

  // @override
  // final image_provider.WebHtmlElementStrategy webHtmlElementStrategy;

  @override
  Future<NetworkImage> obtainKey(
      image_provider.ImageConfiguration configuration) {
    return SynchronousFuture<NetworkImage>(this);
  }

  @override
  ImageStreamCompleter loadBuffer(image_provider.NetworkImage key,
      image_provider.DecoderBufferCallback decode) {
    // Ownership of this controller is handed off to [_loadAsync]; it is that
    // method's responsibility to close the controller's stream when the image
    // has been loaded or an error is thrown.
    final StreamController<ImageChunkEvent> chunkEvents =
        StreamController<ImageChunkEvent>();

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key as NetworkImage, chunkEvents, decode: decode),
      chunkEvents: chunkEvents.stream,
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<image_provider.ImageProvider>(
            'Image provider', this),
        DiagnosticsProperty<image_provider.NetworkImage>('Image key', key)
      ],
    );
  }

  @override
  ImageStreamCompleter loadImage(image_provider.NetworkImage key,
      image_provider.ImageDecoderCallback decode) {
    // Ownership of this controller is handed off to [_loadAsync]; it is that
    // method's responsibility to close the controller's stream when the image
    // has been loaded or an error is thrown.
    final StreamController<ImageChunkEvent> chunkEvents =
        StreamController<ImageChunkEvent>();

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key as NetworkImage, chunkEvents, decode: decode),
      chunkEvents: chunkEvents.stream,
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<image_provider.ImageProvider>(
            'Image provider', this),
        DiagnosticsProperty<image_provider.NetworkImage>('Image key', key)
      ],
    );
  }

  // Do not access this field directly; use [_httpClient] instead.
  // We set `autoUncompress` to false to ensure that we can trust the value of
  // the `Content-Length` HTTP header. We automatically uncompress the content
  // in our call to [consolidateHttpClientResponseBytes].
  static final HttpClient _sharedHttpClient = HttpClient()
    ..autoUncompress = false;

  static HttpClient get _httpClient {
    HttpClient? client;
    assert(() {
      if (debugNetworkImageHttpClientProvider != null) {
        client = debugNetworkImageHttpClientProvider!();
      }
      return true;
    }());
    return client ?? _sharedHttpClient;
  }

  Future<ui.Codec> _loadAsync(
      NetworkImage key, StreamController<ImageChunkEvent> chunkEvents,
      {required _SimpleDecoderCallback decode}) async {
    try {
      assert(key == this);

      final Uri resolved = Uri.base.resolve(key.url);

      ///优先使用缓存
      if (cache) {
        final Uint8List? bytes = await _loadCache(resolved);
        if (bytes != null) {
          try {
            ///有可能本地文件不完整,会报错,则再次走http请求
            return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
          } catch (e) {}
        }
      }

      final Uint8List bytes = await NetworkImageLoadQueue.get.add(() async {
        final HttpClientRequest request = await _httpClient.getUrl(resolved);

        headers?.forEach((String name, String value) {
          request.headers.add(name, value);
        });
        final HttpClientResponse response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          // The network may be only temporarily unavailable, or the file will be
          // added on the server later. Avoid having future calls to resolve
          // fail to check the network again.
          await response.drain<List<int>>(<int>[]);
          throw image_provider.NetworkImageLoadException(
              statusCode: response.statusCode, uri: resolved);
        }

        Uint8List bytes = await consolidateHttpClientResponseBytes(
          response,
          onBytesReceived: (int cumulative, int? total) {
            chunkEvents.add(ImageChunkEvent(
                cumulativeBytesLoaded: cumulative, expectedTotalBytes: total));
          },
        );
        if (bytes.lengthInBytes == 0) {
          throw Exception('NetworkImage is an empty file: $resolved');
        }

        if (url.contains('.bnc')) {
          bytes = AesUtil.decryptImg(bytes, this.key);
        }

        // 无论是否加密，都进行磁盘缓存
        if (cache) {
          _saveCache(resolved, bytes);
        }
        return bytes;
      });
      return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } catch (e) {
      // Depending on where the exception was thrown, the image cache may not
      // have had a chance to track the key in the cache at all.
      // Schedule a microtask to give the cache a chance to add the key.
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
      rethrow;
    } finally {
      chunkEvents.close();
    }
  }

  ///缓存文件夹
  static const String _cacheImageFolderName = 'cache_image';

  ///缓存7天
  static const Duration _cacheMaxAge = Duration(days: 30);

  /// 最大缓存字节数
  static const int _maximumSizeBytes = 1024 * 1024 * 100;

  /// 最大缓存条目/对象
  static const int _maximumSize = 2000;

  ///读取文件缓存
  Future<Uint8List?> _loadCache(Uri resolved) async {
    if (kIsWeb) {
      return null;
    }

    try {
      final String cacheKey = HashUtil.hash(resolved.path.toString());
      final Directory cacheImagesDirectory = Directory(path.join(
          (await getTemporaryDirectory()).path, _cacheImageFolderName));

      final File file = File(path.join(cacheImagesDirectory.path, cacheKey));

      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (e) {
      return null;
    }
  }

  ///写入文件缓存
  Future<void> _saveCache(Uri resolved, Uint8List decryptedData) async {
    if (kIsWeb) {
      return;
    }
    final String cacheKey = HashUtil.hash(resolved.path.toString());

    final Directory cacheImagesDirectory = Directory(
        path.join((await getTemporaryDirectory()).path, _cacheImageFolderName));
    final file = File(path.join(cacheImagesDirectory.path, cacheKey));

    if (!await cacheImagesDirectory.exists()) {
      await cacheImagesDirectory.create(recursive: true);
    }
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    await file.writeAsBytes(decryptedData);
  }

  ///清理文件缓存
  static _cleanCache() async {
    final Directory cacheImagesDirectory = Directory(
        path.join((await getTemporaryDirectory()).path, _cacheImageFolderName));
    if (await cacheImagesDirectory.exists()) {
      DateTime now = DateTime.now();
      await for (var file in cacheImagesDirectory.list()) {
        // 检查文件的最后修改时间，如果过期就删除
        if (file is File) {
          DateTime lastModified = await file.lastModified();
          if (lastModified.isBefore(now.subtract(_cacheMaxAge))) {
            file.delete();
          }
        }
      }
    }
  }

  ///清除所有缓存
  static Future<void> clearAllCache() async {
    try {
      final Directory cacheImagesDirectory = Directory(path.join(
          (await getTemporaryDirectory()).path, _cacheImageFolderName));
      if (await cacheImagesDirectory.exists()) {
        await cacheImagesDirectory.delete(recursive: true);
      }
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (e) {
      debugPrint("clear image cache error: $e");
    }
  }

  ///获取缓存大小（字节）
  static Future<int> getCacheSize() async {
    try {
      final Directory cacheImagesDirectory = Directory(path.join(
          (await getTemporaryDirectory()).path, _cacheImageFolderName));
      if (!await cacheImagesDirectory.exists()) return 0;

      int totalSize = 0;
      await for (var file in cacheImagesDirectory.list(recursive: true)) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  ///启动app时调用
  static init() {
    if (kIsWeb) {
      return;
    }
    PaintingBinding.instance.imageCache.maximumSizeBytes = _maximumSizeBytes;
    PaintingBinding.instance.imageCache.maximumSize = _maximumSize;
    _cleanCache();
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is NetworkImage &&
        other.url == url &&
        other.scale == scale &&
        mapEquals(other.headers, headers);
  }

  @override
  int get hashCode => Object.hash(url, scale, headers);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'NetworkImage')}("$url", scale: ${scale.toStringAsFixed(1)}, headers: $headers)';
}
