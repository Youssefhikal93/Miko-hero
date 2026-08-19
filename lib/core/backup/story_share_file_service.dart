import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:miko_hero/core/backup/backup_file_service.dart';
import 'package:miko_hero/core/backup/encrypted_backup_codec.dart';
import 'package:miko_hero/core/backup/story_share_codec.dart';

/// Selected encrypted story bytes and their original display name.
class PickedStoryFile {
  /// Creates a selection after its bytes pass the shared size boundary.
  const PickedStoryFile({required this.name, required this.bytes});

  /// Original file name shown while the parent confirms the import.
  final String name;

  /// Complete encrypted container held only for this import flow.
  final Uint8List bytes;
}

/// Opens and saves single-story share files on Android, iOS, and web.
class StoryShareFileService {
  /// Lets the parent choose one encrypted Iam - hero story file.
  Future<PickedStoryFile?> pickStory() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>[storyShareFileExtension],
      allowMultiple: false,
      withData: true,
    );
    if (result == null) return null;
    final file = result.files.single;
    if (file.size > maximumBackupBytes) {
      throw const BackupTooLargeException();
    }
    final bytes = file.bytes;
    if (bytes == null) throw const BackupFileReadException();
    return PickedStoryFile(name: file.name, bytes: bytes);
  }

  /// Opens the save flow and reports success, including web download dispatch.
  Future<bool> saveStory(
    Uint8List bytes,
    String storyTitle,
    String dialogTitle,
  ) async {
    final savedPath = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: '${_safeFileStem(storyTitle)}.$storyShareFileExtension',
      type: FileType.custom,
      allowedExtensions: const <String>[storyShareFileExtension],
      bytes: bytes,
    );
    return kIsWeb || savedPath != null;
  }

  /// Produces a portable bounded name without altering the stored story title.
  String _safeFileStem(String storyTitle) {
    final unsafe = RegExp(r'''[<>:"/\\|?*\x00-\x1F]''');
    final normalized = storyTitle.replaceAll(unsafe, '').trim();
    final bounded = String.fromCharCodes(normalized.runes.take(60)).trim();
    return bounded.isEmpty ? 'iam-hero-story' : bounded;
  }
}
