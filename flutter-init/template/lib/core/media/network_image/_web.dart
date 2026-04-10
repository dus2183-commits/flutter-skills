import 'dart:async';
import 'dart:js_interop';
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/src/painting/image_provider.dart' as image_provider;
import 'package:flutter/src/web.dart' as web;
import 'queue/_network_image_load_queue.dart';

@JS('fetchImage')
external JSPromise<JSArrayBuffer> fetchImage(
    JSString url, JSString key, JSBoolean cache);

@JS('fetchImageBlob')
external JSPromise<JSString> fetchImageBlob(
    JSString url, JSString key, JSBoolean cache);

@JS('dbClean')
external JSPromise<JSNumber> dbClean(
    JSString storeName, JSNumber day, JSNumber size);

@JS('dbClearAll')
external JSPromise<JSBoolean> dbClearAll(JSString storeName);

@JS('dbGetSize')
external JSPromise<JSNumber> dbGetSize(JSString storeName);

/// Creates a type for an overridable factory function for testing purposes.
typedef HttpRequestFactory = web.XMLHttpRequest Function();

// Method signature for _loadAsync decode callbacks.
typedef _SimpleDecoderCallback = Future<ui.Codec> Function(
    ui.ImmutableBuffer buffer);

/// Default HTTP client.
web.XMLHttpRequest _httpClient() {
  return web.XMLHttpRequest();
}

/// Creates an overridable factory function.
HttpRequestFactory httpRequestFactory = _httpClient;

/// Restores to the default HTTP request factory.
void debugRestoreHttpRequestFactory() {
  httpRequestFactory = _httpClient;
}

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
      chunkEvents: chunkEvents.stream,
      codec: _loadAsync(key as NetworkImage, decode, chunkEvents),
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: _imageStreamInformationCollector(key),
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
      chunkEvents: chunkEvents.stream,
      codec: _loadAsync(key as NetworkImage, decode, chunkEvents),
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: _imageStreamInformationCollector(key),
    );
  }

  InformationCollector? _imageStreamInformationCollector(
      image_provider.NetworkImage key) {
    InformationCollector? collector;
    assert(() {
      collector = () => <DiagnosticsNode>[
            DiagnosticsProperty<image_provider.ImageProvider>(
                'Image provider', this),
            DiagnosticsProperty<NetworkImage>('Image key', key as NetworkImage),
          ];
      return true;
    }());
    return collector;
  }

  // Html renderer does not support decoding network images to a specified size. The decode parameter
  // here is ignored and `ui_web.createImageCodecFromUrl` will be used directly
  // in place of the typical `instantiateImageCodec` method.
  Future<ui.Codec> _loadAsync(
    NetworkImage key,
    _SimpleDecoderCallback decode,
    StreamController<ImageChunkEvent> chunkEvents,
  ) async {
    assert(key == this);

    final bool containsNetworkImageHeaders = key.headers?.isNotEmpty ?? false;

    if (isSkiaWeb || containsNetworkImageHeaders) {
      if (key.url.contains('.bnc')) {
        /// canvas渲染方式,加密图片,队列控速
        return NetworkImageLoadQueue.get.add<ui.Codec>(() async {
          final JSArrayBuffer jsArrayBuffer =
              await fetchImage(url.toJS, this.key.toJS, this.cache.toJS).toDart;
          final Uint8List bytes = jsArrayBuffer.toDart.asUint8List();
          // LogUtil.e("currentSize:${PaintingBinding.instance.imageCache.currentSize} currentSizeBytes:${PaintingBinding.instance.imageCache.currentSizeBytes/1024/1024}",);
          return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
        });
      } else {
        /// canvas渲染方式,普通图片,正常加载
        // 对普通图片也使用相同的抓取逻辑，以确保触发 Web 缓存记录
        return NetworkImageLoadQueue.get.add<ui.Codec>(() async {
          final JSArrayBuffer jsArrayBuffer =
              await fetchImage(url.toJS, this.key.toJS, this.cache.toJS).toDart;
          final Uint8List bytes = jsArrayBuffer.toDart.asUint8List();
          return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
        });
      }
    } else {
      if (key.url.contains('.bnc')) {
        /// 加密图片,队列控速
        return NetworkImageLoadQueue.get.add<ui.Codec>(() async {
          final JSString jsBlobUrl =
              await fetchImageBlob(url.toJS, this.key.toJS, this.cache.toJS)
                  .toDart;
          final Uri resolved = Uri.base.resolve(jsBlobUrl.toDart);
          return ui_web.createImageCodecFromUrl(
            resolved,
            chunkCallback: (int bytes, int total) {
              chunkEvents.add(ImageChunkEvent(
                  cumulativeBytesLoaded: bytes, expectedTotalBytes: total));
            },
          );
        });
      } else {
        // 对普通图片也使用相同的抓取逻辑，以确保触发 Web 缓存记录
        return NetworkImageLoadQueue.get.add<ui.Codec>(() async {
          final JSString jsBlobUrl =
              await fetchImageBlob(url.toJS, this.key.toJS, this.cache.toJS)
                  .toDart;
          final Uri resolved = Uri.base.resolve(jsBlobUrl.toDart);
          return ui_web.createImageCodecFromUrl(
            resolved,
            chunkCallback: (int bytes, int total) {
              chunkEvents.add(ImageChunkEvent(
                  cumulativeBytesLoaded: bytes, expectedTotalBytes: total));
            },
          );
        });
      }
    }
  }

  ///清理文件缓存
  static Future<void> _cleanCache() async {
    JSNumber num = await dbClean('image'.toJS, 15.toJS, 1000.toJS).toDart;
    // LogUtil.e("delete ${num.toDartInt}");
  }

  ///清除所有缓存
  static Future<void> clearAllCache() async {
    await dbClearAll('image'.toJS).toDart;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  ///获取缓存大小（字节）
  static Future<int> getCacheSize() async {
    try {
      JSNumber num = await dbGetSize('image'.toJS).toDart;
      return num.toDartInt;
    } catch (e) {
      return 0;
    }
  }

  /// 最大缓存字节数
  static const int _maximumSizeBytes = 1024 * 1024 * 100;

  /// 最大缓存条目/对象
  static const int _maximumSize = 200;

  ///启动app时调用
  static init() {
    if (kIsWeb != true) {
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
    return other is NetworkImage && other.url == url && other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(url, scale);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'NetworkImage')}("$url", scale: ${scale.toStringAsFixed(1)})';
}
