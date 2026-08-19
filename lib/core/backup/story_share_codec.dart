import 'dart:typed_data';

import 'package:miko_hero/core/backup/encrypted_backup_codec.dart';
import 'package:miko_hero/core/models/shared_story.dart';

/// Envelope format name identifying a single-story share file.
const storyShareEnvelopeFormat = 'iam-hero-story';

/// Authenticated associated data bound to a single-story share file.
const storyShareAssociatedData = 'iam-hero-story:v1';

/// File extension used for encrypted single-story share files.
const storyShareFileExtension = 'iamhero-story';

/// Encrypts and validates one story for transfer to another device.
///
/// Uses exactly the family backup's Argon2id and AES-256-GCM building blocks,
/// the same password rules, the same typed failures, and the same 64 MiB cap,
/// but with its own envelope format and authenticated associated data. A
/// complete backup can therefore never be mistaken for a story file, or the
/// other way around, even when both were protected with the same password.
class StoryShareCodec {
  /// Creates the single-story codec on the shared encrypted envelope.
  ///
  /// [deriver] exists so tests can substitute the isolate boundary; production
  /// code keeps the default `compute` hop.
  StoryShareCodec({BackupKeyDeriver? deriver})
    : _envelope = EncryptedEnvelopeCodec(
        format: storyShareEnvelopeFormat,
        associatedData: storyShareAssociatedData,
        deriver: deriver,
      );

  final EncryptedEnvelopeCodec _envelope;

  /// Encrypts one story and its hero name with a new random salt and nonce.
  Future<Uint8List> encode(SharedStory story, String password) {
    return _envelope.encode(story.toJson(), password);
  }

  /// Authenticates, decrypts, and fully validates one story share file.
  ///
  /// A complete family backup is refused as [BackupFormatException] because it
  /// carries a different envelope format and associated data.
  Future<SharedStory> decode(Uint8List bytes, String password) async {
    final payload = await _envelope.decode(bytes, password);
    try {
      return SharedStory.fromJson(payload);
    } on FormatException {
      throw const BackupFormatException();
    }
  }
}
