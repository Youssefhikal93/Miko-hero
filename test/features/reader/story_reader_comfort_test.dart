import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_router.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/app/iam_hero_app.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_reading_settings.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/narration/narration_options.dart';
import 'package:miko_hero/core/narration/narration_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verifies the reading comfort and bedtime mode a child actually sees.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the saved text size scales the story prose', (tester) async {
    _seed(
      readingSettings: const ChildReadingSettings(
        textSize: ReaderTextSize.extraLarge,
      ),
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final themeSize = _themeProseSize(tester);
    expect(
      _proseStyle(tester).fontSize,
      themeSize * ReaderTextSize.extraLarge.scale,
    );
    expect(_proseStyle(tester).fontSize, greaterThan(themeSize));
  });

  testWidgets('the default text size follows the shared typography', (
    tester,
  ) async {
    _seed();

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(_proseStyle(tester).fontSize, _themeProseSize(tester));
    expect(_proseStyle(tester).fontFamily, isNot(easyReadingFontFamily));
    expect(_proseStyle(tester).fontFamily, _themeProseFontFamily(tester));
  });

  test('the easy-reading font is bundled with the app', () async {
    final font = await rootBundle.load(
      'assets/fonts/AtkinsonHyperlegible-Regular.ttf',
    );

    expect(font.lengthInBytes, greaterThan(1000));
  });

  testWidgets('the easy-reading font applies to an English story', (
    tester,
  ) async {
    _seed(readingSettings: const ChildReadingSettings(easyReadingFont: true));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(_proseStyle(tester).fontFamily, easyReadingFontFamily);
  });

  testWidgets('an Arabic story keeps its own rendering', (tester) async {
    _seed(
      readingSettings: const ChildReadingSettings(
        easyReadingFont: true,
        textSize: ReaderTextSize.large,
      ),
      language: AppLanguage.arabic,
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(_proseStyle(tester).fontFamily, isNot(easyReadingFontFamily));
    expect(_proseStyle(tester).fontFamily, _themeProseFontFamily(tester));
    expect(
      _proseStyle(tester).fontSize,
      _themeProseSize(tester) * ReaderTextSize.large.scale,
    );
  });

  testWidgets('the review preview uses the same reading comfort', (
    tester,
  ) async {
    _seed(
      readingSettings: const ChildReadingSettings(
        textSize: ReaderTextSize.large,
        easyReadingFont: true,
      ),
      reviewStatus: 'draft',
      route: '/review/story-1',
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final preview = tester.widget<SelectableText>(
      find.byKey(const ValueKey<String>('review-page-text')).first,
    );
    final context = tester.element(
      find.byKey(const ValueKey<String>('review-page-text')).first,
    );
    final themeStyle = Theme.of(context).textTheme.bodyLarge!;
    expect(preview.style!.fontFamily, easyReadingFontFamily);
    expect(
      preview.style!.fontSize,
      themeStyle.fontSize! * ReaderTextSize.large.scale,
    );
  });

  testWidgets('bedtime mode warms the page and dims the prose', (tester) async {
    _seed();

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final dayColor = _proseStyle(tester).color;
    expect(
      find.byKey(const ValueKey<String>('bedtime-page-wash')),
      findsNothing,
    );

    await tester.tap(find.byTooltip('Bedtime mode'));
    await tester.pumpAndSettle();

    expect(_proseStyle(tester).color, AppTheme.bedtimeProse);
    expect(_proseStyle(tester).color, isNot(dayColor));
    expect(
      find.byKey(const ValueKey<String>('bedtime-page-wash')),
      findsWidgets,
    );
    expect(find.byTooltip('Turn off bedtime mode'), findsOneWidget);

    await tester.tap(find.byTooltip('Turn off bedtime mode'));
    await tester.pumpAndSettle();

    expect(_proseStyle(tester).color, dayColor);
    expect(
      find.byKey(const ValueKey<String>('bedtime-page-wash')),
      findsNothing,
    );
  });

  testWidgets('narration in bedtime mode picks the ten minute sleep timer', (
    tester,
  ) async {
    _seed();
    final voice = _FakeVoice();

    await tester.pumpWidget(_app(voice: voice));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Bedtime mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Play narration'));
    await tester.pumpAndSettle();

    expect(find.text('Bedtime mode set a 10 min sleep timer.'), findsOneWidget);
    await _dismissNotice(tester);
    await _openNarrationSettings(tester);
    expect(_timerSelected(tester, NarrationSleepTimer.tenMinutes), isTrue);
  });

  testWidgets('a sleep timer the parent chose survives bedtime mode', (
    tester,
  ) async {
    _seed();
    final voice = _FakeVoice();

    await tester.pumpWidget(_app(voice: voice));
    await tester.pumpAndSettle();
    await _openNarrationSettings(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('sleep-timer-fiveMinutes')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Bedtime mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Play narration'));
    await tester.pumpAndSettle();

    expect(find.text('Bedtime mode set a 10 min sleep timer.'), findsNothing);
    await _openNarrationSettings(tester);
    expect(_timerSelected(tester, NarrationSleepTimer.fiveMinutes), isTrue);
    expect(_timerSelected(tester, NarrationSleepTimer.tenMinutes), isFalse);
  });
}

/// Stores one child and their approved story before the app is built.
void _seed({
  ChildReadingSettings readingSettings = const ChildReadingSettings(),
  AppLanguage language = AppLanguage.english,
  String reviewStatus = 'approved',
  String route = '/story/story-1',
}) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'active_profile_id': 'miko',
    'child_profiles': jsonEncode(<Map<String, Object>>[
      <String, Object>{
        'id': 'miko',
        'name': 'Miko',
        'age': 7,
        'photoBase64': _transparentPixel,
        'gender': 'girl',
        'readingSettings': readingSettings.toJson(),
      },
    ]),
    'story_library': jsonEncode(<Map<String, Object>>[
      _story(language, reviewStatus),
    ]),
  });
  appRouter.go(route);
}

/// Builds the real application, optionally with a controllable device voice.
Widget _app({NarrationService? voice}) {
  return ProviderScope(
    overrides: [
      if (voice != null) narrationServiceProvider.overrideWithValue(voice),
    ],
    child: const IamHeroApp(),
  );
}

/// Reads the resolved style of the story prose the child is reading.
TextStyle _proseStyle(WidgetTester tester) {
  return tester
      .widget<Text>(find.byKey(const ValueKey<String>('story-prose')))
      .style!;
}

/// Reads the shared body size the reader scales from.
double _themeProseSize(WidgetTester tester) {
  return _themeProseStyle(tester).fontSize!;
}

/// Reads the interface font a story keeps unless the easy font applies.
String? _themeProseFontFamily(WidgetTester tester) {
  return _themeProseStyle(tester).fontFamily;
}

/// Reads the shared body style the reader starts from.
TextStyle _themeProseStyle(WidgetTester tester) {
  final context = tester.element(
    find.byKey(const ValueKey<String>('story-prose')),
  );
  return Theme.of(context).textTheme.bodyLarge!;
}

/// Waits out a snackbar so it stops covering the reader control bar.
Future<void> _dismissNotice(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

/// Opens the reader's narration choices dialog.
Future<void> _openNarrationSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Narration settings'));
  await tester.pumpAndSettle();
}

/// Reports whether one bedtime limit currently shows as selected.
bool _timerSelected(WidgetTester tester, NarrationSleepTimer timer) {
  return tester
      .widget<ChoiceChip>(
        find.byKey(ValueKey<String>('sleep-timer-${timer.name}')),
      )
      .selected;
}

/// One two-page book in the requested story language and review state.
Map<String, Object> _story(AppLanguage language, String reviewStatus) {
  final prose = language == AppLanguage.arabic
      ? 'استيقظت ميكو. أضاءت الحديقة.'
      : 'Miko woke up. The garden glowed.';
  return <String, Object>{
    'id': 'story-1',
    'createdAt': DateTime.utc(2026, 8, 17, 12).toIso8601String(),
    'reviewStatus': reviewStatus,
    'content': <String, Object>{
      'title': 'The moon garden',
      'request': <String, Object>{
        'profileId': 'miko',
        'heroName': 'Miko',
        'gender': 'girl',
        'prompt': <String, Object>{
          'theme': 'a moon garden',
          'moral': 'kindness',
          'preferences': const ChildStoryPreferences().toJson(),
        },
        'presentation': <String, Object>{
          'language': language.code,
          'length': 'short',
          'style': 'pictureBook',
        },
      },
      'pages': <Map<String, Object>>[
        <String, Object>{
          'number': 1,
          'text': prose,
          'sceneDescription': 'a glowing garden',
        },
        <String, Object>{
          'number': 2,
          'text': prose,
          'sceneDescription': 'singing stars',
        },
      ],
    },
  };
}

/// Device voice that keeps every utterance open so playback stays active.
class _FakeVoice implements NarrationService {
  @override
  /// Reports an installed voice so narration always starts.
  Future<bool> supports(AppLanguage language) async => true;

  @override
  /// Never completes, the way a voice mid-sentence has not finished yet.
  Future<void> speak(NarrationRequest request) => Completer<void>().future;

  @override
  /// Accepts cancellation without completing the outstanding utterance.
  Future<void> stop() async {}
}

const _transparentPixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
