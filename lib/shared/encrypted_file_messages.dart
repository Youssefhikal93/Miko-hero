import 'package:miko_hero/core/files/encrypted_file_flow.dart';
import 'package:miko_hero/core/models/shared_story.dart';
import 'package:miko_hero/l10n/app_localizations.dart';

/// Localizes one encrypted-file failure for the backup card.
///
/// Backups and story files say different things about the same reason — a
/// parent restoring a family snapshot needs different wording from one opening
/// a single story — so each surface keeps its own sentences while sharing the
/// reasons. Anything that is not a typed file failure keeps the generic
/// recoverable wording.
String backupFileMessage(AppLocalizations text, Object error) {
  if (error is! EncryptedFileException) return text.backupFailed;
  return switch (error.reason) {
    EncryptedFileFailure.wrongPassword => text.backupWrongPassword,
    EncryptedFileFailure.unsupportedFile => text.backupInvalid,
    EncryptedFileFailure.tooLarge => text.backupTooLarge,
    EncryptedFileFailure.unreadable => text.backupFileReadFailed,
    EncryptedFileFailure.newerVersion => text.backupNewerVersion,
  };
}

/// Localizes one encrypted-file failure for the single-story share flow.
///
/// A story already on this device is the one failure that is not about the file
/// at all, so it is answered here rather than left to the generic sentence.
String storyFileMessage(AppLocalizations text, Object error) {
  if (error is DuplicateStoryException) return text.storyAlreadyOnDevice;
  if (error is! EncryptedFileException) return text.storyFileFailed;
  return switch (error.reason) {
    EncryptedFileFailure.wrongPassword => text.storyFileWrongPassword,
    EncryptedFileFailure.unsupportedFile => text.storyFileInvalid,
    EncryptedFileFailure.tooLarge => text.storyFileTooLarge,
    EncryptedFileFailure.unreadable => text.storyFileReadFailed,
    EncryptedFileFailure.newerVersion => text.storyFileNewerVersion,
  };
}
