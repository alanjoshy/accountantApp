// PIN hash / verify.

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class PinCrypto {
  PinCrypto._();

  static const minLength = 4;
  static const maxLength = 6;

  static bool isValid(String pin) {
    if (pin.length < minLength || pin.length > maxLength) return false;
    return RegExp(r'^\d+$').hasMatch(pin);
  }

  static String hash(String pin, [String? saltB64]) {
    final salt = saltB64 != null
        ? base64Decode(saltB64)
        : List<int>.generate(16, (_) => Random.secure().nextInt(256));

    var digest = sha256.convert(utf8.encode(pin) + salt);
    for (var i = 0; i < 12_000; i++) {
      digest = sha256.convert(digest.bytes + salt);
    }

    return '${base64Encode(salt)}:${base64Encode(digest.bytes)}';
  }

  static bool verify(String pin, String stored) {
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    return hash(pin, parts[0]) == stored;
  }
}
