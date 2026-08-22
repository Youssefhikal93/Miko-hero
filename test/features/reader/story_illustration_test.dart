import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_router.dart';
import 'package:miko_hero/app/iam_hero_app.dart';
import 'package:miko_hero/core/ai_connection/bridge_story_provenance.dart';
import 'package:miko_hero/core/illustrations/illustration_providers.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/in_memory_illustration_store.dart';

/// A one-pixel PNG, small enough to decode inside a widget test.
const _pngPixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

/// Verifies what a child sees on a page and on a shelf, with art and without.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a cached page picture replaces the placeholder art', (
    tester,
  ) async {
    _seed(route: '/story/story-1');
    final store = await _storeHolding(const <String>['illustration-1']);

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(_pageImage, findsOneWidget);
    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.text('1'), findsOneWidget, reason: 'the page number stays');
  });

  testWidgets('a page with no picture keeps the gradient placeholder', (
    tester,
  ) async {
    _seed(route: '/story/story-1');

    await tester.pumpWidget(_app(InMemoryIllustrationStore()));
    await tester.pumpAndSettle();

    expect(_pageImage, findsNothing);
    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'a child never waits at a spinner',
    );
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('a demo story keeps its chip and never shows a picture', (
    tester,
  ) async {
    _seed(route: '/story/story-1', hasBridgeProvenance: false);
    final store = await _storeHolding(const <String>['illustration-1']);

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(_pageImage, findsNothing);
    expect(find.text('DEMO'), findsWidgets);
  });

  testWidgets('a PC story whose first page is cached gets a cover', (
    tester,
  ) async {
    _seed();
    final store = await _storeHolding(const <String>['illustration-1']);

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(_coverImage, findsOneWidget);
    expect(
      find.text('The moon garden'),
      findsWidgets,
      reason: 'the title stays readable over the art',
    );
    expect(find.text('DEMO'), findsNothing);
  });

  testWidgets('a shelf with no cached pictures keeps its gradients', (
    tester,
  ) async {
    _seed();

    await tester.pumpWidget(_app(InMemoryIllustrationStore()));
    await tester.pumpAndSettle();

    expect(_coverImage, findsNothing);
    expect(find.text('The moon garden'), findsWidgets);
  });

  testWidgets('a demo shelf card keeps its badge and its gradient', (
    tester,
  ) async {
    _seed(hasBridgeProvenance: false);
    final store = await _storeHolding(const <String>['illustration-1']);

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(_coverImage, findsNothing);
    expect(find.text('DEMO'), findsWidgets);
  });
}

/// The drawn picture inside the reader page, when there is one.
final Finder _pageImage = find.byKey(
  const ValueKey<String>('page-illustration'),
);

/// The drawn cover behind a library card, when there is one.
final Finder _coverImage = find.byKey(
  const ValueKey<String>('story-cover-image'),
);

/// Builds an in-memory cache already holding the supplied page pictures.
Future<InMemoryIllustrationStore> _storeHolding(
  List<String> illustrationIds,
) async {
  final store = InMemoryIllustrationStore();
  final bytes = base64Decode(_pngPixel);
  for (final illustrationId in illustrationIds) {
    await store.write(illustrationId, Uint8List.fromList(bytes), eTag: 'v1');
  }
  return store;
}

/// Builds the real application over one in-memory page-image cache.
Widget _app(InMemoryIllustrationStore store) {
  return ProviderScope(
    overrides: [illustrationStoreProvider.overrideWithValue(store)],
    child: const IamHeroApp(),
  );
}

/// Stores one family holding a single approved story, then routes to [route].
void _seed({String route = '/library', bool hasBridgeProvenance = true}) {
  final scene = hasBridgeProvenance
      ? const BridgeStoryProvenance(
          scene: 'a glowing garden',
          storyId: 'story-1',
          illustrationId: 'illustration-1',
        ).toSceneDescription()
      : 'a glowing garden';
  SharedPreferences.setMockInitialValues(<String, Object>{
    'active_profile_id': 'miko',
    'child_profiles': jsonEncode(<Map<String, Object>>[
      <String, Object>{
        'id': 'miko',
        'name': 'Miko',
        'age': 7,
        'photoBase64': _pngPixel,
        'gender': 'girl',
      },
    ]),
    'story_library': jsonEncode(<Map<String, Object>>[
      <String, Object>{
        'id': 'story-1',
        'createdAt': DateTime.utc(2026, 8, 17, 12).toIso8601String(),
        'reviewStatus': 'approved',
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
              'language': 'en',
              'length': 'short',
              'style': 'pictureBook',
            },
          },
          'pages': <Map<String, Object>>[
            <String, Object>{
              'number': 1,
              'text': 'Miko woke up. The garden glowed.',
              'sceneDescription': scene,
            },
          ],
        },
      },
    ]),
  });
  appRouter.go(route);
}
