import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/story_models.dart';

/// Reports an imported story whose identity already exists on this device.
///
/// Recoverable: the parent picked a file the family already has, so the import
/// screen explains it instead of creating a second copy.
class DuplicateStoryException implements Exception {
  /// Creates the stable duplicate-story error.
  const DuplicateStoryException();
}

/// One story prepared for, or read back from, an encrypted share file.
///
/// Deliberately narrow: the complete story plus the hero's display name, which
/// only exists so the receiving parent can recognize the file before importing.
/// It never carries the reference photo, the child's birth date, the parent PIN,
/// or any other profile field.
class SharedStory {
  /// Creates a share payload from one locally stored story.
  const SharedStory({required this.story, required this.heroName});

  /// Complete story exactly as it is stored, including its review status.
  final StoryBook story;

  /// Hero display name shown in the import preview.
  final String heroName;

  /// Number of reader pages announced by the import preview.
  int get pageCount => story.content.pages.length;

  /// Converts the payload into the JSON written inside the encrypted file.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': appStateSchemaVersion,
      'heroName': heroName,
      'story': story.toJson(),
    };
  }

  /// Validates one decrypted share payload before anything is imported.
  ///
  /// A payload from a newer application version is refused with
  /// [UnsupportedSchemaVersionException] instead of partially applied.
  factory SharedStory.fromJson(Map<String, Object?> json) {
    requireSupportedAppStateSchemaVersion(json['schemaVersion']);
    final heroName = json['heroName'];
    final story = json['story'];
    if (heroName is! String ||
        heroName.trim().isEmpty ||
        story is! Map<String, Object?>) {
      throw const FormatException('Malformed shared story.');
    }
    return SharedStory(
      story: StoryBook.fromJson(story),
      heroName: heroName.trim(),
    );
  }

  /// Returns the shared story attached to one existing local child profile.
  StoryBook storyForProfile(String profileId) {
    return story.withProfileId(profileId);
  }
}
