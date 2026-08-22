import 'dart:typed_data';

/// Shape every master-library illustration identity has to match.
///
/// The bridge writes uuids, so this only has to refuse what could escape a file
/// name or an object-store key. Validating at the cache boundary means no
/// platform implementation below ever has to sanitize an identity itself.
final illustrationIdPattern = RegExp(r'^[A-Za-z0-9-]{1,64}$');

/// Whether [illustrationId] is usable as a cache key on every platform.
bool isUsableIllustrationId(String illustrationId) {
  return illustrationIdPattern.hasMatch(illustrationId);
}

/// Requires a usable identity before it reaches platform storage.
void requireUsableIllustrationId(String illustrationId) {
  if (!isUsableIllustrationId(illustrationId)) {
    throw const InvalidIllustrationIdException();
  }
}

/// Reports an illustration identity the cache refuses to use as a key.
///
/// Carries no value: the rejected identity comes from a foreign payload, so it
/// is exactly the kind of thing that must not travel into a log line.
class InvalidIllustrationIdException implements Exception {
  /// Creates the boundary rejection.
  const InvalidIllustrationIdException();

  /// Keeps diagnostics free of the refused identity itself.
  @override
  String toString() => 'Unusable illustration identity.';
}

/// Reports that the platform image cache could not be read or written.
class IllustrationStoreException implements Exception {
  /// Creates a stable cache failure.
  const IllustrationStoreException();

  /// Keeps diagnostics free of any path, key, or image content.
  @override
  String toString() => 'The illustration cache is not usable.';
}

/// One cached page image together with the version the PC served it as.
class CachedIllustration {
  /// Creates one cache entry from stored bytes and their stored ETag.
  const CachedIllustration({required this.bytes, this.eTag});

  /// Complete PNG bytes of one rendered story page.
  final Uint8List bytes;

  /// ETag the bridge served these bytes with, absent when none was stored.
  ///
  /// Sent back as `If-None-Match` so a page whose image did not change costs
  /// one `304` instead of several hundred kilobytes.
  final String? eTag;
}

/// Per-illustration image cache kept outside the persisted story library.
///
/// Page images are far too large for the preference store the library lives in
/// — one page can be several hundred kilobytes and a browser's whole quota is a
/// few megabytes — so they are held here, keyed by the master-library
/// illustration identity every bridge page already carries in its provenance.
abstract class IllustrationStore {
  /// Reads one cached page image, or null when this device has none.
  Future<CachedIllustration?> read(String illustrationId);

  /// Replaces one cached page image and the ETag it was served with.
  Future<void> write(String illustrationId, Uint8List bytes, {String? eTag});

  /// Drops every cached image of one story, by its page identities.
  Future<void> removeForStory(Iterable<String> illustrationIds);

  /// Drops every cached image on this device.
  Future<void> clear();
}
