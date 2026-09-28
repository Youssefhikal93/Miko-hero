import 'dart:io';
import 'dart:typed_data';

import 'package:iam_hero_bridge/src/common/atomic_files.dart';
import 'package:iam_hero_bridge/src/common/image_bytes.dart';
import 'package:iam_hero_bridge/src/common/paths.dart';
import 'package:iam_hero_bridge/src/library/db_transactions.dart';
import 'package:iam_hero_bridge/src/library/master_library.dart';

/// Largest accepted reference photo: 2 MB.
///
/// A phone portrait is well under this; anything larger is a full-resolution
/// camera dump that the 512x512 face encoder would throw away anyway.
const int maxReferencePhotoBytes = 2 * 1024 * 1024;

/// One stored reference photo of a child profile.
class ProfileReferencePhoto {
  /// Creates a photo descriptor.
  const ProfileReferencePhoto({
    required this.profileId,
    required this.format,
    required this.relativePath,
    required this.absolutePath,
    required this.sizeBytes,
  });

  /// Profile the photo belongs to.
  final String profileId;

  /// Stored image format, which fixes the file extension and MIME type.
  final ReferenceImageFormat format;

  /// Library-relative, forward-slash path (`photos/<profileId>.<ext>`).
  final String relativePath;

  /// Absolute path of the file on this machine. Never sent anywhere.
  final String absolutePath;

  /// Size of the stored file in bytes.
  final int sizeBytes;

  /// File name ComfyUI should receive the photo under.
  String get fileName => '$profileId.${format.fileExtension}';

  /// JSON shape returned by the photo upload endpoint.
  ///
  /// Carries the path and size only: the bytes are the child's face and never
  /// travel back out of the library.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'profileId': profileId,
      'relativePath': relativePath,
      'contentType': format.contentType,
      'sizeBytes': sizeBytes,
    };
  }
}

/// Raised when a profile referenced by a photo operation does not exist.
class UnknownProfileException implements Exception {
  /// Creates the exception for [profileId].
  const UnknownProfileException(this.profileId);

  /// The id that matched no profile row.
  final String profileId;

  @override
  String toString() => 'UnknownProfileException()';
}

/// Owns the reference photos under the library's `photos/` folder.
///
/// One photo per profile, named after the profile so the mapping needs no
/// table of its own: the file either exists or the child has no photo. The
/// bytes are the most private thing the bridge stores, so they are never
/// logged, never echoed in a response, and never carried in an error message.
class ProfilePhotoStore {
  /// Creates a store over [library].
  const ProfilePhotoStore({required this.library});

  /// The initialized master library this store writes into.
  final MasterLibrary library;

  /// Whether [profileId] is usable as a photo file name.
  ///
  /// Profile ids come from the app and end up in a path, so anything that
  /// could escape `photos/` is refused before the database is even asked.
  static bool isValidProfileId(String profileId) {
    if (profileId.isEmpty || profileId.length > 64) {
      return false;
    }
    return RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(profileId) &&
        profileId != '.' &&
        profileId != '..';
  }

  /// Whether a profile row exists under [profileId].
  bool profileExists(String profileId) {
    final rows = library.database.select(
      'SELECT id FROM profiles WHERE id = ?',
      <Object?>[profileId],
    );
    return rows.isNotEmpty;
  }

  /// Returns the stored photo of [profileId], or `null` when there is none.
  ProfileReferencePhoto? findPhoto(String profileId) {
    if (!isValidProfileId(profileId)) {
      return null;
    }
    for (final format in ReferenceImageFormat.values) {
      final relativePath = _relativePath(profileId, format);
      final file = File(_absolutePath(relativePath));
      if (file.existsSync()) {
        return ProfileReferencePhoto(
          profileId: profileId,
          format: format,
          relativePath: relativePath,
          absolutePath: file.path,
          sizeBytes: file.lengthSync(),
        );
      }
    }
    return null;
  }

  /// Reads the bytes of [photo] from disk.
  Future<Uint8List> readPhotoBytes(ProfileReferencePhoto photo) async {
    return File(photo.absolutePath).readAsBytes();
  }

  /// Stores [bytes] as the reference photo of [profileId].
  ///
  /// Writes atomically, removes a previously stored photo in the other
  /// format so a profile never has two, and touches the profile's
  /// `updated_at_utc` inside a transaction so the next sync manifest shows
  /// the change. Throws [UnknownProfileException] when the profile does not
  /// exist; nothing is written in that case.
  Future<ProfileReferencePhoto> savePhoto({
    required String profileId,
    required ReferenceImageFormat format,
    required Uint8List bytes,
    required DateTime nowUtc,
  }) async {
    if (!isValidProfileId(profileId) || !profileExists(profileId)) {
      throw UnknownProfileException(profileId);
    }
    final relativePath = _relativePath(profileId, format);
    final absolutePath = _absolutePath(relativePath);
    await writeFileAtomic(absolutePath, bytes);
    for (final other in ReferenceImageFormat.values) {
      if (other == format) {
        continue;
      }
      await _deleteIfPresent(_absolutePath(_relativePath(profileId, other)));
    }
    _touchProfile(profileId, nowUtc);
    return ProfileReferencePhoto(
      profileId: profileId,
      format: format,
      relativePath: relativePath,
      absolutePath: absolutePath,
      sizeBytes: bytes.length,
    );
  }

  /// Removes the reference photo of [profileId], if any.
  ///
  /// Returns `true` when a file was actually deleted. Throws
  /// [UnknownProfileException] for an unknown profile. The profile's
  /// `updated_at_utc` is touched either way, because "this child now has no
  /// photo" is itself a change devices should see.
  Future<bool> deletePhoto({
    required String profileId,
    required DateTime nowUtc,
  }) async {
    if (!isValidProfileId(profileId) || !profileExists(profileId)) {
      throw UnknownProfileException(profileId);
    }
    final removed = await removePhotoFiles(profileId);
    _touchProfile(profileId, nowUtc);
    return removed;
  }

  /// Removes the photo file of [profileId] without touching the database.
  ///
  /// Returns `true` when a file was actually deleted. This is the delete a
  /// profile's own removal needs: by the time the photo goes, the profile row
  /// is already gone, so there is no row left to check or to touch.
  Future<bool> removePhotoFiles(String profileId) async {
    if (!isValidProfileId(profileId)) {
      return false;
    }
    var removed = false;
    for (final format in ReferenceImageFormat.values) {
      final deleted = await _deleteIfPresent(
        _absolutePath(_relativePath(profileId, format)),
      );
      removed = removed || deleted;
    }
    return removed;
  }

  void _touchProfile(String profileId, DateTime nowUtc) {
    final db = library.database;
    runInDatabaseTransaction(db, () {
      db.execute(
        'UPDATE profiles SET updated_at_utc = ? WHERE id = ?',
        <Object?>[nowUtc.toUtc().toIso8601String(), profileId],
      );
    });
  }

  String _relativePath(String profileId, ReferenceImageFormat format) =>
      'photos/$profileId.${format.fileExtension}';

  String _absolutePath(String relativePath) =>
      joinPath(library.rootPath, toPlatformRelativePath(relativePath));

  Future<bool> _deleteIfPresent(String path) async {
    final file = File(path);
    try {
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } on FileSystemException {
      // A photo that cannot be removed is left alone rather than reported:
      // the path is private content and has no place in an error message.
    }
    return false;
  }
}
