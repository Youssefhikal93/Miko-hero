import 'package:flutter/foundation.dart';
import 'package:miko_hero/core/backup/encrypted_backup_codec.dart';
import 'package:miko_hero/core/files/encrypted_file_picker.dart';
import 'package:miko_hero/core/models/app_state.dart';

/// Why an encrypted-file step could not finish, in words a screen localizes.
///
/// The codecs and the picker each raise their own exception type. Collapsing
/// them here is what lets a screen own one sentence per reason instead of a
/// switch over crypto and platform classes it should never have to know.
enum EncryptedFileFailure {
  /// The password did not open the file, or its contents were tampered with.
  wrongPassword,

  /// Not a file of this kind — including this app's other encrypted format.
  unsupportedFile,

  /// Larger than this app will hold in memory.
  tooLarge,

  /// The platform handed over a selection whose bytes it could not read.
  unreadable,

  /// Written by a newer version of the app than this one can represent.
  newerVersion,
}

/// Reports one encrypted-file step that could not finish.
class EncryptedFileException implements Exception {
  /// Creates the failure carrying only its localizable reason.
  const EncryptedFileException(this.reason);

  /// Why the step failed, with no file content or password attached.
  final EncryptedFileFailure reason;

  /// Keeps diagnostics concise without exposing private family content.
  @override
  String toString() => 'Encrypted file failure: ${reason.name}.';
}

/// Encrypts one payload to a file, and opens one back, as a single flow.
///
/// One configuration per payload type — a whole family backup, a single story —
/// differing only in codec, file extension, size cap, and how a file name is
/// derived. Everything else is shared, which is what makes it impossible for a
/// backup and a story file to drift apart in how they are named, bounded, or
/// refused.
///
/// Failures arrive as [EncryptedFileException] so the calling screen looks up
/// one localized sentence per reason rather than switching over codec classes.
class EncryptedFileFlow<T> {
  /// Creates one flow over a picker, a codec pair, and a naming rule.
  const EncryptedFileFlow({
    required this.picker,
    required this.extension,
    required this.maximumBytes,
    required this.encode,
    required this.decode,
    required this.fileStem,
  });

  /// The platform dialogs this flow opens.
  final EncryptedFilePicker picker;

  /// File extension this payload type is written and picked as.
  final String extension;

  /// Largest selection accepted before its bytes are read.
  final int maximumBytes;

  /// Encrypts one payload with the codec belonging to this payload type.
  final Future<Uint8List> Function(T payload, String password) encode;

  /// Authenticates, decrypts, and fully validates one file of this type.
  final Future<T> Function(Uint8List bytes, String password) decode;

  /// Names one payload's file, before the shared safe-name rule bounds it.
  final String Function(T payload) fileStem;

  /// Encrypts one payload without offering it to the platform yet.
  ///
  /// Separate from [save] because the web build asks the parent to confirm the
  /// download after the work is done, and encryption is the slow half.
  Future<Uint8List> encrypt(T payload, String password) {
    return _guarded(() => encode(payload, password));
  }

  /// Offers already encrypted bytes under the name [payload] earns.
  Future<bool> save(Uint8List bytes, T payload, {required String dialogTitle}) {
    return _guarded(
      () => picker.save(
        fileName: '${safeFileStem(fileStem(payload))}.$extension',
        bytes: bytes,
        dialogTitle: dialogTitle,
      ),
    );
  }

  /// Encrypts one payload and offers it, reporting whether it was accepted.
  Future<bool> export(
    T payload,
    String password, {
    required String dialogTitle,
  }) async {
    final bytes = await encrypt(payload, password);
    return save(bytes, payload, dialogTitle: dialogTitle);
  }

  /// Picks one file, asks for its password, and decodes it.
  ///
  /// Null means the parent dismissed the picker or the password prompt, which
  /// is not a failure and changes nothing. [askPassword] receives the picked
  /// file's display name so the prompt can name the file it is about.
  Future<T?> import({
    required Future<String?> Function(String fileName) askPassword,
  }) async {
    final picked = await _guarded(
      () =>
          picker.pick(extensions: <String>[extension], maxBytes: maximumBytes),
    );
    if (picked == null) return null;
    final password = await askPassword(picked.name);
    if (password == null) return null;
    return _guarded(() => decode(picked.bytes, password));
  }

  /// Runs one step, converting every known failure into its typed reason.
  ///
  /// Anything else is rethrown untouched: a caller's own exception, such as a
  /// story identity this device already holds, belongs to the caller.
  Future<R> _guarded<R>(Future<R> Function() step) async {
    try {
      return await step();
    } on BackupAuthenticationException {
      throw const EncryptedFileException(EncryptedFileFailure.wrongPassword);
    } on BackupFormatException {
      throw const EncryptedFileException(EncryptedFileFailure.unsupportedFile);
    } on BackupTooLargeException {
      throw const EncryptedFileException(EncryptedFileFailure.tooLarge);
    } on PickedFileTooLargeException {
      throw const EncryptedFileException(EncryptedFileFailure.tooLarge);
    } on PickedFileReadException {
      throw const EncryptedFileException(EncryptedFileFailure.unreadable);
    } on UnsupportedSchemaVersionException {
      throw const EncryptedFileException(EncryptedFileFailure.newerVersion);
    }
  }
}
