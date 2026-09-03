import 'package:shelf/shelf.dart';

/// Grants browser pages controlled cross-origin access to the bridge.
///
/// Web apps are served from a different origin than the bridge (a hosting
/// service, a dev server, or a different local port), so the browser demands
/// CORS consent before it lets the page read a bridge response. Consent is
/// deliberately narrow:
///
/// * loopback origins — `localhost`, `127.0.0.0/8` and `[::1]` on any port —
///   are always allowed, so a web app opened on the PC itself just works;
/// * every other origin must be listed in the configuration's
///   `allowedWebOrigins`;
/// * disallowed origins receive no CORS headers at all, which makes the
///   browser block the response without the bridge revealing anything.
///
/// Requests without an `Origin` header (native apps, curl, the Flutter
/// mobile client) pass through untouched.
Middleware corsMiddleware({required List<String> extraAllowedOrigins}) {
  final normalizedExtra = extraAllowedOrigins.map(_normalizeOrigin).toSet();

  bool isAllowed(String origin) {
    final normalized = _normalizeOrigin(origin);
    if (normalizedExtra.contains(normalized)) {
      return true;
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return false;
    }
    return _isLoopbackHost(uri.host);
  }

  Map<String, String> allowHeaders(String origin) {
    return <String, String>{
      'access-control-allow-origin': origin,
      // Without this a browser hides the ETag from the web app, which then
      // re-downloads every illustration on every check instead of getting
      // the cheap 304.
      'access-control-expose-headers': 'etag',
      'vary': 'Origin',
    };
  }

  return (Handler innerHandler) {
    return (Request request) async {
      final origin = request.headers['origin'];
      if (origin == null) {
        return innerHandler(request);
      }
      final allowed = isAllowed(origin);
      if (request.method == 'OPTIONS') {
        if (!allowed) {
          // No CORS headers: the browser refuses the exchange on its own.
          return Response(204);
        }
        return Response(
          204,
          headers: <String, String>{
            ...allowHeaders(origin),
            'access-control-allow-methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'access-control-allow-headers':
                'authorization, content-type, if-none-match',
            'access-control-max-age': '86400',
          },
        );
      }
      final response = await innerHandler(request);
      if (!allowed) {
        return response;
      }
      return response.change(headers: allowHeaders(origin));
    };
  };
}

bool _isLoopbackHost(String host) {
  final normalized = host.toLowerCase();
  if (normalized == 'localhost' || normalized == '::1') return true;
  final octets = normalized.split('.');
  return octets.length == 4 &&
      octets.first == '127' &&
      octets.every((octet) {
        final value = int.tryParse(octet);
        return value != null && value >= 0 && value <= 255;
      });
}

String _normalizeOrigin(String origin) {
  final trimmed = origin.trim().toLowerCase();
  return trimmed.endsWith('/')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
}
