import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/story_card.dart';

/// Verifies what each of the three story tile shapes shows and does.
///
/// The commands themselves are proven through the real library UI in
/// `test/features/library/story_card_overflow_test.dart`; this suite is about
/// the shapes a feature can ask for.
void main() {
  testWidgets('every variant opens the story from the middle of the tile', (
    tester,
  ) async {
    for (final variant in StoryCardVariant.values) {
      var opened = 0;
      await _pumpCard(
        tester,
        variant: variant,
        actions: StoryCardActions(open: () => opened++),
      );

      await tester.tap(find.byType(StoryCard));
      await tester.pumpAndSettle();

      expect(opened, 1, reason: 'variant $variant did not open the story');
    }
  });

  testWidgets('the wide row carries the badge, the heart, the meta and one '
      'overflow control', (tester) async {
    await _pumpCard(
      tester,
      variant: StoryCardVariant.wide,
      story: _story(isFavorite: true),
      actions: StoryCardActions(open: () {}, favorite: () {}, delete: () {}),
    );

    expect(find.text('DEMO'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.text('Moon Garden'), findsOneWidget);
    expect(find.textContaining('2 pages · '), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
  });

  testWidgets('the small tile shows the cover and the title only', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      variant: StoryCardVariant.small,
      actions: StoryCardActions(open: () {}, delete: () {}),
    );

    expect(find.text('Moon Garden'), findsOneWidget);
    expect(find.text('DEMO'), findsNothing);
    expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
  });

  testWidgets('a feature that allows nothing gets no overflow control', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      variant: StoryCardVariant.large,
      actions: StoryCardActions(open: () {}),
    );

    expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
  });
}

/// Places one tile at phone width with the real localizations behind it.
Future<void> _pumpCard(
  WidgetTester tester, {
  required StoryCardVariant variant,
  required StoryCardActions actions,
  StoryBook? story,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 360,
              child: StoryCard(
                story: story ?? _story(),
                variant: variant,
                actions: actions,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Builds one approved two-page demo book.
StoryBook _story({bool isFavorite = false}) {
  return StoryBook(
    id: 'story-moon',
    createdAt: DateTime.utc(2026, 8, 18),
    isFavorite: isFavorite,
    content: StoryContent(
      title: 'Moon Garden',
      request: StoryRequest(
        hero: const StoryHero(
          profileId: 'miko',
          name: 'Miko',
          gender: ChildGender.girl,
        ),
        prompt: const StoryPrompt(
          theme: 'moon garden',
          moral: 'kindness',
          preferences: ChildStoryPreferences(),
        ),
        presentation: const StoryPresentation(
          language: AppLanguage.english,
          length: StoryLength.short,
          style: IllustrationStyle.watercolor,
        ),
      ),
      pages: const <StoryPage>[
        StoryPage(
          number: 1,
          text: 'A kind beginning.',
          sceneDescription: 'A moonlit garden.',
        ),
        StoryPage(
          number: 2,
          text: 'A gentle ending.',
          sceneDescription: 'A sleeping garden.',
        ),
      ],
    ),
  );
}
