// AppConfig - 应用配置
// 改造自 yc141 lib/core/app_api.dart
// 区别: 抽象成 interface + GetxService,可注入,可测试

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';

import '../crypto/hash_util.dart';

/// 线路 (主备 fallback)
class Line {
  final String url;
  final String code;

  const Line(this.url, {required this.code});
}

/// 应用配置抽象接口。
/// 业务代码 import 这个,不直接用 dotenv。
abstract class AppConfig {
  String get apiVersion;
  String get apiHeaderKey;
  String get imgKey;
  String get apiKey; // 已分平台
  String get apiPrefix;
  String get sessionId;
  Line get currentLine;
  List<Line> get normalLines;
  List<Line> get backupLines;

  void setSessionId(String id);
  void switchLine(Line line);
}

/// 默认实现: 从 dotenv 读取
class DotenvAppConfig extends GetxService implements AppConfig {
  String _sessionId = '';
  Line? _currentLine;

  Future<DotenvAppConfig> init() async {
    // dotenv.load 应在 main.dart 中已经调用
    final lines = normalLines;
    if (lines.isNotEmpty) {
      _currentLine = lines[0];
    }
    return this;
  }

  @override
  String get apiVersion => dotenv.get('API_VERSION', fallback: '1.0.0');

  @override
  String get apiHeaderKey => dotenv.get('API_HEADER_KEY', fallback: '');

  @override
  String get imgKey => dotenv.get('IMG_KEY', fallback: '');

  /// 三端三套 key
  @override
  String get apiKey {
    if (kIsWeb) {
      return dotenv.get('API_WEB_KEY', fallback: '');
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return dotenv.get('API_IOS_KEY', fallback: '');
    }
    return dotenv.get('API_ANDROID_KEY', fallback: '');
  }

  @override
  String get apiPrefix => dotenv.get('API_PREFIX', fallback: '/api');

  @override
  String get sessionId => _sessionId;

  @override
  Line get currentLine {
    return _currentLine ?? (normalLines.isNotEmpty ? normalLines[0] : const Line('', code: ''));
  }

  @override
  List<Line> get normalLines => _parseLines('NORMAL_LINES');

  @override
  List<Line> get backupLines => _parseLines('BACKUP_LINES');

  @override
  void setSessionId(String id) {
    _sessionId = id;
  }

  @override
  void switchLine(Line line) {
    _currentLine = line;
  }

  // ─── helpers ───

  List<Line> _parseLines(String envKey) {
    final raw = dotenv.get(envKey, fallback: '');
    if (raw.isEmpty) return [];
    return raw.split(',').map((item) {
      final parts = item.split('|');
      return Line(parts[0], code: parts.length > 1 ? parts[1] : '');
    }).toList();
  }

  /// 动态生成线路 (年月+code+hash) - 防爬虫
  static Line createLine(String code) {
    final dt = DateTime.now();
    final input = '${dt.year}-${dt.month.toString().padLeft(2, '0')}$code';
    final hash = HashUtil.hash(input);
    final url = 'https://swift_app.${hash.substring(16)}.com';
    return Line(url, code: '');
  }
}
