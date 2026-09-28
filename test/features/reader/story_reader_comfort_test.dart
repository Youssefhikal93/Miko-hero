import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_reading_settings.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/narration/narration_options.dart';
import 'package:miko_hero/core/narration/narration_service.dart';
import 'package:miko_hero/shared/reading_text_style.dart';

import '../../support/seeded_device.dart';

/// Verifies the reading comfort and bedtime mode a child actually sees.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the saved text size scales the story prose', (tester) async {
    await _seed(
      readingSettings: const ChildReadingSettings(
        textSize: ReaderTextSize.extraLarge,
      ),
    );

    await _pumpReader(tester);

    final themeSize = _themeProseSize(tester);
    expect(
      _proseStyle(tester).fontSize,
      themeSize * 1.15 * ReaderTextSize.extraLarge.scale,
    );
    expect(_proseStyle(tester).fontSize, greaterThan(themeSize));
    expect(_proseStyle(tester).height, 1.6);
  });

  testWidgets('English prose uses the bundled serif at reading metrics', (
    tester,
  ) async {
    await _seed();

    await _pumpReader(tester);

    expect(_proseStyle(tester).fontSize, _themeProseSize(tester) * 1.15);
    expect(_proseStyle(tester).fontFamily, newsreaderFontFamily);
    expect(_proseStyle(tester).height, 1.6);
  });

  test('the easy-reading font is bundled with the app', () async {
    final font = await rootBundle.load(
      'assets/fonts/AtkinsonHyperlegible-Regular.ttf',
    );

    expect(font.lengthInBytes, greaterThan(1000));
  });

  test('the Newsreader family is bundled with the app', () async {
    final font = await rootBundle.load('assets/fonts/Newsreader-Variable.ttf');

    expect(font.lengthInBytes, greaterThan(1000));
  });

  testWidgets('the easy-reading font applies to an English story', (
    tester,
  ) async {
    await _seed(
      readingSettings: const ChildReadingSettings(easyReadingFont: true),
    );

    await _pumpReader(tester);

    expect(_proseStyle(tester).fontFamily, easyReadingFontFamily);
  });

  testWidgets('an Arabic story keeps its own rendering', (tester) async {
    await _seed(
      readingSettings: const ChildReadingSettings(
        easyReadingFont: true,
        textSize: ReaderTextSize.large,
      ),
      language: AppLanguage.arabic,
    );

    await _pumpReader(tester);

    expect(_proseStyle(tester).fontFamily, isNot(easyReadingFontFamily));
    expect(_proseStyle(tester).fontFamily, _themeProseFontFamily(tester));
    expect(
      _proseStyle(tester).fontSize,
      _themeProseSize(tester) * 1.15 * ReaderTextSize.large.scale,
    );
    expect(_proseStyle(tester).height, 1.6);
  });

  testWidgets('the review preview uses the same reading comfort', (
    tester,
  ) async {
    await _seed(
      readingSettings: const ChildReadingSettings(
        textSize: ReaderTextSize.large,
        easyReadingFont: true,
      ),
      reviewStatus: StoryReviewStatus.draft,
    );

    await _pumpReader(tester, route: '/review/story-1');

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
      themeStyle.fontSize! * 1.15 * ReaderTextSize.large.scale,
    );
    expect(preview.style!.height, 1.6);
  });

  testWidgets('bedtime mode warms the page and dims the prose', (tester) async {
    await _seed();

    await _pumpReader(tester);

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
    await _seed();
    final voice = _FakeVoice();

    await _pumpReader(tester, voice: voice);
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
    await _seed();
    final voice = _FakeVoice();

    await _pumpReader(tester, voice: voice);
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

/// Stores one child and their two-page story before the app is built.
Future<void> _seed({
  ChildReadingSettings readingSettings = const ChildReadingSettings(),
  AppLanguage language = AppLanguage.english,
  StoryReviewStatus reviewStatus = StoryReviewStatus.approved,
}) {
  final prose = language == AppLanguage.arabic
      ? 'استيقظت ميكو. أضاءت الحديقة.'
      : 'Miko woke up. The garden glowed.';
  return seedDevice(
    profiles: <ChildProfile>[child(readingSettings: readingSettings)],
    stories: <StoryBook>[
      book(
        profileId: 'miko',
        language: language,
        reviewStatus: reviewStatus,
        pages: <StoryPage>[
          storyPage(1, prose),
          storyPage(2, prose, scene: 'singing stars'),
        ],
      ),
    ],
    activeProfileId: 'miko',
  );
}

/// Opens the seeded book, optionally with a controllable device voice.
Future<void> _pumpReader(
  WidgetTester tester, {
  NarrationService? voice,
  String route = '/story/story-1',
}) {
  return pumpApp(
    tester,
    route: route,
    overrides: [
      if (voice != null) narrationServiceProvider.overrideWithValue(voice),
    ],
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

/// Opens the reader's narration choices dialog from its sleep-timer icon.
Future<void> _openNarrationSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Sleep timer'));
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
