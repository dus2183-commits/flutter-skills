import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';

/// 静态密钥 AES-CBC 加解密
///
/// 后端规范:
/// - 算法: AES-CBC
/// - 密钥: 256 bit (32 字节)
/// - IV: 取密钥的前 16 字节
/// - 填充: PKCS7
/// - 编码: Base64 Standard
///
/// 请求: JSON 字符串 → AES-CBC 加密 → Base64 裸密文 (Content-Type: text/plain)
/// 响应: Base64 裸密文 → AES-CBC 解密 → JSON 字符串
///
/// 调试模式: 请求头加 X-Encrypt: 1,Body 直接传 JSON,服务端跳过加解密
class AesStaticUtil {
  AesStaticUtil._();

  /// 加密: JSON 字符串 → Base64 密文
  ///
  /// [plainText] 待加密的 JSON 字符串
  /// [secretKey] 32 字节密钥
  /// 返回 Base64 Standard 编码的密文
  static String encrypt(String plainText, String secretKey) {
    final key = Key.fromUtf8(secretKey);
    final iv = IV(Uint8List.fromList(secretKey.codeUnits.take(16).toList()));

    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    return encrypted.base64;
  }

  /// 解密: Base64 密文 → JSON 字符串
  ///
  /// [base64Cipher] Base64 编码的密文
  /// [secretKey] 32 字节密钥
  /// 返回解密后的 JSON 字符串
  static String decrypt(String base64Cipher, String secretKey) {
    final key = Key.fromUtf8(secretKey);
    final iv = IV(Uint8List.fromList(secretKey.codeUnits.take(16).toList()));

    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    return encrypter.decrypt64(base64Cipher, iv: iv);
  }

  /// 加密 Map → Base64 密文 (便捷方法)
  static String encryptJson(Map<String, dynamic> data, String secretKey) {
    return encrypt(jsonEncode(data), secretKey);
  }

  /// Base64 密文 → Map (便捷方法)
  static Map<String, dynamic> decryptJson(String base64Cipher, String secretKey) {
    final jsonStr = decrypt(base64Cipher, secretKey);
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }
}
