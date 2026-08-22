import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Number of random bytes in a generated device token (256 bit).
const int deviceTokenBytes = 32;

/// Computes the lowercase hexadecimal SHA-256 digest of [value].
String sha256Hex(String value) {
  return sha256.convert(utf8.encode(value)).toString();
}

/// Generates a cryptographically secure URL-safe bearer token.
///
/// The token carries [bytes] random bytes (default: 256 bits of entropy).
String generateDeviceToken({int bytes = deviceTokenBytes}) {
  final Random secureRandom = Random.secure();
  final values = List<int>.generate(bytes, (_) => secureRandom.nextInt(256));
  return base64UrlEncode(values).replaceAll('=', '');
}

/// Compares two byte lists in constant time.
///
/// The loop always runs over the shorter list regardless of where the first
/// mismatch occurs; only the length difference is observable.
bool constantTimeBytesEquals(List<int> a, List<int> b) {
  var difference = a.length ^ b.length;
  final sharedLength = min(a.length, b.length);
  for (var i = 0; i < sharedLength; i++) {
    difference |= a[i] ^ b[i];
  }
  return difference == 0;
}

/// Compares two plaintext secrets in constant time by hashing both sides
/// first, so plaintext secrets never need to be stored for verification.
bool constantTimeEquals(String a, String b) {
  return constantTimeBytesEquals(
    sha256.convert(utf8.encode(a)).bytes,
    sha256.convert(utf8.encode(b)).bytes,
  );
}

/// Compares a presented digest (hex encoded) against a stored digest
/// (hex encoded) in constant time.
///
/// Used wherever a SHA-256 digest was stored instead of a plaintext secret:
/// device bearer tokens and pairing codes.
bool constantTimeHexDigestEquals(
  String presentedDigestHex,
  String storedDigestHex,
) {
  return constantTimeBytesEquals(
    utf8.encode(presentedDigestHex),
    utf8.encode(storedDigestHex),
  );
}
