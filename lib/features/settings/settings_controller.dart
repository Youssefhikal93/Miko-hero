import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/core/storage/library_transaction.dart';
import 'package:miko_hero/features/story_creation/generation_queue_controller.dart';

/// Supplies application-wide preference and deletion commands to settings.
final settingsControllerProvider = Provider<SettingsController>(
  SettingsController.new,
);

/// Owns locale persistence and deliberate deletion of all family data.
class SettingsController {
  /// Retains access to the shared snapshot and local repository.
  SettingsController(this._ref);

  final Ref _ref;

  /// Persists an interface locale before rebuilding localized widgets.
  Future<void> setLocale(Locale locale) {
    return _ref.read(libraryTransactionProvider).setLocale(locale);
  }

  /// Deletes all family content while preserving the interface locale.
  Future<void> clearFamilyData() async {
    await _ref.read(libraryTransactionProvider).clearFamilyData();
    _ref.invalidate(generationQueueControllerProvider);
  }
}
