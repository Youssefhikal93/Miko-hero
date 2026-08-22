import 'dart:typed_data';

import 'package:miko_hero/core/illustrations/illustration_store.dart';

/// Page-image cache that keeps everything in memory for one test.
///
/// The platform implementations are thin wrappers around a folder and an
/// IndexedDB object store; this replaces exactly that layer, so every test
/// above it — the download loop, the picture run, synchronization, and both
/// deletion paths — exercises the real code that decides what gets cached.
class InMemoryIllustrationStore implements IllustrationStore {
  final Map<String, CachedIllustration> _entries =
      <String, CachedIllustration>{};

  /// Identities this store currently holds, for assertions.
  Iterable<String> get illustrationIds => _entries.keys;

  /// Whether one identity has bytes in this store.
  bool holds(String illustrationId) => _entries.containsKey(illustrationId);

  /// Identity whose read and write both fail, as an unusable cache would.
  String? unwritableIllustrationId;

  @override
  /// Reads one cached page image, or null when the store holds none.
  Future<CachedIllustration?> read(String illustrationId) async {
    requireUsableIllustrationId(illustrationId);
    _refuseUnwritable(illustrationId);
    return _entries[illustrationId];
  }

  @override
  /// Replaces one cached page image and the ETag it was served with.
  Future<void> write(
    String illustrationId,
    Uint8List bytes, {
    String? eTag,
  }) async {
    requireUsableIllustrationId(illustrationId);
    _refuseUnwritable(illustrationId);
    _entries[illustrationId] = CachedIllustration(
      bytes: Uint8List.fromList(bytes),
      eTag: eTag,
    );
  }

  @override
  /// Drops every cached image of one story, by its page identities.
  Future<void> removeForStory(Iterable<String> illustrationIds) async {
    for (final illustrationId in illustrationIds) {
      _entries.remove(illustrationId);
    }
  }

  @override
  /// Drops every cached image this store holds.
  Future<void> clear() async {
    _entries.clear();
  }

  /// Fails the one identity a test marked as unusable.
  void _refuseUnwritable(String illustrationId) {
    if (illustrationId == unwritableIllustrationId) {
      throw const IllustrationStoreException();
    }
  }
}
