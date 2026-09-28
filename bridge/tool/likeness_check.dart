import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:iam_hero_bridge/iam_hero_bridge.dart';
import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';

/// Makes the repeatable, by-eye comparison for one Child profile's drawn Hero.
///
/// The tool deliberately leaves `<out>/bridge-config.json` behind. The owner
/// changes `ipAdapterWeight` or `referenceDenoise` there and runs the same
/// command again, which makes the tuning loop compare like with like. The
/// Bridge requires a Child profile before it accepts a reference photo, so the
/// tool first writes one unillustrated throwaway Story to its temporary Master
/// library; neither compared Story is planned until the Character sheet has
/// been read from the photo.
const String likenessCheckUsage =
    'Usage: dart run tool/likeness_check.dart --photo <path> '
    '--config-from <path> --out <dir> [--language <en|ar|sv|so>] '
    '[--hero-name <name>] [--gender <girl|boy>] [--pages <n>] [--port <n>]';

/// Arguments controlling one likeness comparison run.
class LikenessCheckArguments {
  /// Creates parsed command-line arguments.
  const LikenessCheckArguments({
    required this.photoPath,
    required this.configFromPath,
    required this.outputPath,
    required this.language,
    required this.heroName,
    required this.gender,
    required this.pageCount,
    required this.port,
  });

  /// Path to the private JPEG or PNG reference photo.
  final String photoPath;

  /// Existing Bridge configuration whose illustration settings are reproduced.
  final String configFromPath;

  /// Directory that receives the temporary Master library and comparison.
  final String outputPath;

  /// Story language code.
  final String language;

  /// Hero name used for both compared Stories.
  final String heroName;

  /// Parent-confirmed Girl/Boy context for both Stories and illustrations.
  final String gender;

  /// Number of pages in each Story.
  final int pageCount;

  /// Loopback port used by the child Bridge.
  final int port;
}

/// Parses the narrow command line accepted by the likeness comparison tool.
///
/// Keeping this pure makes the private-photo workflow testable without a
/// Bridge, Ollama, ComfyUI, or a Child profile.
LikenessCheckArguments parseLikenessCheckArguments(List<String> arguments) {
  final values = <String, String>{};
  const known = <String>{
    '--photo',
    '--config-from',
    '--out',
    '--language',
    '--hero-name',
    '--gender',
    '--pages',
    '--port',
  };
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (!known.contains(argument) || index + 1 >= arguments.length) {
      throw const FormatException('Invalid likeness-check arguments.');
    }
    if (values.containsKey(argument)) {
      throw const FormatException(
        'Each likeness-check argument may appear once.',
      );
    }
    final value = arguments[++index];
    if (value.isEmpty || value.startsWith('--')) {
      throw const FormatException(
        'Every likeness-check argument needs a value.',
      );
    }
    values[argument] = value;
  }

  for (final required in <String>['--photo', '--config-from', '--out']) {
    if (!values.containsKey(required)) {
      throw const FormatException(
        'Required likeness-check argument is missing.',
      );
    }
  }

  final language = values['--language'] ?? 'en';
  if (!const <String>{'en', 'ar', 'sv', 'so'}.contains(language)) {
    throw const FormatException('Unsupported story language.');
  }
  final gender = values['--gender'] ?? 'boy';
  if (!const <String>{'girl', 'boy'}.contains(gender)) {
    throw const FormatException('Unsupported Hero gender.');
  }
  final pageValue = values['--pages'];
  final pages = pageValue == null
      ? allowedStoryPageCounts.first
      : int.tryParse(pageValue);
  if (pages == null || !allowedStoryPageCounts.contains(pages)) {
    throw const FormatException('Unsupported Story page count.');
  }
  final portValue = values['--port'];
  final port = portValue == null ? 8799 : int.tryParse(portValue);
  if (port == null || port < 1 || port > 65535) {
    throw const FormatException('Invalid Bridge port.');
  }

  return LikenessCheckArguments(
    photoPath: values['--photo']!,
    configFromPath: values['--config-from']!,
    outputPath: values['--out']!,
    language: language,
    heroName: values['--hero-name'] ?? 'Sami',
    gender: gender,
    pageCount: pages,
    port: port,
  );
}

/// Copies a validated Bridge configuration while forcing the isolated run.
///
/// The Bridge's own configuration parser validates the source first. The JSON
/// copy then preserves every configured value, particularly the illustration
/// checkpoint and its LoRA chain, while isolating the temporary Master library
/// from the family's real one.
Map<String, Object?> rewriteLikenessCheckConfig(
  Map<String, Object?> source, {
  required String libraryPath,
  required int port,
}) {
  BridgeConfig.fromJson(source);
  final Map<String, Object?> copied =
      jsonDecode(jsonEncode(source)) as Map<String, Object?>;
  copied['bindAddress'] = '127.0.0.1';
  copied['port'] = port;
  copied['libraryPath'] = libraryPath;
  copied['allowedWebOrigins'] = <Object?>[];
  return copied;
}

/// Starts the likeness comparison when invoked from `bridge/`.
Future<void> main(List<String> arguments) async {
  final LikenessCheckArguments parsed;
  try {
    parsed = parseLikenessCheckArguments(arguments);
  } on FormatException {
    stdout.writeln(likenessCheckUsage);
    exitCode = 2;
    return;
  }
  await _LikenessCheck(parsed).run();
}

class _LikenessCheck {
  _LikenessCheck(this.arguments);

  final LikenessCheckArguments arguments;
  final HttpClient _httpClient = HttpClient();
  final Map<String, Duration> _timings = <String, Duration>{};
  Process? _bridgeProcess;
  BridgeConfig? _config;
  bool _bridgeExited = false;
  Completer<String>? _pairingCode;
  StreamSubscription<String>? _bridgeStdoutSubscription;
  StreamSubscription<String>? _bridgeStderrSubscription;

  Future<void> run() async {
    try {
      _config = await _time('prepare', _prepare);
      await _time('check port', _ensurePortIsFree);
      await _time('start Bridge', _startBridge);
      await _time('wait for Bridge health', _waitForHealth);
      final token = await _time('pair Paired device', _pair);
      await _time(
        'create Child profile',
        () => _createProfileWithThrowawayStory(token),
      );
      final contentType = await _time(
        'read reference photo',
        _photoContentType,
      );
      await _time(
        'upload reference photo',
        () => _uploadPhoto(token, contentType),
      );
      final wardrobe = await _time(
        'read Character sheet',
        () => _rederiveSheet(token),
      );
      stdout.writeln(
        'Character sheet ready; outfit: ${wardrobe.outfit}; '
        'prop: ${wardrobe.prop}',
      );

      final storyOne = await _time(
        'generate Story 1',
        () => _generateStory(token, _storyOneTheme, 'Story 1'),
      );
      final storyTwo = await _time(
        'generate Story 2',
        () => _generateStory(token, _storyTwoTheme, 'Story 2'),
      );
      await _time(
        'illustrate Story 1',
        () => _illustrateStory(token, storyOne.id, 'Story 1'),
      );
      await _time(
        'illustrate Story 2',
        () => _illustrateStory(token, storyTwo.id, 'Story 2'),
      );
      await _time(
        'download Story 1 illustrations',
        () => _downloadIllustrations(token, storyOne, 'story-1'),
      );
      await _time(
        'download Story 2 illustrations',
        () => _downloadIllustrations(token, storyTwo, 'story-2'),
      );
      await _time(
        'write comparison',
        () => _writeResults(storyOne, storyTwo, wardrobe),
      );
      stdout.writeln('Comparison written: compare.html and report.md');
    } on _LikenessCheckFailure catch (error) {
      stderr.writeln(error.message);
      exitCode = 1;
    } on FileSystemException {
      stderr.writeln('The likeness check could not read or write its files.');
      exitCode = 1;
    } on FormatException {
      stderr.writeln(
        'The Bridge configuration could not be read or validated.',
      );
      exitCode = 1;
    } catch (error) {
      stderr.writeln('The likeness check failed: ${error.runtimeType}: $error');
      exitCode = 1;
    } finally {
      await _stopBridge();
      await _unloadModels();
      _httpClient.close(force: true);
      stdout.writeln('bridge stopped, models unloaded');
    }
  }

  Future<T> _time<T>(String step, Future<T> Function() action) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      stopwatch.stop();
      _timings[step] = stopwatch.elapsed;
    }
  }

  Future<BridgeConfig> _prepare() async {
    final sourceFile = File(arguments.configFromPath);
    if (!await sourceFile.exists()) {
      throw const _LikenessCheckFailure(
        'The source Bridge configuration is missing.',
      );
    }
    final Object? decoded = jsonDecode(await sourceFile.readAsString());
    if (decoded is! Map<String, Object?>) {
      throw const _LikenessCheckFailure(
        'The source Bridge configuration is invalid.',
      );
    }
    final output = Directory(arguments.outputPath).absolute;
    await output.create(recursive: true);
    final library = Directory('${output.path}${Platform.pathSeparator}library');
    final sourceConfig = BridgeConfig.fromJson(decoded);
    if (_pathsOverlap(output.path, sourceConfig.libraryPath)) {
      throw const _LikenessCheckFailure(
        'The comparison output would overlap the family Master library.',
      );
    }
    if (await library.exists()) {
      await library.delete(recursive: true);
    }
    await library.create(recursive: true);
    final rewritten = rewriteLikenessCheckConfig(
      decoded,
      libraryPath: library.path,
      port: arguments.port,
    );
    final configFile = File(
      '${output.path}${Platform.pathSeparator}bridge-config.json',
    );
    await configFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(rewritten),
    );
    final config = BridgeConfig.fromJson(rewritten);
    stdout.writeln('Bridge configuration written.');
    return config;
  }

  bool _pathsOverlap(String first, String second) {
    final firstPath = Directory(first).absolute.path.toLowerCase();
    final secondPath = Directory(second).absolute.path.toLowerCase();
    final separator = Platform.pathSeparator;
    return firstPath == secondPath ||
        firstPath.startsWith('$secondPath$separator') ||
        secondPath.startsWith('$firstPath$separator');
  }

  Future<void> _ensurePortIsFree() async {
    ServerSocket? socket;
    try {
      socket = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        arguments.port,
      );
    } on SocketException {
      throw _LikenessCheckFailure(
        'Port ${arguments.port} is already in use; refusing to stop it.',
      );
    } finally {
      await socket?.close();
    }
  }

  Future<void> _startBridge() async {
    final config = _config!;
    _bridgeProcess = await Process.start('dart', <String>[
      'run',
      'bin/iam_hero_bridge.dart',
      '--config',
      _configFile.path,
    ], workingDirectory: Directory.current.path);
    _pairingCode = Completer<String>();
    _bridgeStdoutSubscription = _bridgeProcess!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_readBridgeStdout);
    _bridgeStderrSubscription = _bridgeProcess!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((_) {});
    _bridgeProcess!.exitCode.then((_) {
      _bridgeExited = true;
    });
    stdout.writeln('Bridge started on port ${config.port}.');
  }

  late final File _configFile = File(
    '${Directory(arguments.outputPath).absolute.path}${Platform.pathSeparator}'
    'bridge-config.json',
  );
  void _readBridgeStdout(String line) {
    final match = RegExp(r'Pairing code: (\d{6})').firstMatch(line);
    final pairingCode = _pairingCode;
    if (match != null && pairingCode != null && !pairingCode.isCompleted) {
      pairingCode.complete(match.group(1)!);
    }
  }

  Future<void> _waitForHealth() async {
    final deadline = DateTime.now().add(const Duration(minutes: 3));
    while (DateTime.now().isBefore(deadline)) {
      try {
        final result = await _request('GET', '/health');
        if (result.statusCode == 200) {
          stdout.writeln('Bridge health ready.');
          return;
        }
      } catch (_) {
        // The child Bridge is still starting, or has not bound its socket yet.
      }
      if (_bridgeExited) {
        throw const _LikenessCheckFailure(
          'The Bridge stopped before health was ready.',
        );
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    throw const _LikenessCheckFailure(
      'The Bridge did not answer health within three minutes.',
    );
  }

  Future<String> _pair() async {
    final request = await _request('POST', '/pair/request');
    final body = _jsonBody(request);
    if (request.statusCode != 201) {
      throw _httpFailure('Pairing request', request, body);
    }
    final pairingId = _requiredString(body, 'pairingId');
    final code =
        await Future.any(<Future<String>>[
          _pairingCode!.future,
          _bridgeProcess!.exitCode.then<String>((_) {
            throw const _LikenessCheckFailure(
              'The Bridge stopped before it printed a pairing code.',
            );
          }),
        ]).timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw const _LikenessCheckFailure(
            'No pairing code appeared from the Bridge.',
          ),
        );
    final confirmed = await _request(
      'POST',
      '/pair/confirm',
      jsonBody: <String, Object?>{
        'pairingId': pairingId,
        'code': code,
        'deviceName': 'likeness-check',
      },
    );
    final confirmedBody = _jsonBody(confirmed);
    if (confirmed.statusCode != 200) {
      throw _httpFailure('Pairing confirmation', confirmed, confirmedBody);
    }
    stdout.writeln('Paired device ready.');
    return _requiredString(confirmedBody, 'deviceToken');
  }

  Future<void> _createProfileWithThrowawayStory(String token) async {
    await _generateStory(token, 'A short walk to the park', 'profile setup');
  }

  Future<String> _photoContentType() async {
    final bytes = await File(arguments.photoPath).readAsBytes();
    if (_isPng(bytes)) return 'image/png';
    if (_isJpeg(bytes)) return 'image/jpeg';
    throw const _LikenessCheckFailure(
      'The reference photo is not a JPEG or PNG.',
    );
  }

  bool _isPng(List<int> bytes) {
    const magic = <int>[137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length < magic.length) return false;
    for (var index = 0; index < magic.length; index++) {
      if (bytes[index] != magic[index]) return false;
    }
    return true;
  }

  bool _isJpeg(List<int> bytes) {
    return bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
  }

  Future<void> _uploadPhoto(String token, String contentType) async {
    final bytes = await File(arguments.photoPath).readAsBytes();
    final result = await _request(
      'PUT',
      '/profiles/$_profileId/photo',
      token: token,
      contentType: contentType,
      bytes: bytes,
    );
    final body = _jsonBody(result);
    if (result.statusCode != 200) {
      throw _httpFailure('Reference photo upload', result, body);
    }
    stdout.writeln('Reference photo stored in the temporary Master library.');
  }

  Future<_Wardrobe> _rederiveSheet(String token) async {
    final result = await _request(
      'POST',
      '/profiles/$_profileId/hero-sheet/rederive',
      token: token,
    );
    final body = _jsonBody(result);
    if (result.statusCode != 202) {
      throw _httpFailure('Character sheet re-read', result, body);
    }
    final sheet = body['sheet'];
    if (sheet is! Map<String, Object?> ||
        sheet['photoHash'] is! String ||
        (sheet['photoHash'] as String).isEmpty) {
      throw const _LikenessCheckFailure(
        'The Character sheet was not derived from the photo.',
      );
    }
    return _Wardrobe(
      outfit: _requiredString(sheet, 'outfit'),
      prop: _requiredString(sheet, 'prop'),
    );
  }

  Future<_Story> _generateStory(
    String token,
    String theme,
    String label,
  ) async {
    final created = await _request(
      'POST',
      '/stories/generate',
      token: token,
      jsonBody: <String, Object?>{
        'profileId': _profileId,
        'heroName': arguments.heroName,
        'ageYears': _heroAgeYears,
        'genderContext': arguments.gender,
        'languageCode': arguments.language,
        'theme': theme,
        'moral': _moral,
        'pageCount': arguments.pageCount,
        'illustrationStyle': 'pictureBook',
      },
    );
    final body = _jsonBody(created);
    if (created.statusCode != 202) {
      throw _httpFailure('$label generation', created, body);
    }
    final jobId = _requiredString(body, 'jobId');
    stdout.writeln('$label generation job $jobId queued.');
    final completed = await _pollJob(
      token,
      '/stories/jobs/$jobId',
      '$label generation',
    );
    final story = completed['story'];
    if (story is! Map<String, Object?>) {
      throw const _LikenessCheckFailure(
        'A completed Story generation returned no Story.',
      );
    }
    return await _readStory(token, _requiredString(story, 'id'), theme);
  }

  Future<_Story> _readStory(String token, String storyId, String theme) async {
    final result = await _request('GET', '/stories/$storyId', token: token);
    final body = _jsonBody(result);
    if (result.statusCode != 200) {
      throw _httpFailure('Story read', result, body);
    }
    final story = body['story'];
    if (story is! Map<String, Object?> || story['pages'] is! List<Object?>) {
      throw const _LikenessCheckFailure(
        'The Bridge returned an incomplete Story.',
      );
    }
    final pages = <_StoryPage>[];
    for (final page in story['pages'] as List<Object?>) {
      if (page is! Map<String, Object?>) {
        throw const _LikenessCheckFailure(
          'The Bridge returned an incomplete Story.',
        );
      }
      final pageNumber = page['pageNumber'];
      if (pageNumber is! int) {
        throw const _LikenessCheckFailure(
          'The Bridge returned an incomplete Story.',
        );
      }
      pages.add(
        _StoryPage(
          number: pageNumber,
          illustrationId: _requiredString(page, 'illustrationId'),
        ),
      );
    }
    return _Story(
      id: storyId,
      title: _requiredString(story, 'title'),
      theme: theme,
      pages: pages,
    );
  }

  Future<void> _illustrateStory(
    String token,
    String storyId,
    String label,
  ) async {
    final created = await _request(
      'POST',
      '/stories/$storyId/illustrate',
      token: token,
      jsonBody: <String, Object?>{
        'illustrationStyle': 'pictureBook',
        'genderContext': arguments.gender,
      },
    );
    final body = _jsonBody(created);
    if (created.statusCode != 202) {
      throw _httpFailure('$label illustration', created, body);
    }
    final jobId = _requiredString(body, 'jobId');
    stdout.writeln('$label illustration job $jobId queued.');
    await _pollJob(token, '/illustrations/jobs/$jobId', '$label illustration');
  }

  Future<Map<String, Object?>> _pollJob(
    String token,
    String path,
    String label,
  ) async {
    String? previousStatus;
    while (true) {
      final result = await _request('GET', path, token: token);
      final body = _jsonBody(result);
      if (result.statusCode != 200) {
        throw _httpFailure('$label job', result, body);
      }
      final status = _requiredString(body, 'status');
      final jobId = _requiredString(body, 'jobId');
      if (status != previousStatus) {
        stdout.writeln('$label job $jobId: $status.');
        previousStatus = status;
      }
      if (status == 'completed') return body;
      if (status == 'failed' || status == 'cancelled') {
        final error = body['error'];
        final errorCode =
            error is Map<String, Object?> && error['code'] is String
            ? error['code'] as String
            : status;
        throw _LikenessCheckFailure('$label job $jobId $status: $errorCode.');
      }
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }

  Future<void> _downloadIllustrations(
    String token,
    _Story story,
    String directoryName,
  ) async {
    final directory = Directory(
      '${Directory(arguments.outputPath).absolute.path}${Platform.pathSeparator}'
      '$directoryName',
    );
    await directory.create(recursive: true);
    for (final page in story.pages) {
      final result = await _request(
        'GET',
        '/sync/illustrations/${page.illustrationId}',
        token: token,
      );
      if (result.statusCode == 409) {
        throw const _LikenessCheckFailure(
          'An Illustration was not ready after its job completed.',
        );
      }
      if (result.statusCode != 200 ||
          result.headers.contentType?.mimeType != 'image/png') {
        throw _httpFailure('Illustration download', result, null);
      }
      final file = File(
        '${directory.path}${Platform.pathSeparator}page-${page.number}.png',
      );
      await file.writeAsBytes(result.bytes);
      stdout.writeln('Saved $directoryName/page-${page.number}.png.');
    }
  }

  Future<void> _writeResults(
    _Story first,
    _Story second,
    _Wardrobe wardrobe,
  ) async {
    final output = Directory(arguments.outputPath).absolute;
    final facts = _configFacts(wardrobe);
    await File(
      '${output.path}${Platform.pathSeparator}compare.html',
    ).writeAsString(_compareHtml(first, second, facts));
    await File(
      '${output.path}${Platform.pathSeparator}report.md',
    ).writeAsString(_report(first, second, facts));
  }

  _ConfigFacts _configFacts(_Wardrobe wardrobe) {
    final illustration = _config!.illustration;
    return _ConfigFacts(
      checkpoint: illustration.checkpoint,
      loras: illustration.loras
          .map((lora) => '${lora.name} (${lora.strength})')
          .toList(growable: false),
      ipAdapterWeight: illustration.ipAdapterWeight,
      referenceDenoise: illustration.referenceDenoise,
      outfit: wardrobe.outfit,
      prop: wardrobe.prop,
    );
  }

  String _compareHtml(_Story first, _Story second, _ConfigFacts facts) {
    final rows = <String>[];
    final pageCount = first.pages.length > second.pages.length
        ? first.pages.length
        : second.pages.length;
    for (var index = 0; index < pageCount; index++) {
      final pageNumber = index + 1;
      rows.add(
        '''<section class="pair"><h2>Page $pageNumber</h2><div class="grid">
<figure><img src="story-1/page-$pageNumber.png" alt="Story 1 page $pageNumber"></figure>
<figure><img src="story-2/page-$pageNumber.png" alt="Story 2 page $pageNumber"></figure>
</div></section>''',
      );
    }
    return '''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>Hero likeness check</title>
<style>body{font-family:system-ui,sans-serif;margin:2rem;color:#222}.facts{background:#f5f5f5;padding:1rem}.heads,.grid{display:grid;grid-template-columns:1fr 1fr;gap:1rem}.pair{margin-top:2rem}.pair h2{grid-column:1/-1}.pair figure{margin:0}img{max-width:100%;height:auto;display:block}</style></head>
<body><h1>Hero likeness check</h1><div class="facts"><p>Checkpoint: ${_html(facts.checkpoint)}</p><p>LoRAs: ${_html(facts.loraText)}</p><p>ipAdapterWeight: ${facts.ipAdapterWeight}; referenceDenoise: ${facts.referenceDenoise}</p><p>Wardrobe: outfit ${_html(facts.outfit)}; prop ${_html(facts.prop)}</p></div>
<div class="heads"><section><h2>${_html(first.title)}</h2><p>${_html(first.theme)}</p></section><section><h2>${_html(second.title)}</h2><p>${_html(second.theme)}</p></section></div>${rows.join()} </body></html>''';
  }

  String _report(_Story first, _Story second, _ConfigFacts facts) {
    final timings = _timings.entries
        .map((entry) => '- ${entry.key}: ${_duration(entry.value)}')
        .join('\n');
    return '''# Hero likeness check report

- Checkpoint: `${facts.checkpoint}`
- LoRAs: ${facts.loraText}
- ipAdapterWeight: ${facts.ipAdapterWeight}
- referenceDenoise: ${facts.referenceDenoise}
- Outfit: ${facts.outfit}
- Prop: ${facts.prop}
- Story 1 id: `${first.id}`
- Story 2 id: `${second.id}`

## Timings

$timings
''';
  }

  String _duration(Duration duration) {
    return '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  String _html(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  Future<_HttpResult> _request(
    String method,
    String path, {
    String? token,
    Map<String, Object?>? jsonBody,
    List<int>? bytes,
    String? contentType,
  }) async {
    final request = await _httpClient.openUrl(
      method,
      Uri.parse('http://127.0.0.1:${arguments.port}$path'),
    );
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    if (jsonBody != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(jsonBody));
    } else if (bytes != null) {
      request.headers.contentType = ContentType.parse(contentType!);
      request.add(bytes);
    }
    final response = await request.close().timeout(const Duration(seconds: 30));
    final responseBytes = await response.fold<List<int>>(<int>[], (all, chunk) {
      all.addAll(chunk);
      return all;
    });
    return _HttpResult(
      statusCode: response.statusCode,
      headers: response.headers,
      bytes: responseBytes,
    );
  }

  Map<String, Object?> _jsonBody(_HttpResult result) {
    try {
      final Object? decoded = jsonDecode(utf8.decode(result.bytes));
      if (decoded is Map<String, Object?>) return decoded;
    } on FormatException {
      // A non-JSON error is not a Bridge response this tool can safely report.
    }
    throw const _LikenessCheckFailure(
      'The Bridge returned an invalid response.',
    );
  }

  String _requiredString(Map<String, Object?> object, String key) {
    final value = object[key];
    if (value is String && value.isNotEmpty) return value;
    throw const _LikenessCheckFailure(
      'The Bridge returned an incomplete response.',
    );
  }

  _LikenessCheckFailure _httpFailure(
    String action,
    _HttpResult result,
    Map<String, Object?>? body,
  ) {
    final error = body?['error'];
    final code = error is Map<String, Object?> && error['code'] is String
        ? error['code'] as String
        : 'unexpected_response';
    return _LikenessCheckFailure(
      '$action failed: HTTP ${result.statusCode} $code.',
    );
  }

  Future<void> _stopBridge() async {
    final process = _bridgeProcess;
    if (process != null) {
      try {
        if (Platform.isWindows) {
          await Process.run('taskkill', <String>[
            '/PID',
            '${process.pid}',
            '/T',
            '/F',
          ]);
        } else {
          process.kill(ProcessSignal.sigterm);
          await process.exitCode.timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              process.kill(ProcessSignal.sigkill);
              return -1;
            },
          );
        }
      } catch (_) {
        // Cleanup continues to model unloading even when the child already died.
      }
    }
    await _bridgeStdoutSubscription?.cancel();
    await _bridgeStderrSubscription?.cancel();
  }

  Future<void> _unloadModels() async {
    final config = _config;
    if (config == null) return;
    final tags = <String>{config.ollamaModel, config.visionModel};
    for (final tag in tags) {
      try {
        await Process.run('ollama', <String>['stop', tag]);
      } catch (_) {
        // The cleanup promise is best effort when Ollama is unavailable.
      }
    }
  }
}

const String _profileId = 'likeness-check';
const int _heroAgeYears = 6;
const String _moral = 'sharing what you have';
const String _storyOneTheme = 'A rainy afternoon at home';
const String _storyTwoTheme = 'A morning at the market';

class _Wardrobe {
  const _Wardrobe({required this.outfit, required this.prop});

  final String outfit;
  final String prop;
}

class _Story {
  const _Story({
    required this.id,
    required this.title,
    required this.theme,
    required this.pages,
  });

  final String id;
  final String title;
  final String theme;
  final List<_StoryPage> pages;
}

class _StoryPage {
  const _StoryPage({required this.number, required this.illustrationId});

  final int number;
  final String illustrationId;
}

class _ConfigFacts {
  const _ConfigFacts({
    required this.checkpoint,
    required this.loras,
    required this.ipAdapterWeight,
    required this.referenceDenoise,
    required this.outfit,
    required this.prop,
  });

  final String checkpoint;
  final List<String> loras;
  final double ipAdapterWeight;
  final double referenceDenoise;
  final String outfit;
  final String prop;

  String get loraText => loras.isEmpty ? 'none' : loras.join(', ');
}

class _HttpResult {
  const _HttpResult({
    required this.statusCode,
    required this.headers,
    required this.bytes,
  });

  final int statusCode;
  final HttpHeaders headers;
  final List<int> bytes;
}

class _LikenessCheckFailure implements Exception {
  const _LikenessCheckFailure(this.message);

  final String message;
}
