import 'dart:typed_data';

import 'package:miko_hero/core/files/encrypted_file_picker.dart';

/// The platform file dialogs, replaced by what a test already decided.
///
/// The only boundary any file flow needs replaced: backups, story files, and
/// rendered PDFs all reach the device through this one port, so a test that
/// wants to know what a parent would actually receive reads [savedBytes] and
/// [savedFileName] rather than a plugin.
class FakeEncryptedFilePicker implements EncryptedFilePicker {
  /// Creates a picker that offers [picked], or nothing when it is null.
  FakeEncryptedFilePicker({
    this.picked,
    this.pickedName = 'picked-file',
    this.acceptsSave = true,
  });

  /// Bytes handed to a flow as if a parent had chosen that file.
  Uint8List? picked;

  /// Display name the flow shows while asking for the file's password.
  String pickedName;

  /// Whether the parent accepts the save dialog rather than dismissing it.
  bool acceptsSave;

  /// Bytes the last save offered, or null when nothing was ever offered.
  Uint8List? savedBytes;

  /// File name the last save offered, including its extension.
  String? savedFileName;

  /// Extensions the last pick asked the platform to filter on.
  List<String>? pickedExtensions;

  @override
  /// Applies the same size boundary the real platform picker applies.
  Future<PickedFile?> pick({
    required List<String> extensions,
    required int maxBytes,
  }) async {
    pickedExtensions = extensions;
    final bytes = picked;
    if (bytes == null) return null;
    if (bytes.length > maxBytes) throw const PickedFileTooLargeException();
    return PickedFile(name: pickedName, bytes: bytes);
  }

  @override
  /// Records the offer instead of writing anything to the device.
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
    required String dialogTitle,
  }) async {
    if (!acceptsSave) return false;
    savedFileName = fileName;
    savedBytes = bytes;
    return true;
  }
}
