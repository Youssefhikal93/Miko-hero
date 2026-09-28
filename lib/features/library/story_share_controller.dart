import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/backup/encrypted_backup_codec.dart';
import 'package:miko_hero/core/backup/story_share_codec.dart';
import 'package:miko_hero/core/files/encrypted_file_flow.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/shared_story.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/models/unknown_entity_exception.dart';
import 'package:miko_hero/core/storage/library_transaction.dart';

/// Supplies the authenticated encryption codec used by story share commands.
final storyShareCodecProvider = Provider<StoryShareCodec>((ref) {
  return StoryShareCodec();
});

/// Supplies the single-story configuration of the encrypted-file flow.
///
/// Named for the story's own title, which is what a parent recognizes in a
/// message thread; the codec's distinct envelope is what keeps a full family
/// backup from ever opening here.
final storyFileFlowProvider = Provider<EncryptedFileFlow<SharedStory>>((ref) {
  final codec = ref.watch(storyShareCodecProvider);
  return EncryptedFileFlow<SharedStory>(
    picker: ref.watch(encryptedFilePickerProvider),
    extension: storyShareFileExtension,
    maximumBytes: maximumBackupBytes,
    encode: codec.encode,
    decode: codec.decode,
    fileStem: (shared) => shared.story.content.title,
  );
});

/// Supplies single-story export and import commands to library widgets.
final storyShareControllerProvider = Provider<StoryShareController>(
  StoryShareController.new,
);

/// Decides what a story file carries and which shelf an imported one joins.
///
/// The file half belongs to [storyFileFlowProvider]; what is left here is the
/// two things only this app knows — whose name travels with a story, and that
/// an imported book joins a chosen child's shelf as one library transaction.
class StoryShareController {
  /// Retains the provider scope used by the share and import transactions.
  StoryShareController(this._ref);

  final Ref _ref;

  /// Encrypts one stored story with its hero name and offers it as a file.
  ///
  /// The child's reference photo and every other profile detail stay here: the
  /// payload is the book plus the display name the receiving device shows while
  /// the parent chooses a shelf for it. Returns false when the parent cancelled
  /// the save, and reports a story another screen deleted as
  /// [UnknownEntityException].
  Future<bool> exportStory(
    String storyId,
    String password, {
    required String dialogTitle,
  }) {
    final current = _currentState;
    final story = current.requireStoryById(storyId);
    final profile = current.profileById(story.content.request.profileId);
    final heroName = profile?.name ?? story.content.request.heroName;
    return _ref
        .read(storyFileFlowProvider)
        .export(
          SharedStory(story: story, heroName: heroName),
          password,
          dialogTitle: dialogTitle,
        );
  }

  /// Picks one story file, asks for its password, and fully validates it.
  ///
  /// Null means the parent dismissed the picker or the password prompt.
  Future<SharedStory?> openStoryFile({
    required Future<String?> Function(String fileName) askPassword,
  }) {
    return _ref.read(storyFileFlowProvider).import(askPassword: askPassword);
  }

  /// Adds one decoded story to the chosen profile's shelf.
  ///
  /// Refuses a story identity that already exists on this device with
  /// [DuplicateStoryException] so importing the same file twice can never
  /// create a second copy. An unknown destination profile surfaces as
  /// [UnknownEntityException], for example when it was deleted mid-import. The
  /// imported book keeps its review status, so a shared draft still needs
  /// parent approval here.
  Future<void> importStory(SharedStory shared, String profileId) async {
    if (_currentState.profileById(profileId) == null) {
      throw const UnknownEntityException('child profile');
    }
    await _ref.read(libraryTransactionProvider).mutateStories((stories) {
      if (stories.any((story) => story.id == shared.story.id)) {
        throw const DuplicateStoryException();
      }
      // Newest-first is the transaction's job; the import only says which
      // books the shelf should hold afterwards.
      return <StoryBook>[shared.storyForProfile(profileId), ...stories];
    });
  }

  /// Reads the loaded snapshot or preserves the provider's loading error.
  AppState get _currentState {
    return _ref.read(appControllerProvider).requireValue;
  }
}
