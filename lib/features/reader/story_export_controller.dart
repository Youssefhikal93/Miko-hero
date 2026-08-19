import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/core/export/pdf_file_service.dart';
import 'package:miko_hero/core/export/story_pdf_service.dart';
import 'package:miko_hero/core/models/story_models.dart';

/// Supplies the offline multilingual PDF renderer.
final storyPdfServiceProvider = Provider<StoryPdfService>((ref) {
  return StoryPdfService();
});

/// Supplies the platform PDF save boundary.
final pdfFileServiceProvider = Provider<PdfFileService>((ref) {
  return PdfFileService();
});

/// Supplies reader export commands without coupling widgets to file plugins.
final storyExportControllerProvider = Provider<StoryExportController>(
  StoryExportController.new,
);

/// Coordinates local rendering and the user-selected PDF destination.
class StoryExportController {
  /// Retains the provider scope for export service composition.
  const StoryExportController(this._ref);

  final Ref _ref;

  /// Renders and saves one approved story, returning false after cancellation.
  Future<bool> export(StoryBook story, String dialogTitle) async {
    if (story.reviewStatus != StoryReviewStatus.approved) {
      throw StateError('Only approved stories can be exported.');
    }
    final bytes = await _ref.read(storyPdfServiceProvider).build(story);
    return _ref.read(pdfFileServiceProvider).save(bytes, story, dialogTitle);
  }
}
