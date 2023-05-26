import 'package:encrypt/encrypt.dart' as security; 
import 'package:FaceNetAuthentication/config/constant.dart';

encrypt(data)
{ 
    final key = security.Key.fromUtf8(SECRET_KEY);
    final iv = security.IV.fromLength(16);

    final encrypter = security.Encrypter(security.AES(key, mode: security.AESMode.cbc));

    final encrypted = encrypter.encrypt(data, iv: iv);
    return encrypted.base64;
}

decrypt(data)
{ 
    final key = security.Key.fromUtf8(SECRET_KEY);
    final iv = security.IV.fromLength(16);

    final encrypter = security.Encrypter(security.AES(key, mode: security.AESMode.cbc));

    final encrypted = encrypter.decrypt(data, iv: iv);
    return encrypted;
}