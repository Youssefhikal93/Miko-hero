import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Supplies Flutter's built-in Material labels while Somali remains selected.
class SomaliMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  /// Creates the stateless Somali platform-label fallback.
  const SomaliMaterialLocalizationsDelegate();

  @override
  /// Uses the fallback only because Flutter does not ship Somali Material text.
  bool isSupported(Locale locale) => locale.languageCode == 'so';

  @override
  /// Loads English platform labels without changing the app's Somali locale.
  Future<MaterialLocalizations> load(Locale locale) {
    return SynchronousFuture<MaterialLocalizations>(
      const DefaultMaterialLocalizations(),
    );
  }

  @override
  /// Never reloads because the delegate contains no mutable resources.
  bool shouldReload(SomaliMaterialLocalizationsDelegate old) => false;
}

/// Supplies Flutter's built-in Cupertino labels while Somali remains selected.
class SomaliCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  /// Creates the stateless Somali platform-label fallback.
  const SomaliCupertinoLocalizationsDelegate();

  @override
  /// Uses the fallback only because Flutter does not ship Somali Cupertino text.
  bool isSupported(Locale locale) => locale.languageCode == 'so';

  @override
  /// Loads English platform labels without changing the app's Somali locale.
  Future<CupertinoLocalizations> load(Locale locale) {
    return SynchronousFuture<CupertinoLocalizations>(
      const DefaultCupertinoLocalizations(),
    );
  }

  @override
  /// Never reloads because the delegate contains no mutable resources.
  bool shouldReload(SomaliCupertinoLocalizationsDelegate old) => false;
}
