import 'dart:io';
import 'dart:typed_data';

import 'package:miko_hero/core/illustrations/illustration_store.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Folder inside the application support directory holding page images.
const illustrationDirectoryName = 'illustrations';

/// Extension of one cached page image.
const illustrationImageExtension = '.png';

/// Extension of the sidecar holding one image's ETag.
const illustrationETagExtension = '.etag';

/// Creates the file-backed image cache used on every non-web platform.
IllustrationStore createIllustrationStore() => FileIllustrationStore();

/// Keeps rendered page images as ordinary files in application support.
///
/// Deliberately outside the family's document folders: these are a cache of
/// what the PC master library already holds, so losing them costs one download
/// and never costs a story. Writes go to a temporary file and are renamed into
/// place, so an interrupted download can never leave a half-written PNG that a
/// later launch would try to decode.
class FileIllustrationStore implements IllustrationStore {
  /// Creates a store rooted in the platform's application support directory.
  FileIllustrationStore({
    this.resolveSupportDirectory = getApplicationSupportDirectory,
  });

  /// Resolves the platform folder the cache lives in; replaced by tests.
  final Future<Directory> Function() resolveSupportDirectory;

  Future<Directory>? _directory;

  @override
  /// Reads one cached page image, or null when this device has none.
  Future<CachedIllustration?> read(String illustrationId) async {
    requireUsableIllustrationId(illustrationId);
    try {
      final directory = await _cacheDirectory();
      final image = File(_imagePath(directory, illustrationId));
      if (!image.existsSync()) return null;
      return CachedIllustration(
        bytes: await image.readAsBytes(),
        eTag: await _readETag(directory, illustrationId),
      );
    } on FileSystemException {
      throw const IllustrationStoreException();
    }
  }

  @override
  /// Replaces one cached page image and the ETag it was served with.
  Future<void> write(
    String illustrationId,
    Uint8List bytes, {
    String? eTag,
  }) async {
    requireUsableIllustrationId(illustrationId);
    try {
      final directory = await _cacheDirectory();
      final imagePath = _imagePath(directory, illustrationId);
      final pending = File('$imagePath.writing');
      await pending.writeAsBytes(bytes, flush: true);
      await pending.rename(imagePath);
      final sidecar = File(_eTagPath(directory, illustrationId));
      if (eTag == null || eTag.isEmpty) {
        if (sidecar.existsSync()) await sidecar.delete();
        return;
      }
      final pendingETag = File('${sidecar.path}.writing');
      await pendingETag.writeAsString(eTag, flush: true);
      await pendingETag.rename(sidecar.path);
    } on FileSystemException {
      throw const IllustrationStoreException();
    }
  }

  @override
  /// Drops every cached image of one story, by its page identities.
  Future<void> removeForStory(Iterable<String> illustrationIds) async {
    try {
      final directory = await _cacheDirectory();
      for (final illustrationId in illustrationIds) {
        if (!isUsableIllustrationId(illustrationId)) continue;
        final image = File(_imagePath(directory, illustrationId));
        if (image.existsSync()) await image.delete();
        final sidecar = File(_eTagPath(directory, illustrationId));
        if (sidecar.existsSync()) await sidecar.delete();
      }
    } on FileSystemException {
      throw const IllustrationStoreException();
    }
  }

  @override
  /// Drops every cached image on this device.
  Future<void> clear() async {
    try {
      final directory = await _cacheDirectory();
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
      _directory = null;
    } on FileSystemException {
      throw const IllustrationStoreException();
    }
  }

  /// Opens, and on first use creates, the folder every image is written into.
  ///
  /// A failed open is not remembered: a platform that could not answer once —
  /// a permission the parent has since granted, for instance — has to be given
  /// another chance rather than leaving the cache dead for the whole session.
  Future<Directory> _cacheDirectory() async {
    final opening = _directory ??= _openCacheDirectory();
    try {
      return await opening;
    } on Exception {
      if (identical(_directory, opening)) _directory = null;
      rethrow;
    }
  }

  /// Creates the cache folder under the platform application support directory.
  Future<Directory> _openCacheDirectory() async {
    final support = await resolveSupportDirectory();
    return Directory(
      p.join(support.path, illustrationDirectoryName),
    ).create(recursive: true);
  }

  /// Reads the stored ETag of one image, treating an empty sidecar as absent.
  Future<String?> _readETag(Directory directory, String illustrationId) async {
    final sidecar = File(_eTagPath(directory, illustrationId));
    if (!sidecar.existsSync()) return null;
    final eTag = await sidecar.readAsString();
    return eTag.isEmpty ? null : eTag;
  }

  /// Path of one cached page image.
  String _imagePath(Directory directory, String illustrationId) {
    return p.join(directory.path, '$illustrationId$illustrationImageExtension');
  }

  /// Path of one cached page image's ETag sidecar.
  String _eTagPath(Directory directory, String illustrationId) {
    return p.join(directory.path, '$illustrationId$illustrationETagExtension');
  }
}
