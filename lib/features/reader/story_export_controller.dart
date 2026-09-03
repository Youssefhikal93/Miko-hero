import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/ai_connection/bridge_story_provenance.dart';
import 'package:miko_hero/core/export/pdf_file_service.dart';
import 'package:miko_hero/core/export/story_pdf_service.dart';
import 'package:miko_hero/core/illustrations/illustration_providers.dart';
import 'package:miko_hero/core/models/kingdom_theme.dart';
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
  ///
  /// [includePhoto] carries the parent's export-time choice: only then is the
  /// hero's saved reference photo resolved and placed on the PDF cover. A
  /// missing profile or photo silently produces the photo-free cover.
  ///
  /// Page illustrations are story content rather than private likeness, so
  /// every picture this device already downloaded prints unconditionally on the
  /// page it was drawn for.
  Future<bool> export(
    StoryBook story,
    String dialogTitle, {
    bool includePhoto = false,
  }) async {
    if (story.reviewStatus != StoryReviewStatus.approved) {
      throw StateError('Only approved stories can be exported.');
    }
    final bytes = await _ref
        .read(storyPdfServiceProvider)
        .build(
          story,
          coverPhotoBase64: includePhoto ? _coverPhoto(story) : null,
          illustrationBytesById: await _illustrations(story),
          kingdomSymbol: _kingdomSymbol(story),
        );
    return _ref.read(pdfFileServiceProvider).save(bytes, story, dialogTitle);
  }

  /// Reads the hero's favourite kingdom badge for the dedication page.
  ///
  /// A decoration choice rather than private information, so unlike the photo
  /// it needs no export-time permission. A story whose profile is gone simply
  /// gets a dedication with no badge.
  KingdomSymbol? _kingdomSymbol(StoryBook story) {
    final state = _ref.read(appControllerProvider).value;
    final profile = state?.profileById(story.content.request.profileId);
    return profile?.kingdomTheme.symbol;
  }

  /// Reads every stored page image of [story], skipping the ones absent here.
  ///
  /// Reads sequentially through the same cache the reader displays from, so an
  /// export shows exactly the pictures the child can already see. A cache that
  /// refuses one identity yields no bytes for that page instead of failing:
  /// losing a picture may cost a text-only page, never the export. Stories with
  /// no bridge identities — every demo book — resolve to no pictures at all.
  Future<Map<String, Uint8List>> _illustrations(StoryBook story) async {
    final illustrationIds = BridgeStoryProvenance.illustrationIdsOf(story);
    if (illustrationIds.isEmpty) return const <String, Uint8List>{};
    final store = _ref.read(illustrationStoreProvider);
    final illustrations = <String, Uint8List>{};
    for (final illustrationId in illustrationIds) {
      try {
        final cached = await store.read(illustrationId);
        if (cached != null) illustrations[illustrationId] = cached.bytes;
      } on Exception {
        continue;
      }
    }
    return illustrations;
  }

  /// Reads the hero's private photo from loaded state, or null when absent.
  String? _coverPhoto(StoryBook story) {
    final state = _ref.read(appControllerProvider).value;
    final profile = state?.profileById(story.content.request.profileId);
    final photoBase64 = profile?.photoBase64;
    return photoBase64 == null || photoBase64.isEmpty ? null : photoBase64;
  }
}
