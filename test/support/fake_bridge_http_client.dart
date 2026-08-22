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
Map<String, Object> bridgeStoryPayload({
  required String storyId,
  required String languageCode,
  required int pageCount,
  String title = 'The Lantern Path',
}) {
  return <String, Object>{
    'id': storyId,
    'profileId': 'miko',
    'title': title,
    'languageCode': languageCode,
    'createdAtUtc': '2026-08-22T10:06:11.000Z',
    'pages': <Map<String, Object>>[
      for (var number = 1; number <= pageCount; number++)
        <String, Object>{
          'id': 'page-$number',
          'pageNumber': number,
          'text': 'Page $number prose.',
          'illustrationScene': 'A lantern scene $number.',
          'illustrationId': 'illustration-$number',
          'illustrationRelativePath': 'illustrations/$storyId/$number.png',
          'illustrationStatus': 'pending',
        },
    ],
  };
}
