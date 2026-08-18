import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/app/app_controller.dart';

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
  Future<void> setLocale(Locale locale) async {
    final repository = await _ref.read(localRepositoryProvider.future);
    await repository.saveLocale(locale);
    final current = _ref.read(appControllerProvider).requireValue;
    _ref
        .read(appControllerProvider.notifier)
        .commit(current.withLocale(locale));
  }

  /// Deletes all family content while preserving the interface locale.
  Future<void> clearFamilyData() async {
    final repository = await _ref.read(localRepositoryProvider.future);
    await repository.clearAll();
    final current = _ref.read(appControllerProvider).requireValue;
    _ref
        .read(appControllerProvider.notifier)
        .commit(current.withoutFamilyData());
  }
}
