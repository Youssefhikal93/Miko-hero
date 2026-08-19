import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_reading_settings.dart';

/// Verifies that per-child reading comfort survives storage and stays bounded.
void main() {
  test('chosen reading comfort survives a JSON round trip', () {
    const chosen = ChildReadingSettings(
      textSize: ReaderTextSize.extraLarge,
      easyReadingFont: true,
    );

    final restored = ChildReadingSettings.fromJson(chosen.toJson());

    expect(restored.textSize, ReaderTextSize.extraLarge);
    expect(restored.easyReadingFont, isTrue);
    expect(restored.toJson(), chosen.toJson());
  });

  test('a payload without reading comfort decodes to the defaults', () {
    final restored = ChildReadingSettings.fromJson(const <String, Object?>{});

    expect(restored.textSize, ReaderTextSize.medium);
    expect(restored.easyReadingFont, isFalse);
  });

  test('a comfort value this build does not know is refused', () {
    for (final malformed in <Map<String, Object?>>[
      <String, Object?>{'textSize': 'gigantic'},
      <String, Object?>{'textSize': 4},
      <String, Object?>{'easyReadingFont': 'yes'},
    ]) {
      expect(
        () => ChildReadingSettings.fromJson(malformed),
        throwsA(isA<FormatException>()),
        reason: 'accepted $malformed',
      );
    }
  });

  test('the easy-reading font applies to Latin script only', () {
    const enabled = ChildReadingSettings(easyReadingFont: true);

    expect(enabled.proseFontFamily(AppLanguage.english), easyReadingFontFamily);
    expect(enabled.proseFontFamily(AppLanguage.swedish), easyReadingFontFamily);
    expect(enabled.proseFontFamily(AppLanguage.somali), easyReadingFontFamily);
    expect(enabled.proseFontFamily(AppLanguage.arabic), isNull);
    expect(
      const ChildReadingSettings().proseFontFamily(AppLanguage.english),
      isNull,
    );
  });

  test('each larger step renders prose bigger than the one before', () {
    final scales = ReaderTextSize.values
        .map((size) => size.scale)
        .toList(growable: false);

    expect(ReaderTextSize.medium.scale, 1);
    expect(scales, orderedEquals(<double>[...scales]..sort()));
    expect(scales.first, lessThan(scales.last));
  });

  test('a profile saved before reading comfort keeps the defaults', () {
    final profile = ChildProfile.fromJson(<String, Object?>{
      'id': 'miko',
      'name': 'Miko',
      'age': 7,
      'photoBase64': 'cGhvdG8=',
      'gender': 'girl',
    });

    expect(profile.readingSettings.textSize, ReaderTextSize.medium);
    expect(profile.readingSettings.easyReadingFont, isFalse);
    expect(profile.finishedStoryIds, isEmpty);
  });

  test('a profile keeps its comfort and rewards through a round trip', () {
    const profile = ChildProfile(
      id: 'miko',
      name: 'Miko',
      legacyAge: 7,
      photoBase64: 'cGhvdG8=',
      gender: ChildGender.girl,
      themeColorValue: roseProfileThemeColorValue,
      hasCustomThemeColor: false,
      readingSettings: ChildReadingSettings(
        textSize: ReaderTextSize.large,
        easyReadingFont: true,
      ),
      finishedStoryIds: <String>['story-moon', 'story-sun'],
    );

    final restored = ChildProfile.fromJson(profile.toJson());

    expect(restored.readingSettings.textSize, ReaderTextSize.large);
    expect(restored.readingSettings.easyReadingFont, isTrue);
    expect(restored.finishedStoryIds, <String>['story-moon', 'story-sun']);
    expect(restored.finishedStoryCount, 2);
  });
}
