import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_router.dart';
import 'package:miko_hero/app/iam_hero_app.dart';
import 'package:miko_hero/core/illustrations/illustration_providers.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/storage/bridge_credential_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/in_memory_illustration_store.dart';

/// Verifies what the shelf's chips and its title search actually show.
///
/// Everything runs through the real library UI over real preference storage,
/// with only the platform image cache and the pairing store replaced.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the shelf opens on the first child and names where it lives', (
    tester,
  ) async {
    _storeFamily();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('The shelf'), findsOneWidget);
    expect(find.text('Stored only on this device'), findsOneWidget);
    expect(find.text('The moon garden'), findsOneWidget);
    expect(find.text('The lantern path'), findsOneWidget);
    expect(find.text('Two kites over the harbour'), findsNothing);
  });

  testWidgets('a child chip swaps the shelf for that child', (tester) async {
    _storeFamily();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

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
    _storeFamily();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

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
    _storeFamily();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

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

/// Builds the real application over in-memory device storage.
Widget _app() {
  return ProviderScope(
    overrides: [
      bridgeCredentialStorageProvider.overrideWithValue(
        InMemoryBridgeCredentialStorage(),
      ),
      illustrationStoreProvider.overrideWithValue(InMemoryIllustrationStore()),
    ],
    child: const IamHeroApp(),
  );
}

/// Stores two children whose shelves must stay apart, then opens the shelf.
void _storeFamily() {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'active_profile_id': 'miko',
    'child_profiles': jsonEncode(<Map<String, Object>>[
      _profile('miko', 'Miko', 'girl'),
      _profile('abbas', 'Abbas', 'boy'),
    ]),
    'story_library': jsonEncode(<Map<String, Object>>[
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
    ]),
  });
  appRouter.go('/library');
}

/// One stored child profile, saved the way the profile editor writes it.
Map<String, Object> _profile(String id, String name, String gender) {
  return <String, Object>{
    'id': id,
    'name': name,
    'age': 7,
    'photoBase64': 'cGhvdG8=',
    'gender': gender,
  };
}

/// Builds one stored approved book owned by [profileId].
Map<String, Object> _story({
  required String id,
  required String profileId,
  required String title,
  bool isFavorite = false,
  List<String> collections = const <String>[],
}) {
  return <String, Object>{
    'id': id,
    'createdAt': DateTime.utc(2026, 8, 17, 12).toIso8601String(),
    'reviewStatus': 'approved',
    'isFavorite': isFavorite,
    'collections': collections,
    'content': <String, Object>{
      'title': title,
      'request': <String, Object>{
        'profileId': profileId,
        'heroName': 'Hero',
        'gender': 'girl',
        'prompt': <String, Object>{
          'theme': 'a moon garden',
          'moral': 'kindness',
          'preferences': const ChildStoryPreferences().toJson(),
        },
        'presentation': <String, Object>{
          'language': 'en',
          'length': 'short',
          'style': 'pictureBook',
        },
      },
      'pages': <Map<String, Object>>[
        <String, Object>{
          'number': 1,
          'text': 'The garden glowed.',
          'sceneDescription': 'a glowing garden',
        },
      ],
    },
  };
}
