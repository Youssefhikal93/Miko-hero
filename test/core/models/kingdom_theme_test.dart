import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/backup/encrypted_backup_codec.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/kingdom_theme.dart';
import 'package:miko_hero/core/models/story_models.dart';

/// Verifies that a child's kingdom decoration survives storage and backups.
void main() {
  test('every chosen decoration survives a JSON round trip', () {
    const chosen = KingdomTheme(
      castle: CastleStyle.crystalSpires,
      frame: AvatarFrameStyle.hearts,
      backdrop: KingdomBackdrop.ocean,
      symbol: KingdomSymbol.rocket,
    );

    final restored = KingdomTheme.fromJson(chosen.toJson());

    expect(restored.castle, CastleStyle.crystalSpires);
    expect(restored.frame, AvatarFrameStyle.hearts);
    expect(restored.backdrop, KingdomBackdrop.ocean);
    expect(restored.symbol, KingdomSymbol.rocket);
    expect(restored.toJson(), chosen.toJson());
  });

  test('a payload without decoration decodes to the defaults', () {
    final restored = KingdomTheme.fromJson(const <String, Object?>{});

    expect(restored.castle, CastleStyle.classicTowers);
    expect(restored.frame, AvatarFrameStyle.none);
    expect(restored.backdrop, KingdomBackdrop.nightSky);
    expect(restored.symbol, KingdomSymbol.star);
  });

  test('a decoration name this build does not know is refused', () {
    for (final malformed in <Map<String, Object?>>[
      <String, Object?>{'castle': 'ice-palace'},
      <String, Object?>{'frame': 'ribbons'},
      <String, Object?>{'backdrop': 'volcano'},
      <String, Object?>{'symbol': 'unicorn'},
      <String, Object?>{'symbol': 7},
    ]) {
      expect(
        () => KingdomTheme.fromJson(malformed),
        throwsA(isA<FormatException>()),
        reason: 'accepted $malformed',
      );
    }
  });

  test('a profile saved before personalization keeps the defaults', () {
    final profile = ChildProfile.fromJson(<String, Object?>{
      'id': 'miko',
      'name': 'Miko',
      'age': 7,
      'photoBase64': 'cGhvdG8=',
      'gender': 'girl',
    });

    expect(profile.kingdomTheme.castle, CastleStyle.classicTowers);
    expect(profile.kingdomTheme.frame, AvatarFrameStyle.none);
  });

  test('a profile keeps its decoration through the encrypted backup', () async {
    final codec = EncryptedBackupCodec();
    final original = _familyState();

    final encrypted = await codec.encode(original, 'family-safe-password');
    final restored = await codec.decode(encrypted, 'family-safe-password');
    final theme = restored.profiles.single.kingdomTheme;

    expect(theme.castle, CastleStyle.forestTreehouse);
    expect(theme.frame, AvatarFrameStyle.laurel);
    expect(theme.backdrop, KingdomBackdrop.meadow);
    expect(theme.symbol, KingdomSymbol.dragon);
  });

  test('a decorated profile is written at the current schema version', () {
    expect(_familyState().toJson()['schemaVersion'], appStateSchemaVersion);
    expect(appStateSchemaVersion, 3);
  });

  test('a version three snapshot is accepted and version four is refused', () {
    final payload = _familyState().toJson();

    expect(
      AppState.fromJson(<String, Object?>{...payload, 'schemaVersion': 3}),
      isA<AppState>(),
    );
    expect(
      () => AppState.fromJson(<String, Object?>{
        ...payload,
        'schemaVersion': appStateSchemaVersion + 1,
      }),
      throwsA(isA<UnsupportedSchemaVersionException>()),
    );
  });
}

/// One decorated family snapshot used by the storage and backup assertions.
AppState _familyState() {
  final profile = ChildProfile(
    id: 'miko',
    name: 'Miko',
    legacyAge: 7,
    birthDate: DateTime(2018, 6, 15),
    photoBase64: 'cHJpdmF0ZS1waG90bw==',
    gender: ChildGender.girl,
    themeColorValue: roseProfileThemeColorValue,
    hasCustomThemeColor: false,
    kingdomTheme: const KingdomTheme(
      castle: CastleStyle.forestTreehouse,
      frame: AvatarFrameStyle.laurel,
      backdrop: KingdomBackdrop.meadow,
      symbol: KingdomSymbol.dragon,
    ),
  );
  return AppState.validated(
    locale: const Locale('sv'),
    profiles: <ChildProfile>[profile],
    stories: const <StoryBook>[],
    activeProfileId: profile.id,
  );
}
