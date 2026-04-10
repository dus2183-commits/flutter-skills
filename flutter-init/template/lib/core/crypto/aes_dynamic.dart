import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
// import 'package:encrypter_plus/encrypter_plus.dart';
import 'package:encrypt/encrypt.dart';

class AesDynamicUtil {
  ///创建key
  static Key generateKey(String requestId, String key) {
    // 去除requestId中的所有'-'
    String cleanId = requestId.replaceAll('-', '');
    // 将十六进制字符串转换为二进制数据
    List<int> cleanIdBytes = hex.decode(cleanId);
    // 使用HMAC-SHA256算法生成密钥
    Hmac hmac = Hmac(sha256, utf8.encode(key));

    Digest digest = hmac.convert(cleanIdBytes);

    // 将List<int>转换为Uint8List
    Uint8List keyBytes = Uint8List.fromList(digest.bytes);
    // 返回AES Key
    return Key(keyBytes);
  }

  ///加密
  static Uint8List encryptRaw(String text, String requestId, String key) {
    // 压缩
    Uint8List compressed = Uint8List.fromList(GZipEncoder().encode(utf8.encode(text)));
    // 生成key
    Key ukey = generateKey(requestId, key);
    // 生成iv
    IV iv = IV.fromSecureRandom(16);

    final encrypt = Encrypter(AES(ukey, mode: AESMode.cbc)).encryptBytes(compressed, iv: iv);

    // 拼接IV和加密数据（IV + ciphertext）
    return Uint8List.fromList([...iv.bytes, ...encrypt.bytes]);
  }

  ///解密
  static String decryptRaw(Uint8List bytes, String requestId, String key) {
    // 生成key
    Key ukey = generateKey(requestId, key);
    // 分离IV
    final iv = IV(bytes.sublist(0, 16));
    // 分离数据
    final ciphertext = bytes.sublist(16);

    //解密数据
    final decrypted = Encrypter(AES(ukey, mode: AESMode.cbc)).decryptBytes(Encrypted(ciphertext), iv: iv);
    return utf8.decode(GZipDecoder().decodeBytes(decrypted));
  }
}
