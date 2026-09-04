import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// Longest file stem this app ever asks a platform to create.
///
/// Bounded because a story title is the child's words, not a file name: some
/// platforms refuse a long component outright and others silently truncate it.
const maximumFileStemRunes = 60;

/// Stem used when a title leaves nothing a file system would accept.
const fallbackFileStem = 'iam-hero-story';

/// One file the parent chose, with the name shown while they confirm it.
class PickedFile {
  /// Creates a selection whose bytes already passed the size boundary.
  const PickedFile({required this.name, required this.bytes});

  /// Original file name, shown so the parent recognizes what they picked.
  final String name;

  /// Complete file content, held only for the flow that asked for it.
  final Uint8List bytes;
}

/// Reports a platform picker result whose bytes could not be read.
class PickedFileReadException implements Exception {
  /// Creates a stable file-read error.
  const PickedFileReadException();

  /// Keeps diagnostics concise without naming the parent's file.
  @override
  String toString() => 'The selected file could not be read.';
}

/// Reports a selection larger than this app will hold in memory.
class PickedFileTooLargeException implements Exception {
  /// Creates a stable size-limit error.
  const PickedFileTooLargeException();

  /// Keeps diagnostics concise without naming the parent's file.
  @override
  String toString() => 'The selected file is too large.';
}

/// The platform file dialogs every encrypted-file flow shares.
///
/// Deliberately the whole surface: one way in and one way out, so a backup, a
/// story file, and a rendered PDF cannot each grow their own idea of what a
/// size cap or an unreadable selection means. The fake used by tests is the
/// second implementation, which is what keeps the flows testable without a
/// device dialog.
abstract interface class EncryptedFilePicker {
  /// Lets the parent choose one file with any of [extensions].
  ///
  /// Returns null when they dismissed the dialog. A selection over [maxBytes]
  /// is refused with [PickedFileTooLargeException] before its bytes are read,
  /// and one the platform cannot hand over raises [PickedFileReadException].
  Future<PickedFile?> pick({
    required List<String> extensions,
    required int maxBytes,
  });

  /// Offers [bytes] to the parent under [fileName], reporting acceptance.
  ///
  /// False means the parent cancelled; a web download counts as accepted,
  /// because the browser gives no answer once the file has been dispatched.
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
    required String dialogTitle,
  });
}

/// The real dialogs, on Android, iOS, desktop, and the web.
class PlatformEncryptedFilePicker implements EncryptedFilePicker {
  /// Creates the picker backed by `file_picker`.
  const PlatformEncryptedFilePicker();

  @override
  Future<PickedFile?> pick({
    required List<String> extensions,
    required int maxBytes,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      allowMultiple: false,
      withData: true,
    );
    if (result == null) return null;
    final file = result.files.single;
    if (file.size > maxBytes) throw const PickedFileTooLargeException();
    final bytes = file.bytes;
    if (bytes == null) throw const PickedFileReadException();
    return PickedFile(name: file.name, bytes: bytes);
  }

  @override
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
    required String dialogTitle,
  }) async {
    final savedPath = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: <String>[_extensionOf(fileName)],
      bytes: bytes,
    );
    return kIsWeb || savedPath != null;
  }

  /// Reads back the extension the caller already put on the file name.
  String _extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? fileName : fileName.substring(dot + 1);
  }
}

/// Produces a portable, bounded file stem without altering the stored title.
///
/// The one naming rule for every file this app offers: strip what no common
/// file system accepts, bound it, and fall back rather than hand a platform an
/// empty name. [fallback] is tried before the generic stem, which is how a PDF
/// keeps a story identity when its title was nothing but punctuation.
String safeFileStem(String title, {String fallback = fallbackFileStem}) {
  final bounded = _bounded(title);
  if (bounded.isNotEmpty) return bounded;
  final boundedFallback = _bounded(fallback);
  return boundedFallback.isEmpty ? fallbackFileStem : boundedFallback;
}

/// Strips unsafe characters and control codes, then bounds what is left.
String _bounded(String value) {
  final unsafe = RegExp(r'''[<>:"/\\|?*\x00-\x1F]''');
  final normalized = value.replaceAll(unsafe, '').trim();
  return String.fromCharCodes(
    normalized.runes.take(maximumFileStemRunes),
  ).trim();
}
