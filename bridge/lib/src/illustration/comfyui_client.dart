import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Largest ComfyUI JSON answer the bridge is willing to buffer (4 MB).
///
/// A history entry lists file names, not pixels; anything past this is a
/// runaway response and is dropped instead of filling memory.
const int maxComfyUiJsonBytes = 4 * 1024 * 1024;

/// Largest rendered image the bridge will download (16 MB).
///
/// A 512x512 PNG is a few hundred kilobytes. The cap exists so a
/// misconfigured workflow cannot stream an unbounded file into memory.
const int maxComfyUiImageBytes = 16 * 1024 * 1024;

/// Where ComfyUI lives and how long any one call to it may take.
///
/// Passed to every method instead of being captured in a constructor so the
/// production client stays stateless and a test can point two calls at two
/// different budgets without building a second client.
class ComfyUiEndpoint {
  /// Creates an endpoint description.
  const ComfyUiEndpoint({required this.baseUrl, required this.timeout});

  /// Base URL of the local ComfyUI API, e.g. `http://127.0.0.1:8188`.
  final String baseUrl;

  /// Wall-clock budget for one call.
  final Duration timeout;

  /// Resolves [path] (and optional [query]) against [baseUrl].
  Uri resolve(String path, [Map<String, String>? query]) {
    final parsed = Uri.parse(baseUrl);
    var base = parsed.path;
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return parsed.replace(
      path: '$base$path',
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }
}

/// One image ComfyUI saved, as named in a history entry.
class ComfyUiImageReference {
  /// Creates a reference to a saved image.
  const ComfyUiImageReference({
    required this.fileName,
    required this.subfolder,
    required this.type,
  });

  /// File name inside ComfyUI's output folder.
  final String fileName;

  /// Subfolder the file sits in; usually empty.
  final String subfolder;

  /// ComfyUI folder kind, `output` for rendered images.
  final String type;

  /// Parses one entry of a node's `images` list, or `null` when unusable.
  static ComfyUiImageReference? fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) {
      return null;
    }
    final fileName = raw['filename'];
    if (fileName is! String || fileName.isEmpty) {
      return null;
    }
    final subfolder = raw['subfolder'];
    final type = raw['type'];
    return ComfyUiImageReference(
      fileName: fileName,
      subfolder: subfolder is String ? subfolder : '',
      type: type is String && type.isNotEmpty ? type : 'output',
    );
  }
}

/// What `GET /history/<promptId>` says about one submitted workflow.
class ComfyUiHistoryEntry {
  /// Creates a history snapshot.
  const ComfyUiHistoryEntry({
    required this.known,
    required this.completed,
    required this.failed,
    required this.images,
  });

  /// A prompt ComfyUI has never heard of — still queued, or already purged.
  static const ComfyUiHistoryEntry unknown = ComfyUiHistoryEntry(
    known: false,
    completed: false,
    failed: false,
    images: <ComfyUiImageReference>[],
  );

  /// Whether ComfyUI returned an entry for the prompt at all.
  final bool known;

  /// Whether `status.completed` is true.
  final bool completed;

  /// Whether `status.status_str` reports an error.
  final bool failed;

  /// Every image any node saved, in node then list order.
  final List<ComfyUiImageReference> images;

  /// Parses the body of `GET /history/<promptId>` for [promptId].
  factory ComfyUiHistoryEntry.fromResponseJson(
    Map<String, Object?> body,
    String promptId,
  ) {
    final entry = body[promptId];
    if (entry is! Map<String, Object?>) {
      return ComfyUiHistoryEntry.unknown;
    }
    var completed = false;
    var failed = false;
    final status = entry['status'];
    if (status is Map<String, Object?>) {
      completed = status['completed'] == true;
      final statusString = status['status_str'];
      failed = statusString is String && statusString.toLowerCase() == 'error';
    }
    final images = <ComfyUiImageReference>[];
    final outputs = entry['outputs'];
    if (outputs is Map<String, Object?>) {
      final nodeIds = outputs.keys.toList()..sort();
      for (final nodeId in nodeIds) {
        final node = outputs[nodeId];
        if (node is! Map<String, Object?>) {
          continue;
        }
        final nodeImages = node['images'];
        if (nodeImages is! List<Object?>) {
          continue;
        }
        for (final raw in nodeImages) {
          final image = ComfyUiImageReference.fromJson(raw);
          if (image != null) {
            images.add(image);
          }
        }
      }
    }
    return ComfyUiHistoryEntry(
      known: true,
      completed: completed,
      failed: failed,
      images: List<ComfyUiImageReference>.unmodifiable(images),
    );
  }
}

/// Abstraction over every outbound call illustration rendering makes.
///
/// This is the seam tests replace: no real ComfyUI server is ever needed.
/// Implementations propagate transport failures ([SocketException],
/// [TimeoutException], [HttpException]) and throw a [ComfyUiCallException]
/// for a rejected call; the job engine maps both to typed failure codes.
abstract class ComfyUiClient {
  /// Whether ComfyUI answers `GET /system_stats`.
  ///
  /// Never throws: an unreachable server is a `false`, which is how the
  /// queue tells "ComfyUI is off" apart from "this page did not render".
  Future<bool> isReachable(ComfyUiEndpoint endpoint);

  /// Whether this ComfyUI install knows the node class [classType].
  ///
  /// Asked before a graph that needs a custom node is ever submitted, so an
  /// uninstalled extension becomes one clear error instead of every page of
  /// the book failing at submission time. Never throws: like [isReachable],
  /// a server that cannot answer is a `false`.
  Future<bool> supportsNodeType(ComfyUiEndpoint endpoint, String classType);

  /// Uploads [bytes] as an input image and returns the name ComfyUI stored
  /// it under, which is what a `LoadImage` node must reference.
  Future<String> uploadReferenceImage(
    ComfyUiEndpoint endpoint, {
    required String fileName,
    required String contentType,
    required Uint8List bytes,
  });

  /// Queues [workflow] under [clientId] and returns the new prompt id.
  Future<String> submitWorkflow(
    ComfyUiEndpoint endpoint, {
    required Map<String, Object?> workflow,
    required String clientId,
  });

  /// Reads what ComfyUI currently knows about [promptId].
  Future<ComfyUiHistoryEntry> readHistory(
    ComfyUiEndpoint endpoint, {
    required String promptId,
  });

  /// Downloads the bytes of one saved [image].
  Future<Uint8List> fetchImage(
    ComfyUiEndpoint endpoint, {
    required ComfyUiImageReference image,
  });

  /// Asks ComfyUI to abandon whatever it is rendering right now.
  ///
  /// Best effort: a failure here is swallowed by the caller, because the
  /// only reason to interrupt is that the bridge has already given up.
  Future<void> interrupt(ComfyUiEndpoint endpoint);
}

/// Raised when ComfyUI answers a call with something unusable.
class ComfyUiCallException implements Exception {
  /// Creates the exception with a safe [message].
  const ComfyUiCallException(this.message);

  /// Explanation that never quotes prompts, scene text or image data.
  final String message;

  @override
  String toString() => 'ComfyUiCallException($message)';
}

/// Production [ComfyUiClient] backed by `dart:io`.
class IoComfyUiClient implements ComfyUiClient {
  /// Creates the production IO-backed client.
  const IoComfyUiClient();

  /// Shared client. Rendering is single-threaded by design, so a couple of
  /// connections to one host are plenty.
  static final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..maxConnectionsPerHost = 2
    ..autoUncompress = true;

  @override
  Future<bool> isReachable(ComfyUiEndpoint endpoint) async {
    try {
      final response = await _send(
        endpoint,
        method: 'GET',
        url: endpoint.resolve('/system_stats'),
        maxResponseBytes: maxComfyUiJsonBytes,
      );
      return response.statusCode == HttpStatus.ok;
    } on Exception catch (_) {
      return false;
    }
  }

  @override
  Future<bool> supportsNodeType(
    ComfyUiEndpoint endpoint,
    String classType,
  ) async {
    try {
      // One node's schema rather than the whole `/object_info` catalogue,
      // which is megabytes of every installed node on a busy install.
      final response = await _send(
        endpoint,
        method: 'GET',
        url: endpoint.resolve('/object_info/$classType'),
        maxResponseBytes: maxComfyUiJsonBytes,
      );
      if (response.statusCode != HttpStatus.ok) {
        return false;
      }
      final Object? decoded = jsonDecode(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      // An unknown class answers `200 {}` on some builds and `404` on
      // others, so the entry has to actually be there.
      return decoded is Map<String, Object?> && decoded.containsKey(classType);
    } on Exception catch (_) {
      return false;
    }
  }

  @override
  Future<String> uploadReferenceImage(
    ComfyUiEndpoint endpoint, {
    required String fileName,
    required String contentType,
    required Uint8List bytes,
  }) async {
    const boundary = '----iam-hero-bridge-reference-photo';
    final builder = BytesBuilder(copy: false)
      ..add(
        utf8.encode(
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="image"; '
          'filename="$fileName"\r\n'
          'Content-Type: $contentType\r\n\r\n',
        ),
      )
      ..add(bytes)
      ..add(
        utf8.encode(
          '\r\n--$boundary\r\n'
          'Content-Disposition: form-data; name="type"\r\n\r\n'
          'input\r\n'
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="overwrite"\r\n\r\n'
          'true\r\n'
          '--$boundary--\r\n',
        ),
      );
    final response = await _send(
      endpoint,
      method: 'POST',
      url: endpoint.resolve('/upload/image'),
      body: builder.takeBytes(),
      contentType: 'multipart/form-data; boundary=$boundary',
      maxResponseBytes: maxComfyUiJsonBytes,
    );
    final decoded = _decodeJsonObject(response, 'the image upload');
    final name = decoded['name'];
    if (name is! String || name.isEmpty) {
      throw const ComfyUiCallException(
        'ComfyUI did not name the uploaded reference image.',
      );
    }
    final subfolder = decoded['subfolder'];
    if (subfolder is String && subfolder.isNotEmpty) {
      // LoadImage addresses files inside the input folder by relative path.
      return '$subfolder/$name';
    }
    return name;
  }

  @override
  Future<String> submitWorkflow(
    ComfyUiEndpoint endpoint, {
    required Map<String, Object?> workflow,
    required String clientId,
  }) async {
    final body = utf8.encode(
      jsonEncode(<String, Object?>{'prompt': workflow, 'client_id': clientId}),
    );
    final response = await _send(
      endpoint,
      method: 'POST',
      url: endpoint.resolve('/prompt'),
      body: body,
      // The scene text inside a workflow is UTF-8 and corrupts if the
      // transport is left to guess, exactly as it does for Ollama.
      contentType: 'application/json; charset=utf-8',
      maxResponseBytes: maxComfyUiJsonBytes,
    );
    final decoded = _decodeJsonObject(response, 'the workflow submission');
    final promptId = decoded['prompt_id'];
    if (promptId is! String || promptId.isEmpty) {
      throw const ComfyUiCallException(
        'ComfyUI accepted the workflow without returning a prompt id.',
      );
    }
    return promptId;
  }

  @override
  Future<ComfyUiHistoryEntry> readHistory(
    ComfyUiEndpoint endpoint, {
    required String promptId,
  }) async {
    final response = await _send(
      endpoint,
      method: 'GET',
      url: endpoint.resolve('/history/$promptId'),
      maxResponseBytes: maxComfyUiJsonBytes,
    );
    if (response.statusCode == HttpStatus.notFound) {
      return ComfyUiHistoryEntry.unknown;
    }
    final decoded = _decodeJsonObject(response, 'the render history');
    return ComfyUiHistoryEntry.fromResponseJson(decoded, promptId);
  }

  @override
  Future<Uint8List> fetchImage(
    ComfyUiEndpoint endpoint, {
    required ComfyUiImageReference image,
  }) async {
    final response = await _send(
      endpoint,
      method: 'GET',
      url: endpoint.resolve('/view', <String, String>{
        'filename': image.fileName,
        'subfolder': image.subfolder,
        'type': image.type,
      }),
      maxResponseBytes: maxComfyUiImageBytes,
    );
    if (response.statusCode != HttpStatus.ok) {
      throw ComfyUiCallException(
        'ComfyUI answered HTTP ${response.statusCode} for a rendered image.',
      );
    }
    return response.bodyBytes;
  }

  @override
  Future<void> interrupt(ComfyUiEndpoint endpoint) async {
    await _send(
      endpoint,
      method: 'POST',
      url: endpoint.resolve('/interrupt'),
      body: Uint8List(0),
      contentType: 'application/json; charset=utf-8',
      maxResponseBytes: maxComfyUiJsonBytes,
    );
  }

  Map<String, Object?> _decodeJsonObject(_RawResponse response, String what) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ComfyUiCallException(
        'ComfyUI answered HTTP ${response.statusCode} for $what.',
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
    } on FormatException {
      throw ComfyUiCallException('ComfyUI answered $what with invalid JSON.');
    }
    if (decoded is! Map<String, Object?>) {
      throw ComfyUiCallException(
        'ComfyUI answered $what with an unexpected JSON shape.',
      );
    }
    return decoded;
  }

  Future<_RawResponse> _send(
    ComfyUiEndpoint endpoint, {
    required String method,
    required Uri url,
    required int maxResponseBytes,
    Uint8List? body,
    String? contentType,
  }) {
    return _open(
      method: method,
      url: url,
      body: body,
      contentType: contentType,
      maxResponseBytes: maxResponseBytes,
    ).timeout(
      endpoint.timeout,
      onTimeout: () => throw TimeoutException(
        'ComfyUI did not answer in time.',
        endpoint.timeout,
      ),
    );
  }

  Future<_RawResponse> _open({
    required String method,
    required Uri url,
    required int maxResponseBytes,
    Uint8List? body,
    String? contentType,
  }) async {
    final HttpClientRequest request = await _client.openUrl(method, url);
    request.headers.set(HttpHeaders.acceptHeader, '*/*');
    if (body != null) {
      if (contentType != null) {
        request.headers.set(HttpHeaders.contentTypeHeader, contentType);
      }
      request.contentLength = body.length;
      request.add(body);
    }
    final HttpClientResponse response = await request.close();
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
      if (builder.length > maxResponseBytes) {
        throw const ComfyUiCallException(
          'A ComfyUI answer exceeded the accepted size.',
        );
      }
    }
    return _RawResponse(response.statusCode, builder.takeBytes());
  }
}

class _RawResponse {
  const _RawResponse(this.statusCode, this.bodyBytes);

  final int statusCode;
  final Uint8List bodyBytes;
}
