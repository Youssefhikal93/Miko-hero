import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/core/illustrations/illustration_service.dart';
import 'package:miko_hero/core/illustrations/illustration_store.dart';
import 'package:miko_hero/core/illustrations/illustration_store_platform.dart';

/// Supplies this platform's page-image cache, replaced by tests with a fake.
final illustrationStoreProvider = Provider<IllustrationStore>((ref) {
  return createIllustrationStore();
});

/// Supplies how often an illustration job running on the PC is polled.
///
/// Injectable so a test can drive a whole picture run without waiting out the
/// real interval.
final illustrationPollIntervalProvider = Provider<Duration>((ref) {
  return defaultIllustrationPollInterval;
});

/// Supplies the clock the illustration job timeout is measured against.
final illustrationClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

/// Exposes the cached bytes of one page image, or null when none are stored.
///
/// Watched per page rather than per story, so one finished download repaints
/// exactly the page it belongs to. A cache that cannot be read resolves to no
/// bytes instead of an error: a child's page must fall back to its placeholder
/// art, never to a failure message.
final illustrationBytesProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  illustrationId,
) async {
  if (!isUsableIllustrationId(illustrationId)) return null;
  final store = ref.watch(illustrationStoreProvider);
  try {
    return (await store.read(illustrationId))?.bytes;
  } on Exception {
    return null;
  }
});

/// Refreshes every open reader of the page images that just changed.
void invalidateCachedIllustrations(Ref ref, Iterable<String> illustrationIds) {
  for (final illustrationId in illustrationIds) {
    ref.invalidate(illustrationBytesProvider(illustrationId));
  }
}
