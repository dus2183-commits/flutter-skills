import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
// import 'package:encrypter_plus/encrypter_plus.dart';
import 'package:encrypt/encrypt.dart';

class AesUtil {
  ///图片解密
  static Uint8List decryptImg(Uint8List bytes, String key) {
    final utf8Key = Key.fromUtf8(key);
    final iv = IV.fromLength(0);
    return Uint8List.fromList(Encrypter(AES(utf8Key, mode: AESMode.ecb)).decryptBytes(Encrypted(bytes), iv: iv));
  }

  ///WebSocket解密
  static String decryptWebSocket(String hexCipher, String hexKey) {
    final keyBytes = Uint8List.fromList(hex.decode(hexKey)); // Hex 解码密钥
    final cipherBytes = Uint8List.fromList(hex.decode(hexCipher)); // Hex 解码密文

    final key = Key(keyBytes); // AES 128-bit key
    final iv = IV.fromLength(0); // ECB 模式无 IV

    final encrypter = Encrypter(AES(key, mode: AESMode.ecb));
    final decryptedBytes = encrypter.decryptBytes(Encrypted(cipherBytes), iv: iv);
    final decryptedText = utf8.decode(decryptedBytes);
    return decryptedText;
  }

  /// 缓存数据加密
  static String encryptCache(String text) {
    final cacheKey = Key.fromUtf8('03902989cbc6431d');
    final cacheIv = IV.fromLength(12);
    final cacheAesEncryptor = Encrypter(AES(cacheKey, mode: AESMode.ecb));
    return cacheAesEncryptor.encrypt(text, iv: cacheIv).base16;
  }

  /// 缓存数据解密
  static String decryptCache(String text) {
    final cacheKey = Key.fromUtf8('03902989cbc6431d');
    final cacheIv = IV.fromLength(12);
    final cacheAesEncryptor = Encrypter(AES(cacheKey, mode: AESMode.ecb));
    return cacheAesEncryptor.decrypt(Encrypted.fromBase16(text), iv: cacheIv);
  }
}
