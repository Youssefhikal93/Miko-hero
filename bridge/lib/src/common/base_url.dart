/// A validated `http(s)` root that outbound calls resolve their paths against.
///
/// Every local service the bridge talks to — Ollama, ComfyUI — is configured
/// as a base URL, and every one of them needs the same two things: the URL
/// checked once when the configuration is read, and paths appended to it
/// without doubling or dropping a slash. Doing that in each caller produced
/// four copies of the same trailing-slash loop that could drift apart; this is
/// the one copy.
class BaseUrl {
  const BaseUrl._(this._root, this.text);

  /// Parses [value], or returns `null` when it is not an absolute `http(s)`
  /// URL with a host.
  ///
  /// Trailing slashes are removed, so `http://host:8188/` and
  /// `http://host:8188` are the same base and resolve identical paths.
  static BaseUrl? tryParse(String value) {
    final trimmed = value.trim();
    if (!trimmed.contains('://')) {
      return null;
    }
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null ||
        (parsed.scheme != 'http' && parsed.scheme != 'https') ||
        parsed.host.isEmpty) {
      return null;
    }
    var path = parsed.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    final root = parsed.replace(path: path);
    return BaseUrl._(root, root.toString());
  }

  /// Parses [value] or throws a [FormatException] naming nothing but the
  /// constraint, so a caller can decide how to report the offending value.
  factory BaseUrl.parse(String value) {
    final parsed = BaseUrl.tryParse(value);
    if (parsed == null) {
      throw const FormatException('Not an absolute http(s) base URL.');
    }
    return parsed;
  }

  final Uri _root;

  /// Normalized text form, without a trailing slash; what a config file holds.
  final String text;

  /// Host of the base URL, e.g. `127.0.0.1`.
  String get host => _root.host;

  /// Resolves [path] (which must start with `/`) and optional [query] against
  /// this base, preserving any path prefix the base itself carries.
  Uri resolve(String path, [Map<String, String>? query]) {
    return _root.replace(
      path: '${_root.path}$path',
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }

  @override
  String toString() => text;

  @override
  bool operator ==(Object other) => other is BaseUrl && other.text == text;

  @override
  int get hashCode => text.hashCode;
}
