import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';

/// Verifies that a child's displayed age stays correct as the child grows.
void main() {
  test('profile stored before birth dates keeps its saved age', () {
    final profile = ChildProfile.fromJson(<String, Object?>{
      'id': 'miko',
      'name': 'Miko',
      'age': 7,
      'photoBase64': 'cGhvdG8=',
      'gender': 'girl',
    });

    expect(profile.birthDate, isNull);
    expect(profile.legacyAge, 7);
    expect(profile.ageOn(DateTime(2030, 8, 19)), 7);
    expect(profile.toJson()['age'], 7);
    expect(profile.toJson().containsKey('birthDate'), isFalse);
  });

  test('age counts the birthday itself and not the day before', () {
    final profile = _profileBornOn('2019-02-28');

    expect(profile.ageOn(DateTime(2026, 2, 27)), 6);
    expect(profile.ageOn(DateTime(2026, 2, 28)), 7);
    expect(profile.ageOn(DateTime(2026, 3, 1)), 7);
  });

  test('a child born on a leap day ages on the following first of March', () {
    final profile = _profileBornOn('2016-02-29');

    expect(profile.ageOn(DateTime(2026, 2, 28)), 9);
    expect(profile.ageOn(DateTime(2026, 3, 1)), 10);
  });

  test('a stored birth date wins over the stale saved age', () {
    final profile = ChildProfile.fromJson(<String, Object?>{
      'id': 'abbas',
      'name': 'Abbas',
      'age': 9,
      'birthDate': '2018-06-15',
      'photoBase64': 'cGhvdG8=',
      'gender': 'boy',
    });

    expect(profile.ageOn(DateTime(2026, 6, 14)), 7);
    expect(profile.ageOn(DateTime(2026, 6, 15)), 8);
  });

  test('a birth date survives a local storage round trip', () {
    final saved = ChildProfile.fromJson(_profileBornOn('2018-06-15').toJson());

    expect(saved.birthDate, DateTime(2018, 6, 15));
    expect(saved.toJson()['birthDate'], '2018-06-15');
  });

  test('malformed stored birth dates are refused at the storage boundary', () {
    for (final malformedDate in <Object>[
      '15-06-2018',
      '2018-6-15',
      '2018-02-30',
      '2018-13-01',
      'yesterday',
      20180615,
    ]) {
      expect(
        () => _profileJsonWith(malformedDate),
        throwsA(isA<FormatException>()),
        reason: 'accepted $malformedDate',
      );
    }
  });

  test('a future birth date is refused at the storage boundary', () {
    final tomorrow = DateTime.now().add(const Duration(days: 1));

    expect(
      () => _profileJsonWith(formatChildBirthDate(tomorrow)),
      throwsA(isA<FormatException>()),
    );
  });

  test('a birth date younger than the supported range is refused', () {
    final lastMonth = DateTime.now().subtract(const Duration(days: 30));

    expect(
      () => _profileJsonWith(formatChildBirthDate(lastMonth)),
      throwsA(isA<FormatException>()),
    );
  });

  test('a profile saved before spellings existed keeps its one name', () {
    final profile = ChildProfile.fromJson(<String, Object?>{
      'id': 'malika',
      'name': 'Malika',
      'age': 7,
      'photoBase64': 'cGhvdG8=',
      'gender': 'girl',
    });

    expect(profile.nameSpellings, isEmpty);
    for (final language in AppLanguage.values) {
      expect(profile.nameIn(language), 'Malika');
      expect(profile.heroNameIn(language), 'Malika hero');
    }
    expect(
      profile.toJson().containsKey('nameSpellings'),
      isFalse,
      reason: 'a profile with no spellings encodes as it always did',
    );
  });

  test('one spelling per language survives a storage round trip', () {
    final saved = _malika().withNameSpellings(<AppLanguage, String>{
      AppLanguage.arabic: 'مليكة',
      AppLanguage.somali: 'Maliika',
    });

    final restored = ChildProfile.fromJson(saved.toJson());

    expect(restored.nameIn(AppLanguage.arabic), 'مليكة');
    expect(restored.nameIn(AppLanguage.somali), 'Maliika');
    expect(
      restored.nameIn(AppLanguage.english),
      'Malika',
      reason: 'a language with no spelling uses the entered name',
    );
    expect(restored.heroNameIn(AppLanguage.arabic), 'مليكة hero');
    expect(restored.toJson()['nameSpellings'], <String, Object>{
      'ar': 'مليكة',
      'so': 'Maliika',
    });
  });

  test('a cleared box is an absent language, not an empty spelling', () {
    final saved = _malika().withNameSpellings(<AppLanguage, String>{
      AppLanguage.arabic: '  مليكة  ',
      AppLanguage.swedish: '   ',
    });

    expect(saved.nameSpellings.keys, <AppLanguage>[AppLanguage.arabic]);
    expect(saved.nameSpellings[AppLanguage.arabic], 'مليكة');
    expect(saved.nameIn(AppLanguage.swedish), 'Malika');
  });

  test('spellings survive every other saved change to the profile', () {
    final saved = _malika()
        .withNameSpellings(<AppLanguage, String>{AppLanguage.arabic: 'مليكة'})
        .withThemeColor(0xFF112233)
        .withFinishedStory('story-1');

    expect(saved.nameIn(AppLanguage.arabic), 'مليكة');
  });

  final malformedSpellings = <String, Object?>{
    'a spelling list that is not an object': <Object?>['مليكة'],
    'an unsupported language code': <String, Object?>{'de': 'Malika'},
    'a blank spelling': <String, Object?>{'ar': '   '},
    'a spelling that is not a string': <String, Object?>{'ar': 7},
    'an oversized spelling': <String, Object?>{
      'ar': 'م' * (maximumChildNameSpellingLength + 1),
    },
  };
  malformedSpellings.forEach((description, encoded) {
    test('$description is refused at the storage boundary', () {
      expect(
        () => ChildProfile.fromJson(<String, Object?>{
          'id': 'malika',
          'name': 'Malika',
          'age': 7,
          'nameSpellings': encoded,
          'photoBase64': 'cGhvdG8=',
          'gender': 'girl',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

/// One valid profile whose name is written differently in different languages.
ChildProfile _malika() {
  return ChildProfile.fromJson(<String, Object?>{
    'id': 'malika',
    'name': 'Malika',
    'age': 7,
    'photoBase64': 'cGhvdG8=',
    'gender': 'girl',
  });
}

/// Builds a valid profile carrying one encoded birth date.
ChildProfile _profileBornOn(String birthDate) {
  return ChildProfile.fromJson(<String, Object?>{
    'id': 'miko',
    'name': 'Miko',
    'age': 7,
    'birthDate': birthDate,
    'photoBase64': 'cGhvdG8=',
    'gender': 'girl',
  });
}

/// Decodes a profile whose birth date is deliberately unusable.
ChildProfile _profileJsonWith(Object birthDate) {
  return ChildProfile.fromJson(<String, Object?>{
    'id': 'miko',
    'name': 'Miko',
    'age': 7,
    'birthDate': birthDate,
    'photoBase64': 'cGhvdG8=',
    'gender': 'girl',
  });
}
