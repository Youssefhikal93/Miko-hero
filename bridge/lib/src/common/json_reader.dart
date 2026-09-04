import 'package:iam_hero_bridge/src/common/base_url.dart';

/// How one JSON schema names its fields and raises its failures.
///
/// [JsonReader] knows constraints — bounds, types, which keys exist — and
/// nothing about who is asking. This knows the vocabulary a schema's messages
/// use and the exception type its callers already handle, which is what lets a
/// configuration file (a [FormatException] at startup) and an HTTP body (a
/// typed `400`) share one reader without either changing what it throws.
abstract class JsonFieldFailures {
  /// Allows const subclasses.
  const JsonFieldFailures();

  /// Names one field inside a message, e.g. `Field "heroName"`.
  String describeField(String path);

  /// Names the object at [path], which is empty for the whole document.
  String describeContainer(String path);

  /// Builds — never throws — the exception carrying [message] for [path].
  Object failure(String path, String message);
}

/// Failures of the bridge's own configuration file: a [FormatException] that
/// stops startup before anything is served.
class BridgeConfigFailures extends JsonFieldFailures {
  /// Creates the shared configuration failure vocabulary.
  const BridgeConfigFailures();

  @override
  String describeField(String path) => 'Bridge config field "$path"';

  @override
  String describeContainer(String path) => path.isEmpty
      ? 'The bridge configuration'
      : 'Bridge config section "$path"';

  @override
  Object failure(String path, String message) => FormatException(message);
}

/// The vocabulary every `bridge_config.json` field is refused in.
const JsonFieldFailures bridgeConfigFailures = BridgeConfigFailures();

/// Reads one JSON object's fields, refusing anything the schema did not ask
/// for and naming the field — never its value — when it does.
///
/// One reader per object, carrying the dotted path it sits at, so a message
/// about `illustration.upscale.targetSize` says exactly that without every
/// schema threading a path string through every helper. Four schemas used to
/// carry their own copy of this logic and had already drifted: only one of
/// them refused unknown keys, and the same "integer between" sentence was
/// written out three times.
class JsonReader {
  const JsonReader._(this._json, this._path, this._failures);

  /// Reads the whole document [json] under an empty path.
  const JsonReader.root(
    Map<String, Object?> json, {
    required JsonFieldFailures failures,
  }) : this._(json, '', failures);

  /// Reads [value] as the object at [path], refusing anything that is not one.
  ///
  /// [expected] completes the sentence "… must be …" for a caller that wants
  /// to name the shape it needed rather than just "an object".
  factory JsonReader.object(
    Object? value, {
    required String path,
    required JsonFieldFailures failures,
    String expected = 'an object',
  }) {
    if (value is! Map<String, Object?>) {
      throw failures.failure(
        path,
        '${failures.describeField(path)} must be $expected.',
      );
    }
    return JsonReader._(value, path, failures);
  }

  final Map<String, Object?> _json;
  final String _path;
  final JsonFieldFailures _failures;

  /// Dotted path of the object being read; empty at the document root.
  String get path => _path;

  /// Dotted path [field] would be reported under.
  String pathOf(String field) => _path.isEmpty ? field : '$_path.$field';

  /// Refuses any key that is not in [allowed], naming it.
  ///
  /// A key nobody reads is a setting the parent believes is in effect. That is
  /// worth a refusal at startup rather than a book that quietly came out with
  /// the previous settings.
  void rejectUnknownKeys(Set<String> allowed) {
    for (final key in _json.keys) {
      if (!allowed.contains(key)) {
        _raise(
          _path,
          '${_failures.describeContainer(_path)} has no setting named '
          '"$key". Known settings: ${(allowed.toList()..sort()).join(', ')}.',
        );
      }
    }
  }

  /// Whether [field] carries anything at all.
  bool has(String field) => _json[field] != null;

  /// Reads [field] as a required, trimmed, non-empty string.
  String requireString(String field, {int? maxLength}) {
    final value = _json[field];
    if (value is! String || value.trim().isEmpty) {
      _fail(field, 'is required and must be a non-empty string.');
    }
    final trimmed = value.trim();
    return maxLength == null
        ? trimmed
        : _withinLength(field, trimmed, maxLength);
  }

  /// Reads [field] as an optional trimmed string, or `null` when absent.
  ///
  /// A present-but-blank value is refused rather than treated as absent: a
  /// setting someone bothered to write is not a setting they meant to omit.
  String? optionalString(String field, {int? maxLength}) {
    final value = _json[field];
    if (value == null) {
      return null;
    }
    if (value is! String || value.trim().isEmpty) {
      _fail(field, 'must be a non-empty string.');
    }
    final trimmed = value.trim();
    return maxLength == null
        ? trimmed
        : _withinLength(field, trimmed, maxLength);
  }

  /// Reads [field] as optional free text where absent and blank mean the same
  /// thing: nothing was filled in.
  String optionalText(String field, {required int maxLength}) {
    final value = _json[field];
    if (value == null) {
      return '';
    }
    if (value is! String) {
      _fail(field, 'must be a string when present.');
    }
    return _withinLength(field, value.trim(), maxLength);
  }

  /// Reads [field] as a required integer inside `[minimum, maximum]`.
  int requireInt(String field, {required int minimum, required int maximum}) {
    final value = _json[field];
    if (value is! int || value < minimum || value > maximum) {
      _fail(field, 'must be an integer between $minimum and $maximum.');
    }
    return value;
  }

  /// Reads [field] as an optional integer inside `[minimum, maximum]`.
  int optionalInt(
    String field, {
    required int minimum,
    required int maximum,
    required int fallback,
  }) {
    if (_json[field] == null) {
      return fallback;
    }
    return requireInt(field, minimum: minimum, maximum: maximum);
  }

  /// Reads [field] as a required number, accepting its JSON integer spelling.
  ///
  /// `7` and `7.0` are the same number in a file, so an integer is widened;
  /// anything that is not a number at all is refused rather than parsed out of
  /// a string.
  double requireDouble(
    String field, {
    required double minimum,
    required double maximum,
    bool minimumIsExclusive = false,
  }) {
    final value = _json[field];
    final double? number = value is int
        ? value.toDouble()
        : (value is double ? value : null);
    if (number == null ||
        number > maximum ||
        (minimumIsExclusive ? number <= minimum : number < minimum)) {
      _fail(
        field,
        'must be a number ${minimumIsExclusive ? 'above' : 'between'} '
        '$minimum ${minimumIsExclusive ? 'and up to' : 'and'} $maximum.',
      );
    }
    return number;
  }

  /// Reads [field] as an optional number, as [requireDouble] accepts one.
  double optionalDouble(
    String field, {
    required double minimum,
    required double maximum,
    required double fallback,
    bool minimumIsExclusive = false,
  }) {
    if (_json[field] == null) {
      return fallback;
    }
    return requireDouble(
      field,
      minimum: minimum,
      maximum: maximum,
      minimumIsExclusive: minimumIsExclusive,
    );
  }

  /// Reads [field] as an optional boolean.
  bool optionalBool(String field, {required bool fallback}) {
    final value = _json[field];
    if (value == null) {
      return fallback;
    }
    if (value is! bool) {
      _fail(field, 'must be true or false.');
    }
    return value;
  }

  /// Reads [field] as one of [allowed], written exactly as it is spelled
  /// there.
  ///
  /// The type check comes first on purpose: in Dart `512.0 == 512`, so a
  /// float spelling of an integer setting would otherwise slip through a
  /// membership test.
  T choice<T extends Object>(
    String field, {
    required List<T> allowed,
    required T fallback,
  }) {
    final value = _json[field];
    if (value == null) {
      return fallback;
    }
    if (value is! T || !allowed.contains(value)) {
      _fail(field, 'must be one of ${allowed.join(', ')}.');
    }
    return value;
  }

  /// Reads [field] as a required string [resolve] can name a value for.
  ///
  /// [expected] completes "must be …", so a schema keeps the wording its
  /// callers already read — `"girl" or "boy"` rather than a generated list.
  T namedChoice<T extends Object>(
    String field, {
    required T? Function(String) resolve,
    required String expected,
    required int maxLength,
  }) {
    final resolved = resolve(requireString(field, maxLength: maxLength));
    if (resolved == null) {
      _fail(field, 'must be $expected.');
    }
    return resolved;
  }

  /// Reads [field] as an optional string [resolve] can name a value for,
  /// answering `null` only when it is absent — a present value that cannot be
  /// resolved is refused, so `?? aDefault` at the call site is safe.
  T? optionalNamedChoice<T extends Object>(
    String field, {
    required T? Function(String) resolve,
    required String expected,
  }) {
    final value = _json[field];
    if (value == null) {
      return null;
    }
    final resolved = value is String ? resolve(value.trim()) : null;
    if (resolved == null) {
      _fail(field, 'must be $expected.');
    }
    return resolved;
  }

  /// Reads [field] as an optional `http(s)` base URL.
  BaseUrl? optionalBaseUrl(String field) {
    final value = optionalString(field);
    if (value == null) {
      return null;
    }
    final parsed = BaseUrl.tryParse(value);
    if (parsed == null) {
      _fail(field, 'must be an http(s) URL.');
    }
    return parsed;
  }

  /// Reads [field] as an optional list, or `null` when absent.
  List<Object?>? optionalList(String field, {required String expected}) {
    final value = _json[field];
    if (value == null) {
      return null;
    }
    if (value is! List<Object?>) {
      _fail(field, 'must be $expected.');
    }
    return value;
  }

  /// Reads [field] as an optional nested object, or `null` when absent.
  JsonReader? section(String field, {String expected = 'an object'}) {
    final value = _json[field];
    if (value == null) {
      return null;
    }
    return JsonReader.object(
      value,
      path: pathOf(field),
      failures: _failures,
      expected: expected,
    );
  }

  /// A reader over one element of a list read from this object, reported
  /// under `<field>[<index>]`.
  JsonReader elementAt(
    Object? value, {
    required String field,
    required int index,
    String expected = 'an object',
  }) {
    return JsonReader.object(
      value,
      path: '${pathOf(field)}[$index]',
      failures: _failures,
      expected: expected,
    );
  }

  /// Refuses [field] with [constraint], which completes the field's name.
  Never fail(String field, String constraint) => _fail(field, constraint);

  String _withinLength(String field, String value, int maxLength) {
    if (value.length > maxLength) {
      _fail(field, 'exceeds the $maxLength character limit.');
    }
    return value;
  }

  Never _fail(String field, String constraint) {
    final full = pathOf(field);
    _raise(full, '${_failures.describeField(full)} $constraint');
  }

  Never _raise(String path, String message) {
    throw _failures.failure(path, message);
  }
}
