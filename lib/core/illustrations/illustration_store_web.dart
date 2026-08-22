import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:miko_hero/core/illustrations/illustration_store.dart';
import 'package:web/web.dart' as web;

/// Browser database this device keeps its cached page images in.
const illustrationDatabaseName = 'miko_hero_illustrations';

/// Object store holding one record per illustration identity.
const illustrationObjectStoreName = 'illustrations';

/// Schema version of the browser database this build writes.
const illustrationDatabaseVersion = 1;

/// Creates the IndexedDB-backed image cache used on web.
IllustrationStore createIllustrationStore() => IndexedDbIllustrationStore();

/// Keeps rendered page images in IndexedDB rather than in `localStorage`.
///
/// `localStorage` is the wrong home twice over: it holds text, so every image
/// would have to be base64-inflated first, and its whole quota is a few
/// megabytes, which one illustrated story would exhaust. IndexedDB stores the
/// bytes as bytes and is what the browser sizes generously.
class IndexedDbIllustrationStore implements IllustrationStore {
  Future<web.IDBDatabase>? _database;

  @override
  /// Reads one cached page image, or null when this browser has none.
  Future<CachedIllustration?> read(String illustrationId) async {
    requireUsableIllustrationId(illustrationId);
    final store = await _objectStore(readOnly: true);
    final stored = await _completed(store.get(illustrationId.toJS));
    if (stored == null || !stored.isA<JSObject>()) return null;
    final record = stored as _StoredIllustration;
    final bytes = record.bytes;
    if (bytes == null) return null;
    final eTag = record.eTag?.toDart;
    return CachedIllustration(
      bytes: bytes.toDart,
      eTag: eTag == null || eTag.isEmpty ? null : eTag,
    );
  }

  @override
  /// Replaces one cached page image and the ETag it was served with.
  Future<void> write(
    String illustrationId,
    Uint8List bytes, {
    String? eTag,
  }) async {
    requireUsableIllustrationId(illustrationId);
    final store = await _objectStore(readOnly: false);
    await _completed(
      store.put(
        _StoredIllustration(bytes: bytes.toJS, eTag: eTag?.toJS),
        illustrationId.toJS,
      ),
    );
  }

  @override
  /// Drops every cached image of one story, by its page identities.
  Future<void> removeForStory(Iterable<String> illustrationIds) async {
    final usableIds = illustrationIds.where(isUsableIllustrationId);
    if (usableIds.isEmpty) return;
    final store = await _objectStore(readOnly: false);
    for (final illustrationId in usableIds) {
      await _completed(store.delete(illustrationId.toJS));
    }
  }

  @override
  /// Drops every cached image in this browser.
  Future<void> clear() async {
    final store = await _objectStore(readOnly: false);
    await _completed(store.clear());
  }

  /// Opens one transaction and returns the single object store inside it.
  Future<web.IDBObjectStore> _objectStore({required bool readOnly}) async {
    final database = await _openDatabase();
    final transaction = database.transaction(
      illustrationObjectStoreName.toJS,
      readOnly ? 'readonly' : 'readwrite',
    );
    return transaction.objectStore(illustrationObjectStoreName);
  }

  /// Opens the database once per store, creating the object store on first use.
  Future<web.IDBDatabase> _openDatabase() {
    return _database ??= _open();
  }

  /// Performs the actual open, including the one-time schema upgrade.
  Future<web.IDBDatabase> _open() {
    final request = web.window.indexedDB.open(
      illustrationDatabaseName,
      illustrationDatabaseVersion,
    );
    request.onupgradeneeded = ((web.Event event) {
      final database = request.result as web.IDBDatabase;
      if (!database.objectStoreNames.contains(illustrationObjectStoreName)) {
        database.createObjectStore(illustrationObjectStoreName);
      }
    }).toJS;
    return _completed(request).then((result) {
      if (result == null || !result.isA<web.IDBDatabase>()) {
        throw const IllustrationStoreException();
      }
      return result as web.IDBDatabase;
    });
  }

  /// Awaits one IndexedDB request and reports a refused one as a cache failure.
  Future<JSAny?> _completed(web.IDBRequest request) {
    final completer = Completer<JSAny?>();
    request.onsuccess = ((web.Event event) {
      if (!completer.isCompleted) completer.complete(request.result);
    }).toJS;
    request.onerror = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(const IllustrationStoreException());
      }
    }).toJS;
    return completer.future;
  }
}

/// One stored record: the page image bytes plus the ETag they arrived with.
extension type _StoredIllustration._(JSObject _) implements JSObject {
  /// Builds the object literal IndexedDB stores under one identity.
  external factory _StoredIllustration({JSUint8Array bytes, JSString? eTag});

  /// Stored PNG bytes, absent in a record this build did not write.
  external JSUint8Array? get bytes;

  /// Stored ETag, absent when the bridge served the image without one.
  external JSString? get eTag;
}
