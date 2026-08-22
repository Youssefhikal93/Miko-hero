import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/illustrations/illustration_store.dart';

import '../../support/in_memory_illustration_store.dart';

/// Verifies the contract every platform page-image cache has to honour.
///
/// The identity check is the part that matters most: these keys arrive from the
/// PC inside a stored scene description, and both platform implementations turn
/// them straight into a file name or an object-store key.
void main() {
  test('only bridge-shaped identities are accepted as keys', () {
    const uuid = '7f3c1b2a-9d44-4e51-8f10-abcdef012345';

    expect(isUsableIllustrationId(uuid), isTrue);
    expect(isUsableIllustrationId('illustration-1'), isTrue);
    expect(isUsableIllustrationId('A' * 64), isTrue);
    expect(isUsableIllustrationId(''), isFalse);
    expect(isUsableIllustrationId('A' * 65), isFalse);
    expect(isUsableIllustrationId('../../secrets'), isFalse);
    expect(isUsableIllustrationId('page 1'), isFalse);
    expect(isUsableIllustrationId('page_1'), isFalse);
    expect(isUsableIllustrationId('page/1'), isFalse);
    expect(isUsableIllustrationId('page.png'), isFalse);
  });

  test('an unusable identity is refused at the cache boundary', () async {
    final store = InMemoryIllustrationStore();

    await expectLater(
      store.read('../escape'),
      throwsA(isA<InvalidIllustrationIdException>()),
    );
    await expectLater(
      store.write('../escape', Uint8List.fromList(<int>[1])),
      throwsA(isA<InvalidIllustrationIdException>()),
    );
  });

  test('written bytes and their ETag come back unchanged', () async {
    final store = InMemoryIllustrationStore();
    final bytes = Uint8List.fromList(<int>[137, 80, 78, 71, 1, 2, 3]);

    expect(await store.read('illustration-1'), isNull);
    await store.write('illustration-1', bytes, eTag: 'etag-1');
    final cached = await store.read('illustration-1');

    expect(cached, isNotNull);
    expect(cached!.bytes, bytes);
    expect(cached.eTag, 'etag-1');
  });

  test('a second write replaces the image and its ETag', () async {
    final store = InMemoryIllustrationStore();
    final first = Uint8List.fromList(<int>[1]);
    await store.write('illustration-1', first, eTag: 'a');

    await store.write('illustration-1', Uint8List.fromList(<int>[2, 3]));
    final cached = await store.read('illustration-1');

    expect(cached!.bytes, <int>[2, 3]);
    expect(cached.eTag, isNull, reason: 'a versionless image has no ETag');
  });

  test('removing one story leaves every other story cached', () async {
    final store = InMemoryIllustrationStore();
    await store.write('story-a-1', Uint8List.fromList(<int>[1]));
    await store.write('story-a-2', Uint8List.fromList(<int>[2]));
    await store.write('story-b-1', Uint8List.fromList(<int>[3]));

    await store.removeForStory(const <String>['story-a-1', 'story-a-2']);

    expect(await store.read('story-a-1'), isNull);
    expect(await store.read('story-a-2'), isNull);
    expect(await store.read('story-b-1'), isNotNull);
  });

  test('clearing drops every cached image', () async {
    final store = InMemoryIllustrationStore();
    await store.write('story-a-1', Uint8List.fromList(<int>[1]));
    await store.write('story-b-1', Uint8List.fromList(<int>[2]));

    await store.clear();

    expect(store.illustrationIds, isEmpty);
  });
}
