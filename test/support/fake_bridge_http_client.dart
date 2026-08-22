import 'dart:convert';

import 'package:http/http.dart' as http;

/// Answers bridge calls from a scripted handler without opening a socket.
///
/// This is the only boundary the local AI tests replace: everything above it —
/// the typed client, the generator, the controllers, and real preference
/// storage — runs exactly as it does on a device.
class FakeBridgeHttpClient extends http.BaseClient {
  /// Creates a client that routes every request through [handler].
  FakeBridgeHttpClient(this.handler);

  /// Produces one answer, or throws to simulate a transport failure.
  final Future<http.Response> Function(http.Request request) handler;

  /// Every request the app made, in order, for request-mapping assertions.
  final List<http.Request> requests = <http.Request>[];

  @override
  /// Records the request and streams the scripted answer back.
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final sentRequest = request as http.Request;
    requests.add(sentRequest);
    final response = await handler(sentRequest);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }

  /// Bodies of every request sent to [path], decoded as UTF-8 JSON.
  List<Map<String, Object?>> jsonBodiesFor(String path) {
    return requests
        .where((request) => request.url.path == path)
        .map(
          (request) =>
              jsonDecode(utf8.decode(request.bodyBytes))
                  as Map<String, Object?>,
        )
        .toList(growable: false);
  }

  /// Number of requests sent to [path], regardless of method.
  int callsTo(String path) {
    return requests.where((request) => request.url.path == path).length;
  }
}

/// Builds a JSON answer encoded exactly the way the bridge encodes its own.
http.Response bridgeJsonResponse(Object body, {int statusCode = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: <String, String>{
      'content-type': 'application/json; charset=utf-8',
    },
  );
}

/// Builds the bridge's typed error envelope for a refused call.
http.Response bridgeErrorResponse(String code, int statusCode) {
  return bridgeJsonResponse(<String, Object>{
    'error': <String, Object>{'code': code, 'message': 'Refused.'},
  }, statusCode: statusCode);
}

/// Builds one completed story payload with [pageCount] validated pages.
///
/// The same shape answers a finished generation job and a synchronization
/// download, which is exactly the property the bridge contract promises.
Map<String, Object> bridgeStoryPayload({
  required String storyId,
  required String languageCode,
  required int pageCount,
  String title = 'The Lantern Path',
  String profileId = 'miko',
  String createdAtUtc = '2026-08-22T10:06:11.000Z',
  String updatedAtUtc = '2026-08-22T10:06:11.000Z',
  String? pageTextPrefix,
  String illustrationIdPrefix = 'illustration',
  String illustrationStatus = 'pending',
}) {
  return <String, Object>{
    'id': storyId,
    'profileId': profileId,
    'title': title,
    'languageCode': languageCode,
    'createdAtUtc': createdAtUtc,
    'updatedAtUtc': updatedAtUtc,
    'pages': <Map<String, Object>>[
      for (var number = 1; number <= pageCount; number++)
        <String, Object>{
          'id': 'page-$number',
          'pageNumber': number,
          'text': pageTextPrefix == null
              ? 'Page $number prose.'
              : '$pageTextPrefix $number.',
          'illustrationScene': 'A lantern scene $number.',
          'illustrationId': '$illustrationIdPrefix-$number',
          'illustrationRelativePath': 'illustrations/$storyId/$number.png',
          'illustrationStatus': illustrationStatus,
        },
    ],
  };
}

/// Builds one `GET /sync/manifest` answer from its entry lists.
Map<String, Object?> bridgeManifestPayload({
  String generatedAtUtc = '2026-08-22T11:00:00.000Z',
  String? lastSyncedAtUtc,
  List<Map<String, Object>> profiles = const <Map<String, Object>>[],
  List<Map<String, Object>> stories = const <Map<String, Object>>[],
  List<Map<String, Object>> deletions = const <Map<String, Object>>[],
}) {
  return <String, Object?>{
    'generatedAtUtc': generatedAtUtc,
    'lastSyncedAtUtc': lastSyncedAtUtc,
    'profiles': profiles,
    'stories': stories,
    'deletions': deletions,
  };
}

/// Builds one manifest profile entry.
Map<String, Object> bridgeManifestProfile({
  required String id,
  required String displayName,
  String updatedAtUtc = '2026-08-22T10:00:00.000Z',
}) {
  return <String, Object>{
    'id': id,
    'displayName': displayName,
    'updatedAtUtc': updatedAtUtc,
  };
}

/// Builds one metadata-only manifest story entry.
Map<String, Object> bridgeManifestStory({
  required String id,
  required String profileId,
  String title = 'The Lantern Path',
  String languageCode = 'en',
  int pageCount = 6,
  String createdAtUtc = '2026-08-22T10:06:11.000Z',
  String updatedAtUtc = '2026-08-22T10:06:11.000Z',
  String illustrationStatus = 'pending',
  String illustrationIdPrefix = 'illustration',
}) {
  return <String, Object>{
    'id': id,
    'profileId': profileId,
    'title': title,
    'languageCode': languageCode,
    'createdAtUtc': createdAtUtc,
    'updatedAtUtc': updatedAtUtc,
    'pageCount': pageCount,
    'illustrations': <Map<String, Object>>[
      for (var number = 1; number <= pageCount; number++)
        <String, Object>{
          'id': '$illustrationIdPrefix-$number',
          'pageNumber': number,
          'status': illustrationStatus,
        },
    ],
  };
}

/// Builds one manifest deletion record.
Map<String, Object> bridgeManifestDeletion({
  required String entityId,
  String entityType = 'story',
  String deletedAtUtc = '2026-08-22T10:30:00.000Z',
}) {
  return <String, Object>{
    'entityType': entityType,
    'entityId': entityId,
    'deletedAtUtc': deletedAtUtc,
  };
}
