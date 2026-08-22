import 'dart:convert';
import 'dart:io';

int _temporaryFileCounter = 0;

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
  final File temp = await writeTemporarySibling(path, bytes);
  try {
    return await replaceWithTemporaryFile(temp, path);
  } catch (_) {
    await deleteTemporaryFile(temp);
    rethrow;
  }
}

/// Writes [contents] encoded as UTF-8 to [path] atomically.
///
/// See [writeFileAtomic] for the exact durability guarantees.
Future<File> writeStringAtomic(String path, String contents) async {
  return writeFileAtomic(path, utf8.encode(contents));
}

/// Writes [bytes] into a fresh temporary sibling of [targetPath] and returns
/// it, leaving [targetPath] itself untouched.
///
/// This is the first half of [writeFileAtomic], split out so a caller that
/// swaps many files at once can stage every one of them before committing
/// any: a failure while staging changes nothing. Finish with
/// [replaceWithTemporaryFile], or discard with [deleteTemporaryFile].
Future<File> writeTemporarySibling(String targetPath, List<int> bytes) async {
  final target = File(targetPath);
  await target.parent.create(recursive: true);
  final serial = _temporaryFileCounter++;
  final temp = File(
    '${target.path}.tmp-${DateTime.now().microsecondsSinceEpoch}-$serial',
  );
  IOSink? sink;
  try {
    sink = temp.openWrite();
    sink.add(bytes);
    await sink.flush();
    await sink.close();
    sink = null;
    return temp;
  } catch (_) {
    await deleteTemporaryFile(temp);
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

/// Renames [temporary] over [targetPath], replacing an existing target.
Future<File> replaceWithTemporaryFile(File temporary, String targetPath) async {
  final target = File(targetPath);
  try {
    return await temporary.rename(target.path);
  } on FileSystemException {
    // Windows refuses to rename onto an existing file; replace it instead.
    if (await target.exists()) {
      await target.delete();
    }
    return temporary.rename(target.path);
  }
}

/// Removes a staged temporary file, ignoring a failed cleanup.
Future<void> deleteTemporaryFile(File temporary) async {
  try {
    if (await temporary.exists()) {
      await temporary.delete();
    }
  } on FileSystemException {
    // Best-effort cleanup only; the caller's original error must win.
  }
}
