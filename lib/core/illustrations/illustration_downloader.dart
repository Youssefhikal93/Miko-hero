import 'package:miko_hero/core/ai_connection/bridge_client.dart';
import 'package:miko_hero/core/ai_connection/bridge_exception.dart';
import 'package:miko_hero/core/illustrations/illustration_store.dart';

/// What one pass of page-image downloads put on this device.
class IllustrationDownloadReport {
  /// Creates the report of one download pass.
  const IllustrationDownloadReport({
    required this.savedIllustrationIds,
    required this.failureCount,
  });

  /// Identities whose bytes were newly written into the local cache.
  ///
  /// Exactly what has to be invalidated so an open reader repaints with the
  /// picture instead of the placeholder it drew a moment ago.
  final List<String> savedIllustrationIds;

  /// Images that could not be fetched and are worth telling the parent about.
  ///
  /// Deliberately excludes the two answers that are not faults: an image the
  /// PC has not drawn yet, and one this device already holds at the version the
  /// PC is still serving.
  final int failureCount;
}

/// Fetches finished page images from the PC into the local image cache.
///
/// Every identity is fetched on its own, and a single refused image never stops
/// the ones behind it: a book with five pictures and one broken page is worth
/// far more to a family than an all-or-nothing download that yields none. An
/// image the PC has not drawn yet is counted separately from one that failed,
/// because "not made yet" is the normal state of a page nobody has rendered.
class IllustrationDownloader {
  /// Creates a downloader bound to one paired client and one local cache.
  const IllustrationDownloader({required this.client, required this.store});

  /// Typed HTTP boundary to the PC bridge.
  final BridgeClient client;

  /// Local per-illustration image cache.
  final IllustrationStore store;

  /// Downloads every identity that is missing locally or has a stale ETag.
  Future<IllustrationDownloadReport> download(
    Iterable<String> illustrationIds,
  ) async {
    final savedIds = <String>[];
    var failureCount = 0;
    for (final illustrationId in illustrationIds) {
      if (!isUsableIllustrationId(illustrationId)) {
        failureCount++;
        continue;
      }
      try {
        final cached = await store.read(illustrationId);
        final download = await client.downloadIllustration(
          illustrationId,
          knownETag: cached?.eTag,
        );
        final bytes = download.bytes;
        // No bytes means the PC is still serving the version already cached.
        if (bytes == null) continue;
        await store.write(illustrationId, bytes, eTag: download.eTag);
        savedIds.add(illustrationId);
      } on BridgeException catch (error) {
        if (error.failure != BridgeFailure.illustrationNotReady) {
          failureCount++;
        }
      } on Exception {
        failureCount++;
      }
    }
    return IllustrationDownloadReport(
      savedIllustrationIds: List<String>.unmodifiable(savedIds),
      failureCount: failureCount,
    );
  }
}
