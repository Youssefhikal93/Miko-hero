import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:miko_hero/core/models/story_models.dart';

/// Opens the platform save flow for locally rendered PDF storybooks.
class PdfFileService {
  /// Saves one PDF and reports cancellation separately from platform errors.
  Future<bool> save(
    Uint8List bytes,
    StoryBook story,
    String dialogTitle,
  ) async {
    final savedPath = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: '${_safeFileStem(story)}.pdf',
      type: FileType.custom,
      allowedExtensions: const <String>['pdf'],
      bytes: bytes,
    );
    return kIsWeb || savedPath != null;
  }

  /// Produces a portable bounded name without altering the title inside the PDF.
  String _safeFileStem(StoryBook story) {
    final unsafe = RegExp(r'''[<>:"/\\|?*\x00-\x1F]''');
    final normalized = story.content.title.replaceAll(unsafe, '').trim();
    final fallback = normalized.isEmpty ? story.id : normalized;
    final bounded = String.fromCharCodes(fallback.runes.take(60)).trim();
    return bounded.isEmpty ? 'iam-hero-story' : bounded;
  }
}
