import 'dart:convert';
import 'dart:io';

/// Writes [bytes] to [path] atomically: the payload is fully written to a
/// temporary sibling file which is then renamed over [path].
///
/// Renaming over an existing file is not allowed on some platforms (notably
/// Windows), so an existing target is deleted right before the final rename.
/// If anything fails, the temporary file is removed and the original target,
/// if any, stays untouched.
///
/// Returns the resulting [File] at [path].
Future<File> writeFileAtomic(String path, List<int> bytes) async {
  final target = File(path);
  await target.parent.create(recursive: true);
  final tempPath =
      '${target.path}.tmp-${DateTime.now().microsecondsSinceEpoch}';
  final temp = File(tempPath);
  IOSink? sink;
  try {
    sink = temp.openWrite();
    sink.add(bytes);
    await sink.flush();
    await sink.close();
    sink = null;
    try {
      await temp.rename(target.path);
    } on FileSystemException {
      // Windows refuses to rename onto an existing file; replace it instead.
      if (await target.exists()) {
        await target.delete();
      }
      await temp.rename(target.path);
    }
    return target;
  } catch (_) {
    try {
      if (await temp.exists()) {
        await temp.delete();
      }
    } on FileSystemException {
      // Best-effort cleanup only; surface the original error below.
    }
    rethrow;
  } finally {
    if (sink != null) {
      try {
        await sink.close();
      } on FileSystemException {
        // The primary error, if any, must not be masked here.
      }
    }
  }
}

/// Writes [contents] encoded as UTF-8 to [path] atomically.
///
/// See [writeFileAtomic] for the exact durability guarantees.
Future<File> writeStringAtomic(String path, String contents) async {
  return writeFileAtomic(path, utf8.encode(contents));
}
