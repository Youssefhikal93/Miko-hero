import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:iam_hero_bridge/src/common/paths.dart';
import 'package:iam_hero_bridge/src/illustration/illustration_repository.dart';
import 'package:iam_hero_bridge/src/library/master_library.dart';
import 'package:iam_hero_bridge/src/library/story_deleter.dart';

/// Why one illustration file could not be served.
enum IllustrationFileProblem {
  /// No illustration row exists under the requested id.
  unknown,

  /// The row exists but has not been rendered yet, or its render failed.
  notReady,
}

/// One illustration file ready to be streamed to a device.
class IllustrationFile {
  /// Creates a readable illustration file.
  const IllustrationFile({
    required this.illustrationId,
    required this.storyId,
    required this.pageNumber,
    required this.bytes,
    required this.eTag,
  });

  /// Stable id of the `illustrations` row.
  final String illustrationId;

  /// Story the page belongs to.
  final String storyId;

  /// One-based page number shown to the reader.
  final int pageNumber;

  /// Complete PNG contents.
  final Uint8List bytes;

  /// Strong entity tag: the SHA-256 of the file contents, quoted.
  ///
  /// A content hash rather than size-and-mtime, because a re-render of the
  /// same page writes the same path with a new timestamp — and a device that
  /// re-downloads an identical image on every sync is exactly what the tag
  /// exists to prevent.
  final String eTag;
}

/// Result of asking for one illustration file: the file, or why not.
class IllustrationFileResult {
  /// Creates a successful result.
  const IllustrationFileResult.found(IllustrationFile this.file)
    : problem = null;

  /// Creates a failed result.
  const IllustrationFileResult.problem(IllustrationFileProblem this.problem)
    : file = null;

  /// The readable file, set exactly when [problem] is `null`.
  final IllustrationFile? file;

  /// Why the file is not available, set exactly when [file] is `null`.
  final IllustrationFileProblem? problem;
}

/// Reads rendered illustration files out of the library for sync downloads.
///
/// Read-only by construction. The row decides whether a file may be served
/// at all: a `pending` or `failed` page has no image worth sending, and a
/// row whose stored path could point outside `illustrations/` — which only a
/// restored backup could produce — is refused rather than followed.
class IllustrationFileReader {
  /// Creates a reader over [library].
  IllustrationFileReader({required this.library})
    : _repository = IllustrationRepository(library: library);

  /// The initialized master library this reader queries.
  final MasterLibrary library;

  final IllustrationRepository _repository;

  /// Reads the PNG of [illustrationId].
  Future<IllustrationFileResult> read(String illustrationId) async {
    final StoredIllustration? row = _repository.readIllustration(
      illustrationId,
    );
    if (row == null) {
      return const IllustrationFileResult.problem(
        IllustrationFileProblem.unknown,
      );
    }
    if (!row.isCompleted || !isIllustrationRelativePath(row.relativePath)) {
      return const IllustrationFileResult.problem(
        IllustrationFileProblem.notReady,
      );
    }
    final file = File(
      joinPath(library.rootPath, toPlatformRelativePath(row.relativePath)),
    );
    final Uint8List bytes;
    try {
      if (!await file.exists()) {
        return const IllustrationFileResult.problem(
          IllustrationFileProblem.notReady,
        );
      }
      bytes = await file.readAsBytes();
    } on FileSystemException {
      // The row promised an image the disk cannot produce; that is "not
      // ready" to the device, and the path never reaches the response.
      return const IllustrationFileResult.problem(
        IllustrationFileProblem.notReady,
      );
    }
    return IllustrationFileResult.found(
      IllustrationFile(
        illustrationId: row.id,
        storyId: row.storyId,
        pageNumber: row.pageIndex + 1,
        bytes: bytes,
        eTag: '"${sha256.convert(bytes)}"',
      ),
    );
  }
}
