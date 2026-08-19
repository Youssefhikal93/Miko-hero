import 'package:flutter_test/flutter_test.dart';
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
