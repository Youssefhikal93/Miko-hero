import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/ai_connection/bridge_story_provenance.dart';
import 'package:miko_hero/core/illustrations/illustration_providers.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_reading_settings.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/features/reader/reader_spread.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/screen_layout.dart';

import '../../support/in_memory_illustration_store.dart';
import '../../support/seeded_device.dart';

/// Verifies one page of a book as the value round-trip it is.
///
/// Nothing here builds a reader, a route, or a seeded device: a spread is
/// handed one [ReaderPageContext] at one width, and what it draws is the whole
/// of what that value said.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('layout', () {
    testWidgets('a phone width puts the picture over the prose', (
      tester,
    ) async {
      await _pumpSpread(tester, _context(), width: wideReaderBreakpoint - 1);

      final picture = tester.getRect(_placeholderFace);
      final prose = tester.getRect(_prose);
      expect(prose.top, greaterThan(picture.bottom));
      expect(prose.left, lessThan(picture.right));
      expect(picture.left, lessThan(prose.right));
    });

    testWidgets('a wide window puts the picture beside the prose', (
      tester,
    ) async {
      await _pumpSpread(tester, _context(), width: wideReaderBreakpoint);

      final picture = tester.getRect(_placeholderFace);
      final prose = tester.getRect(_prose);
      expect(prose.left, greaterThan(picture.right));
      expect(prose.top, lessThan(picture.bottom));
      expect(picture.top, lessThan(prose.bottom));
    });
  });

  group('the picture', () {
    testWidgets('a page with no picture keeps the hero and the number', (
      tester,
    ) async {
      await _pumpSpread(tester, _context());

      expect(_placeholderFace, findsOneWidget);
      expect(_pageImage, findsNothing);
      expect(find.text('1'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a cached picture replaces the placeholder face', (
      tester,
    ) async {
      final store = InMemoryIllustrationStore();
      await store.write(
        'illustration-1',
        Uint8List.fromList(base64Decode(transparentPixelPhoto)),
        eTag: 'v1',
      );

      await _pumpSpread(tester, _context(drawn: true), store: store);

      expect(_pageImage, findsOneWidget);
      expect(_placeholderFace, findsNothing);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('a story the PC never wrote keeps its demo chip', (
      tester,
    ) async {
      await _pumpSpread(tester, _context());

      expect(find.text('DEMO'), findsOneWidget);
    });

    testWidgets('a story from the PC carries no demo chip', (tester) async {
      await _pumpSpread(tester, _context(drawn: true));

      expect(find.text('DEMO'), findsNothing);
    });
  });

  group('the prose', () {
    testWidgets('an English story reads left to right', (tester) async {
      await _pumpSpread(tester, _context());

      expect(find.text('The moon garden'), findsOneWidget);
      expect(_proseDirection(tester), TextDirection.ltr);
    });

    testWidgets('an Arabic story reads right to left inside a left-to-right '
        'interface', (tester) async {
      await _pumpSpread(tester, _context(language: AppLanguage.arabic));

      expect(_proseDirection(tester), TextDirection.rtl);
    });

    testWidgets('the saved prose size scales the story text', (tester) async {
      await _pumpSpread(
        tester,
        _context(
          readingSettings: const ChildReadingSettings(
            textSize: ReaderTextSize.extraLarge,
          ),
        ),
      );

      final scaled = _proseStyle(tester).fontSize!;

      await _pumpSpread(tester, _context());

      expect(scaled, greaterThan(_proseStyle(tester).fontSize!));
    });

    testWidgets('a narrated sentence is the only tinted one', (tester) async {
      await _pumpSpread(tester, _context(highlightedSentence: 1));

      expect(_highlighted(tester), 'The garden glowed.');
    });

    testWidgets('a silent page tints nothing at all', (tester) async {
      await _pumpSpread(tester, _context());

      expect(_highlighted(tester), isNull);
    });

    testWidgets('a sentence the page does not have tints nothing', (
      tester,
    ) async {
      await _pumpSpread(tester, _context(highlightedSentence: 9));

      expect(_highlighted(tester), isNull);
    });
  });

  group('bedtime', () {
    testWidgets('the day page carries no wash and no warm prose', (
      tester,
    ) async {
      await _pumpSpread(tester, _context());

      expect(_bedtimeWash, findsNothing);
      expect(_proseStyle(tester).color, isNot(AppTheme.bedtimeProse));
    });

    testWidgets('bedtime warms the page and dims the prose', (tester) async {
      await _pumpSpread(tester, _context(bedtime: true));

      expect(_bedtimeWash, findsOneWidget);
      expect(_proseStyle(tester).color, AppTheme.bedtimeProse);
    });

    testWidgets('bedtime keeps the narrated sentence warm', (tester) async {
      await _pumpSpread(
        tester,
        _context(bedtime: true, highlightedSentence: 0),
      );

      expect(_highlighted(tester), 'Miko woke up.');
      expect(_highlightBackground(tester)!.a, greaterThan(0));
    });
  });
}

/// Builds one page value, defaulting to a demo book with no drawn picture.
///
/// [drawn] marks the page as one the PC wrote and illustrated, which is the
/// only kind that can ever resolve to cached bytes.
ReaderPageContext _context({
  bool drawn = false,
  bool bedtime = false,
  int? highlightedSentence,
  AppLanguage language = AppLanguage.english,
  ChildReadingSettings readingSettings = const ChildReadingSettings(),
}) {
  final scene = drawn
      ? const BridgeStoryProvenance(
          scene: 'a glowing garden',
          storyId: 'story-1',
          illustrationId: 'illustration-1',
        ).toSceneDescription()
      : 'a glowing garden';
  final prose = language == AppLanguage.arabic
      ? 'استيقظت ميكو. أضاءت الحديقة.'
      : 'Miko woke up. The garden glowed.';
  final story = book(
    profileId: 'miko',
    language: language,
    pages: <StoryPage>[storyPage(1, prose, scene: scene)],
  );
  return ReaderPageContext(
    story: story,
    page: story.content.pages.first,
    profile: child(),
    readingSettings: readingSettings,
    bedtime: bedtime,
    highlightedSentence: highlightedSentence,
  );
}

/// Draws one spread at [width] with nothing else on screen.
///
/// The width is given by the box around the spread rather than by the window,
/// because the spread asks its own constraints which shape to take.
Future<void> _pumpSpread(
  WidgetTester tester,
  ReaderPageContext pageContext, {
  double width = 400,
  InMemoryIllustrationStore? store,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        illustrationStoreProvider.overrideWithValue(
          store ?? InMemoryIllustrationStore(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              height: 600,
              child: ReaderSpread(pageContext: pageContext),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The hero's face standing in for a page picture that has not arrived.
final Finder _placeholderFace = find.byKey(
  const ValueKey<String>('page-placeholder-face'),
);

/// The drawn picture inside the page, when there is one.
final Finder _pageImage = find.byKey(
  const ValueKey<String>('page-illustration'),
);

/// The story text of the open page.
final Finder _prose = find.byKey(const ValueKey<String>('story-prose'));

/// The warm overlay bedtime mode lays over the picture.
final Finder _bedtimeWash = find.byKey(
  const ValueKey<String>('bedtime-page-wash'),
);

/// Reads the resolved style of the prose the child is reading.
TextStyle _proseStyle(WidgetTester tester) {
  return tester.widget<Text>(_prose).style!;
}

/// Reads the direction the story text itself is laid out in.
TextDirection _proseDirection(WidgetTester tester) {
  return Directionality.of(tester.element(_prose));
}

/// Reads the sentence the page is currently tinting, if any.
String? _highlighted(WidgetTester tester) {
  return _highlightedSpan(tester)?.text;
}

/// Reads the tint colour behind the narrated sentence, if any.
Color? _highlightBackground(WidgetTester tester) {
  return _highlightedSpan(tester)?.style?.backgroundColor;
}

/// Finds the one span the page drew a background behind.
TextSpan? _highlightedSpan(WidgetTester tester) {
  TextSpan? highlighted;
  tester.widget<Text>(_prose).textSpan?.visitChildren((span) {
    if (span is TextSpan && span.style?.backgroundColor != null) {
      highlighted = span;
      return false;
    }
    return true;
  });
  return highlighted;
}
