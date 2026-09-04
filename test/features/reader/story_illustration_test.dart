import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/ai_connection/bridge_story_provenance.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';

import '../../support/in_memory_illustration_store.dart';
import '../../support/seeded_device.dart';

/// Verifies what a child sees on a page and on a shelf, with art and without.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a cached page picture replaces the placeholder art', (
    tester,
  ) async {
    await _seed();
    final store = await _storeHolding(const <String>['illustration-1']);

    await pumpApp(tester, route: '/story/story-1', illustrationStore: store);

    expect(_pageImage, findsOneWidget);
    expect(_placeholderFace, findsNothing);
    expect(find.text('1'), findsOneWidget, reason: 'the page number stays');
  });

  testWidgets('a page with no picture keeps the gradient placeholder', (
    tester,
  ) async {
    await _seed();

    await pumpApp(tester, route: '/story/story-1');

    expect(_pageImage, findsNothing);
    expect(_placeholderFace, findsOneWidget);
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
    await _seed(hasBridgeProvenance: false);
    final store = await _storeHolding(const <String>['illustration-1']);

    await pumpApp(tester, route: '/story/story-1', illustrationStore: store);

    expect(_pageImage, findsNothing);
    expect(find.text('DEMO'), findsWidgets);
  });

  testWidgets('a PC story whose first page is cached gets a cover', (
    tester,
  ) async {
    await _seed();
    final store = await _storeHolding(const <String>['illustration-1']);

    await pumpApp(tester, route: '/library', illustrationStore: store);

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
    await _seed();

    await pumpApp(tester, route: '/library');

    expect(_coverImage, findsNothing);
    expect(find.text('The moon garden'), findsWidgets);
  });

  testWidgets('a demo shelf card keeps its badge and its gradient', (
    tester,
  ) async {
    await _seed(hasBridgeProvenance: false);
    final store = await _storeHolding(const <String>['illustration-1']);

    await pumpApp(tester, route: '/library', illustrationStore: store);

    expect(_coverImage, findsNothing);
    expect(find.text('DEMO'), findsWidgets);
  });
}

/// The drawn picture inside the reader page, when there is one.
final Finder _pageImage = find.byKey(
  const ValueKey<String>('page-illustration'),
);

/// The hero's face standing in for a page picture that has not arrived.
final Finder _placeholderFace = find.byKey(
  const ValueKey<String>('page-placeholder-face'),
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
  final bytes = base64Decode(transparentPixelPhoto);
  for (final illustrationId in illustrationIds) {
    await store.write(illustrationId, Uint8List.fromList(bytes), eTag: 'v1');
  }
  return store;
}

/// Stores one family holding a single approved story, from the PC or the demo.
///
/// Only a story whose page carries its bridge identities can ever have a
/// cached picture, which is what separates the two halves of this suite.
Future<void> _seed({bool hasBridgeProvenance = true}) {
  final scene = hasBridgeProvenance
      ? const BridgeStoryProvenance(
          scene: 'a glowing garden',
          storyId: 'story-1',
          illustrationId: 'illustration-1',
        ).toSceneDescription()
      : 'a glowing garden';
  return seedDevice(
    profiles: <ChildProfile>[child()],
    stories: <StoryBook>[
      book(
        profileId: 'miko',
        pages: <StoryPage>[
          storyPage(1, 'Miko woke up. The garden glowed.', scene: scene),
        ],
      ),
    ],
    activeProfileId: 'miko',
  );
}
