import 'dart:convert';
import 'dart:typed_data';

import 'package:miko_hero/core/ai_connection/bridge_client.dart';
import 'package:miko_hero/core/models/child_profile.dart';

/// One stored profile photo the PC can actually use as a face reference.
class ReferencePhoto {
  /// Creates a photo whose bytes already passed the type and size checks.
  const ReferencePhoto({required this.bytes, required this.contentType});

  /// Raw image bytes exactly as they are stored on this device.
  final Uint8List bytes;

  /// Image type read from the bytes themselves, never from a file name.
  final String contentType;
}

/// Reads a usable reference photo out of a stored profile, or null.
///
/// Null means "send no photo": the book still gets pictures, they just will not
/// carry the child's likeness. That is deliberately not treated as a failure,
/// because a family whose photo is an unexpected format should still get their
/// illustrated story instead of an error message.
ReferencePhoto? readReferencePhoto(String photoBase64) {
  if (photoBase64.isEmpty) return null;
  final Uint8List bytes;
  try {
    bytes = base64Decode(photoBase64);
  } on FormatException {
    return null;
  }
  if (bytes.isEmpty || bytes.length > maximumReferencePhotoBytes) return null;
  final contentType = sniffImageContentType(bytes);
  if (contentType == null) return null;
  return ReferencePhoto(bytes: bytes, contentType: contentType);
}

/// Names the image type from its leading magic bytes, or null for neither.
///
/// The bridge accepts only JPEG and PNG, and a stored photo carries no file
/// name, so the bytes are the only honest source for the `Content-Type` header.
String? sniffImageContentType(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return bridgeJpegContentType;
  }
  if (bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return bridgePngContentType;
  }
  return null;
}
