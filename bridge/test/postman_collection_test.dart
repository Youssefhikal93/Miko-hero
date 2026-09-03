import 'dart:convert';
import 'dart:io';

import 'package:iam_hero_bridge/src/server/bridge_routes.dart';
import 'package:test/test.dart';

/// Name of the committed collection, at the repository root.
const String _collectionFileName = 'Iam-hero-bridge.postman_collection.json';

/// The eight folders the collection is organized into.
const List<String> _expectedFolders = <String>[
  'Health',
  'Pairing',
  'Devices',
  'Profiles',
  'Stories',
  'Illustrations',
  'Sync',
  'Backup',
];

/// One request read out of the collection.
class _CollectionRequest {
  _CollectionRequest({
    required this.folder,
    required this.name,
    required this.method,
    required this.path,
    required this.description,
    required this.auth,
  });

  final String folder;
  final String name;
  final String method;
  final String path;
  final String description;
  final Map<String, Object?>? auth;

  /// `METHOD /normalized/path`, with every parameter segment collapsed.
  String get key => '$method $path';

  /// Where to point at this request when it fails an expectation.
  String get label => '"$folder → $name"';
}

/// Finds the collection by walking up from the test's working directory.
///
/// `dart test` runs from `bridge/`, so the file is one level up; walking makes
/// the test independent of where it was started from.
File _findCollection() {
  Directory directory = Directory.current.absolute;
  while (true) {
    final File candidate = File(
      '${directory.path}${Platform.pathSeparator}$_collectionFileName',
    );
    if (candidate.existsSync()) {
      return candidate;
    }
    final Directory parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError(
        'Could not find $_collectionFileName above ${Directory.current.path}.',
      );
    }
    directory = parent;
  }
}

/// Collapses a path into `METHOD`-comparable form.
///
/// A router parameter (`<jobId>`) and a Postman parameter (`{{jobId}}` or
/// `:jobId`) both become `*`, so the two spellings of the same endpoint match
/// while a genuinely different path never does.
String _normalizePath(List<String> segments) {
  final Iterable<String> collapsed = segments
      .where((String segment) => segment.isNotEmpty)
      .map((String segment) {
        final bool isParameter =
            (segment.startsWith('<') && segment.endsWith('>')) ||
            (segment.startsWith('{{') && segment.endsWith('}}')) ||
            segment.startsWith(':');
        return isParameter ? '*' : segment;
      });
  return '/${collapsed.join('/')}';
}

/// Normalizes a `shelf_router` pattern such as `/stories/jobs/<jobId>`.
String _normalizeRouterPath(String path) {
  return _normalizePath(path.split('/'));
}

/// Reads a Postman request's path, preferring the structured `url.path` list
/// and falling back to `url.raw` for a request written by hand.
String _normalizeRequestPath(Map<String, Object?> url, String label) {
  final Object? path = url['path'];
  if (path is List) {
    return _normalizePath(path.map((Object? part) => '$part').toList());
  }
  final Object? raw = url['raw'];
  if (raw is String) {
    final String withoutHost = raw.replaceFirst('{{baseUrl}}', '');
    final String withoutQuery = withoutHost.split('?').first;
    return _normalizePath(withoutQuery.split('/'));
  }
  throw StateError('Request $label has no usable url.');
}

/// Flattens the collection's folders into the requests they hold.
List<_CollectionRequest> _readRequests(Map<String, Object?> collection) {
  final List<_CollectionRequest> requests = <_CollectionRequest>[];
  final Object? folders = collection['item'];
  if (folders is! List) {
    throw StateError('The collection has no top-level item list.');
  }
  for (final Object? folder in folders) {
    if (folder is! Map<String, Object?>) {
      throw StateError('A top-level item is not an object.');
    }
    final String folderName = '${folder['name']}';
    final Object? entries = folder['item'];
    if (entries is! List) {
      throw StateError('Folder "$folderName" holds no requests.');
    }
    for (final Object? entry in entries) {
      if (entry is! Map<String, Object?>) {
        throw StateError('An item in "$folderName" is not an object.');
      }
      final String name = '${entry['name']}';
      final Object? request = entry['request'];
      if (request is! Map<String, Object?>) {
        throw StateError('"$folderName → $name" has no request.');
      }
      final Object? url = request['url'];
      if (url is! Map<String, Object?>) {
        throw StateError('"$folderName → $name" has no structured url.');
      }
      final Object? auth = request['auth'];
      requests.add(
        _CollectionRequest(
          folder: folderName,
          name: name,
          method: '${request['method']}'.toUpperCase(),
          path: _normalizeRequestPath(url, '"$folderName → $name"'),
          description: request['description'] is String
              ? request['description']! as String
              : '',
          auth: auth is Map<String, Object?> ? auth : null,
        ),
      );
    }
  }
  return requests;
}

void main() {
  late Map<String, Object?> collection;
  late List<_CollectionRequest> requests;

  setUpAll(() {
    final File file = _findCollection();
    final Object? decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, Object?>) {
      throw StateError('$_collectionFileName is not a JSON object.');
    }
    collection = decoded;
    requests = _readRequests(collection);
  });

  group('the Postman collection', () {
    test('declares itself as a v2.1 collection', () {
      final Object? info = collection['info'];
      expect(info, isA<Map<String, Object?>>());
      expect(
        (info! as Map<String, Object?>)['schema'],
        'https://schema.getpostman.com/json/collection/v2.1.0/collection.json',
      );
    });

    test('is organized into the eight documented folders', () {
      final List<Object?> folders = collection['item']! as List<Object?>;
      final List<String> names = folders
          .map(
            (Object? folder) => '${(folder! as Map<String, Object?>)['name']}',
          )
          .toList();
      expect(names, _expectedFolders);
    });

    test('covers every route the router registers', () {
      final Set<String> covered = requests
          .map((_CollectionRequest request) => request.key)
          .toSet();
      final List<String> missing = <String>[];
      for (final BridgeRoute route in bridgeRoutes) {
        final String key =
            '${route.method} ${_normalizeRouterPath(route.path)}';
        if (!covered.contains(key)) {
          missing.add(route.key);
        }
      }
      expect(
        missing,
        isEmpty,
        reason:
            'These routes are served but have no Postman request. Add one to '
            '$_collectionFileName.',
      );
    });

    test('holds nothing the router does not serve', () {
      final Set<String> served = bridgeRoutes
          .map(
            (BridgeRoute route) =>
                '${route.method} ${_normalizeRouterPath(route.path)}',
          )
          .toSet();
      final List<String> stale = <String>[];
      for (final _CollectionRequest request in requests) {
        if (!served.contains(request.key)) {
          stale.add('${request.label} → ${request.method} ${request.path}');
        }
      }
      expect(
        stale,
        isEmpty,
        reason:
            'These Postman requests point at endpoints the bridge no longer '
            'serves.',
      );
    });

    test('holds exactly one request per route', () {
      expect(requests, hasLength(bridgeRoutes.length));
      final Set<String> keys = requests
          .map((_CollectionRequest request) => request.key)
          .toSet();
      expect(
        keys,
        hasLength(requests.length),
        reason: 'Two requests describe the same endpoint.',
      );
    });

    test('describes every request', () {
      for (final _CollectionRequest request in requests) {
        expect(
          request.description.trim(),
          isNotEmpty,
          reason: '${request.label} has no description.',
        );
      }
    });

    test('authenticates at collection level as a bearer device token', () {
      final Object? auth = collection['auth'];
      expect(auth, isA<Map<String, Object?>>());
      final Map<String, Object?> map = auth! as Map<String, Object?>;
      expect(map['type'], 'bearer');
      final List<Object?> bearer = map['bearer']! as List<Object?>;
      final Map<String, Object?> token = bearer.single! as Map<String, Object?>;
      expect(token['key'], 'token');
      expect(token['value'], '{{deviceToken}}');
    });

    test('opts the public endpoints out of auth and no others', () {
      final Set<String> publicKeys = bridgeRoutes
          .where((BridgeRoute route) => !route.requiresAuth)
          .map(
            (BridgeRoute route) =>
                '${route.method} ${_normalizeRouterPath(route.path)}',
          )
          .toSet();
      expect(publicKeys, hasLength(3));

      for (final _CollectionRequest request in requests) {
        if (publicKeys.contains(request.key)) {
          expect(
            request.auth?['type'],
            'noauth',
            reason:
                '${request.label} is a public endpoint and must opt out of the '
                'collection bearer token.',
          );
        } else {
          expect(
            request.auth,
            isNull,
            reason:
                '${request.label} must inherit the collection bearer token '
                'instead of declaring its own auth.',
          );
        }
      }
    });

    test('ships every variable empty except the bridge address', () {
      final List<Object?> declared = collection['variable']! as List<Object?>;
      final Map<String, String> values = <String, String>{
        for (final Object? entry in declared)
          '${(entry! as Map<String, Object?>)['key']}':
              '${(entry as Map<String, Object?>)['value']}',
      };
      expect(values.keys, <String>[
        'baseUrl',
        'deviceToken',
        'profileId',
        'storyId',
        'jobId',
        'illustrationId',
      ]);
      expect(values['baseUrl'], 'http://127.0.0.1:8765');
      for (final MapEntry<String, String> entry in values.entries) {
        if (entry.key == 'baseUrl') {
          continue;
        }
        expect(
          entry.value,
          isEmpty,
          reason:
              'Variable "${entry.key}" ships with a value. The collection must '
              'carry no token and no family data.',
        );
      }
    });

    test('stores the ids the happy path needs into those variables', () {
      final Map<String, String> setterByRoute = <String, String>{
        'POST /pair/confirm': 'deviceToken',
        'POST /stories/generate': 'jobId',
        'POST /stories/*/illustrate': 'jobId',
      };
      for (final MapEntry<String, String> expected in setterByRoute.entries) {
        final String script = _testScriptFor(collection, expected.key);
        expect(
          script,
          contains("pm.collectionVariables.set('${expected.value}'"),
          reason: '${expected.key} must store ${expected.value}.',
        );
      }
      final String manifest = _testScriptFor(collection, 'GET /sync/manifest');
      expect(manifest, contains("pm.collectionVariables.set('storyId'"));
      expect(manifest, contains("pm.collectionVariables.set('illustrationId'"));
    });
  });
}

/// Returns the joined `test` script of the request answering [routeKey].
String _testScriptFor(Map<String, Object?> collection, String routeKey) {
  for (final Object? folder in collection['item']! as List<Object?>) {
    final Map<String, Object?> folderMap = folder! as Map<String, Object?>;
    for (final Object? entry in folderMap['item']! as List<Object?>) {
      final Map<String, Object?> item = entry! as Map<String, Object?>;
      final Map<String, Object?> request =
          item['request']! as Map<String, Object?>;
      final Map<String, Object?> url = request['url']! as Map<String, Object?>;
      final String key =
          '${'${request['method']}'.toUpperCase()} '
          '${_normalizeRequestPath(url, '${item['name']}')}';
      if (key != routeKey) {
        continue;
      }
      final Object? events = item['event'];
      if (events is! List) {
        return '';
      }
      final StringBuffer buffer = StringBuffer();
      for (final Object? event in events) {
        final Map<String, Object?> eventMap = event! as Map<String, Object?>;
        if (eventMap['listen'] != 'test') {
          continue;
        }
        final Map<String, Object?> script =
            eventMap['script']! as Map<String, Object?>;
        for (final Object? line in script['exec']! as List<Object?>) {
          buffer.writeln('$line');
        }
      }
      return buffer.toString();
    }
  }
  throw StateError('No request in the collection answers $routeKey.');
}
