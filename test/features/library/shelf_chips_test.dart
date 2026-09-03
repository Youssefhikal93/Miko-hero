import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';

import '../../support/seeded_device.dart';

/// Verifies what the shelf's chips and its title search actually show.
///
/// Everything runs through the real library UI over real preference storage,
/// with only the platform image cache and the pairing store replaced.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the shelf opens on the first child and names where it lives', (
    tester,
  ) async {
    await _storeFamily();
    await pumpApp(tester, route: '/library');

    expect(find.text('The shelf'), findsOneWidget);
    expect(find.text('Stored only on this device'), findsOneWidget);
    expect(find.text('The moon garden'), findsOneWidget);
    expect(find.text('The lantern path'), findsOneWidget);
    expect(find.text('Two kites over the harbour'), findsNothing);
  });

  testWidgets('a child chip swaps the shelf for that child', (tester) async {
    await _storeFamily();
    await pumpApp(tester, route: '/library');

    await tester.tap(find.byKey(const ValueKey<String>('shelf-child-abbas')));
    await tester.pumpAndSettle();

    expect(find.text('Two kites over the harbour'), findsOneWidget);
    expect(find.text('The moon garden'), findsNothing);
    expect(find.text('The lantern path'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('shelf-child-miko')));
    await tester.pumpAndSettle();

    expect(find.text('The moon garden'), findsOneWidget);
    expect(find.text('Two kites over the harbour'), findsNothing);
  });

  testWidgets('a filter chip narrows the shelf and All brings it back', (
    tester,
  ) async {
    await _storeFamily();
    await pumpApp(tester, route: '/library');

    expect(find.text('All 2'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('shelf-filter-collection:Bedtime')),
    );
    await tester.pumpAndSettle();

    expect(find.text('The moon garden'), findsOneWidget);
    expect(find.text('The lantern path'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('shelf-filter-all')));
    await tester.pumpAndSettle();

    expect(find.text('The lantern path'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('shelf-filter-favorites')),
    );
    await tester.pumpAndSettle();

    expect(find.text('The lantern path'), findsOneWidget);
    expect(find.text('The moon garden'), findsNothing);
  });

  testWidgets('a title search keeps only the books whose title matches', (
    tester,
  ) async {
    await _storeFamily();
    await pumpApp(tester, route: '/library');

    await tester.enterText(
      find.byKey(const ValueKey<String>('shelf-search')),
      'lantern',
    );
    await tester.pumpAndSettle();

    expect(find.text('The lantern path'), findsOneWidget);
    expect(find.text('The moon garden'), findsNothing);
    expect(find.text('All 1'), findsOneWidget);

    // The prose of a story mentions the moon garden; only titles are searched.
    await tester.enterText(
      find.byKey(const ValueKey<String>('shelf-search')),
      'glowed',
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No title on this shelf matches that search.'),
      findsOneWidget,
    );
  });
}

/// Stores two children whose shelves must stay apart.
///
/// Every book carries the same prose, so the title search has something it
/// must deliberately refuse to match on.
Future<void> _storeFamily() {
  return seedDevice(
    profiles: <ChildProfile>[
      child(),
      child(id: 'abbas', name: 'Abbas', gender: ChildGender.boy),
    ],
    stories: <StoryBook>[
      _story(
        id: 'story-1',
        profileId: 'miko',
        title: 'The moon garden',
        collections: const <String>['Bedtime'],
      ),
      _story(
        id: 'story-2',
        profileId: 'miko',
        title: 'The lantern path',
        isFavorite: true,
      ),
      _story(
        id: 'story-3',
        profileId: 'abbas',
        title: 'Two kites over the harbour',
      ),
    ],
    activeProfileId: 'miko',
  );
}

/// Builds one stored approved book owned by [profileId].
StoryBook _story({
  required String id,
  required String profileId,
  required String title,
  bool isFavorite = false,
  List<String> collections = const <String>[],
}) {
  return book(
    id: id,
    profileId: profileId,
    title: title,
    heroName: 'Hero',
    isFavorite: isFavorite,
    collections: collections,
    pages: <StoryPage>[storyPage(1, 'The garden glowed.')],
  );
}
