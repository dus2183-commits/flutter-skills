// 改造自 yc141 lib/util/hash_util.dart
// 区别: 删除了 hashFile() (用了 dart:io,web 不兼容)
// 三端通用版本

import 'dart:convert';

import 'package:crypto/crypto.dart';

class HashUtil {
  /// 计算字符串的 MD5 哈希值(返回十六进制字符串)
  static String hash(String input) {
    final bytes = utf8.encode(input);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// 计算字节数据的 MD5 哈希值(返回十六进制字符串)
  static String hashBytes(List<int> bytes) {
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// SHA256 哈希
  static String sha256Hash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
