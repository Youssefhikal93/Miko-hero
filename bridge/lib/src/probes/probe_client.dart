import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Minimal HTTP response consumed by health probes.
class ProbeHttpResponse {
  /// Creates a probe response.
  const ProbeHttpResponse({required this.statusCode, required this.bodyBytes});

  /// HTTP status code returned by the probed service.
  final int statusCode;

  /// Raw response body bytes (decoded lazily by probes).
  final Uint8List bodyBytes;

  /// Decodes the body as UTF-8 text.
  String get bodyText => utf8.decode(bodyBytes, allowMalformed: true);
}

/// Abstraction over outbound HTTP used exclusively for local service
/// probing (Ollama and ComfyUI base URLs from configuration).
///
/// Tests substitute fakes here — this is the seam where external services
/// are mocked, so no real Ollama/ComfyUI is ever required in CI.
abstract class ProbeHttpClient {
  /// Performs a GET against [url], aborting with a [TimeoutException] or
  /// [SocketException]-style failure when it cannot complete within
  /// [timeout].
  Future<ProbeHttpResponse> get(Uri url, {required Duration timeout});
}

/// Production [ProbeHttpClient] backed by `dart:io`.
///
/// The client never follows redirects and only ever contacts URLs derived
/// from the configured local service base addresses.
class IoProbeHttpClient implements ProbeHttpClient {
  /// Creates the production IO-backed client.
  const IoProbeHttpClient();

  /// Shared keep-alive HTTP client used by every probe.
  static final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 3)
    ..maxConnectionsPerHost = 4
    ..autoUncompress = true;

  @override
  Future<ProbeHttpResponse> get(Uri url, {required Duration timeout}) async {
    final HttpClientRequest request = await _client
        .getUrl(url)
        .timeout(timeout);
    final HttpClientResponse response = await request.close().timeout(timeout);
    final Uint8List body = await _collectBody(response, timeout);
    return ProbeHttpResponse(statusCode: response.statusCode, bodyBytes: body);
  }

  Future<Uint8List> _collectBody(
    HttpClientResponse response,
    Duration timeout,
  ) {
    final completer = Completer<Uint8List>();
    final builder = BytesBuilder(copy: false);
    late StreamSubscription<List<int>> subscription;
    subscription = response.listen(
      builder.add,
      onDone: () => completer.complete(builder.takeBytes()),
      onError: completer.completeError,
      cancelOnError: true,
    );
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        subscription.cancel();
        throw TimeoutException('Probe response body timed out.', timeout);
      },
    );
  }
}
