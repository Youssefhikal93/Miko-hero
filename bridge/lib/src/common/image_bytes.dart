import 'dart:typed_data';

/// The two reference-photo formats the bridge accepts.
///
/// ComfyUI reads both, phones produce both, and keeping the list this short
/// means the bytes can be identified without an image decoding dependency.
enum ReferenceImageFormat {
  /// JPEG, stored as `.jpg`.
  jpeg('image/jpeg', 'jpg'),

  /// PNG, stored as `.png`.
  png('image/png', 'png');

  const ReferenceImageFormat(this.contentType, this.fileExtension);

  /// Canonical MIME type accepted in the `Content-Type` header.
  final String contentType;

  /// File extension used when the photo is stored, without a leading dot.
  final String fileExtension;

  /// Resolves a MIME type to a format, or `null` when it is not accepted.
  ///
  /// `image/jpg` is accepted as a spelling of `image/jpeg` because phone
  /// clients emit it, but it is stored under the canonical extension.
  static ReferenceImageFormat? fromContentType(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'image/jpg') {
      return ReferenceImageFormat.jpeg;
    }
    for (final format in ReferenceImageFormat.values) {
      if (format.contentType == normalized) {
        return format;
      }
    }
    return null;
  }

  /// Resolves a stored file extension to a format, or `null`.
  static ReferenceImageFormat? fromFileExtension(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'jpeg') {
      return ReferenceImageFormat.jpeg;
    }
    for (final format in ReferenceImageFormat.values) {
      if (format.fileExtension == normalized) {
        return format;
      }
    }
    return null;
  }
}

/// The eight bytes every PNG file starts with.
const List<int> pngMagicBytes = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
];

/// The JPEG start-of-image marker plus the first byte of the next marker.
const List<int> jpegMagicBytes = <int>[0xFF, 0xD8, 0xFF];

/// Identifies [bytes] by their leading magic bytes, or `null` when they are
/// neither a PNG nor a JPEG.
///
/// This is the boundary check that keeps a mislabelled or hostile upload out
/// of the library: the declared `Content-Type` is a claim, the magic bytes
/// are evidence. It is deliberately not a full decode — the bridge has no
/// image codec and does not need one to refuse a renamed executable.
ReferenceImageFormat? detectReferenceImageFormat(Uint8List bytes) {
  if (_startsWith(bytes, pngMagicBytes)) {
    return ReferenceImageFormat.png;
  }
  if (_startsWith(bytes, jpegMagicBytes)) {
    return ReferenceImageFormat.jpeg;
  }
  return null;
}

/// Whether [bytes] begin with the PNG signature.
///
/// Used on the way out as well as in: an image ComfyUI hands back is written
/// into the library as a `.png`, so it has to actually be one.
bool looksLikePng(Uint8List bytes) => _startsWith(bytes, pngMagicBytes);

bool _startsWith(Uint8List bytes, List<int> prefix) {
  if (bytes.length < prefix.length) {
    return false;
  }
  for (var index = 0; index < prefix.length; index++) {
    if (bytes[index] != prefix[index]) {
      return false;
    }
  }
  return true;
}
