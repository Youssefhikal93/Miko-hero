import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:iam_hero_bridge/src/common/atomic_files.dart';
import 'package:iam_hero_bridge/src/common/paths.dart';
import 'package:iam_hero_bridge/src/config/bridge_config.dart';
import 'package:iam_hero_bridge/src/config/illustration_settings.dart';
import 'package:iam_hero_bridge/src/generation/cancellation.dart';
import 'package:iam_hero_bridge/src/generation/generated_story.dart';
import 'package:iam_hero_bridge/src/generation/ollama_client.dart';
import 'package:iam_hero_bridge/src/generation/story_draft.dart';
import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';
import 'package:iam_hero_bridge/src/generation/story_library_writer.dart';
import 'package:iam_hero_bridge/src/illustration/comfyui_client.dart';
import 'package:iam_hero_bridge/src/library/character_sheet_store.dart';
import 'package:iam_hero_bridge/src/library/master_library.dart';
import 'package:iam_hero_bridge/src/probes/probe_client.dart';
import 'package:iam_hero_bridge/src/server/app_server.dart';
import 'package:shelf/shelf.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// A fake [ProbeHttpClient] whose behavior is fully scripted per test.
///
/// This is the injection seam required by the brief: Ollama and ComfyUI are
/// mocked at this boundary, so no real services are ever contacted.
class FakeProbeHttpClient implements ProbeHttpClient {
  /// Creates a client. When [failAll] is set every request throws, which
  /// simulates both local services being down. Otherwise canned "available"
  /// answers are returned.
  FakeProbeHttpClient({this.failAll = false});

  /// Whether every probe request should fail.
  final bool failAll;

  /// URLs seen by this client, in request order (for assertions).
  final List<Uri> requestedUrls = <Uri>[];

  @override
  Future<ProbeHttpResponse> get(Uri url, {required Duration timeout}) async {
    requestedUrls.add(url);
    if (failAll) {
      throw const SocketException('Fake probe failure.');
    }
    final path = url.path;
    if (path.endsWith('/api/version')) {
      return _json(200, <String, Object?>{'version': '0.1.17'});
    }
    if (path.endsWith('/api/tags')) {
      return _json(200, <String, Object?>{
        'models': <Object?>[
          <String, Object?>{'name': 'gemma3:4b'},
        ],
      });
    }
    if (path.endsWith('/system_stats')) {
      return _json(200, <String, Object?>{
        'system': <String, Object?>{'os': 'fake'},
      });
    }
    return _json(404, <String, Object?>{'error': 'not found'});
  }

  ProbeHttpResponse _json(int status, Map<String, Object?> body) {
    return ProbeHttpResponse(
      statusCode: status,
      bodyBytes: Uint8List.fromList(utf8.encode(jsonEncode(body))),
    );
  }
}

/// Scripted behaviour of one fake Ollama call.
typedef FakeOllamaResponder =
    Future<OllamaGenerateResponse> Function(
      OllamaGenerateRequest request,
      CancellationToken cancellation,
    );

/// Scripted behaviour of one fake Ollama unload call.
typedef FakeOllamaUnloadResponder =
    Future<void> Function(OllamaUnloadRequest request);

/// A fake [OllamaStoryClient] scripted per test.
///
/// This is the only mocked boundary in the generation tests: everything
/// between the HTTP endpoint and this client is the real implementation.
class FakeOllamaStoryClient implements OllamaStoryClient {
  /// Creates a client driven by [responder].
  FakeOllamaStoryClient(this.responder, {this.unloadResponder});

  /// Answers every call with [payload] inside an Ollama envelope.
  factory FakeOllamaStoryClient.answering(String payload) {
    return FakeOllamaStoryClient(
      (OllamaGenerateRequest request, CancellationToken cancellation) async =>
          ollamaEnvelope(payload),
    );
  }

  /// Answers the outline pass with [outline] and the page pass with [story].
  ///
  /// Generation is two calls now, so a fake that answers both with the same
  /// payload would only ever exercise the first one. The pass is recognized by
  /// the schema the bridge asked for, exactly as a real model would see it.
  factory FakeOllamaStoryClient.writing({
    required String story,
    String? outline,
    String? heroSheet,
    int pageCount = 6,
    FakeOllamaUnloadResponder? unloadResponder,
  }) {
    final plan = outline ?? outlinePayload(pageCount: pageCount);
    final sheet = heroSheet ?? heroSheetPayload();
    return FakeOllamaStoryClient((
      OllamaGenerateRequest request,
      CancellationToken cancellation,
    ) async {
      if (isVisionRequest(request)) {
        return ollamaEnvelope(sheet);
      }
      return ollamaEnvelope(isOutlineRequest(request) ? plan : story);
    }, unloadResponder: unloadResponder);
  }

  /// Fails every call by throwing [error], like a broken transport.
  factory FakeOllamaStoryClient.failing(Object error) {
    return FakeOllamaStoryClient(
      (OllamaGenerateRequest request, CancellationToken cancellation) async =>
          throw error,
    );
  }

  /// Requests whose schema asked for page beats — the outline pass.
  List<OllamaGenerateRequest> get outlineRequests => requests
      .where(
        (request) => !isVisionRequest(request) && isOutlineRequest(request),
      )
      .toList(growable: false);

  /// Requests whose schema asked for finished pages — the page pass.
  List<OllamaGenerateRequest> get pageRequests => requests
      .where(
        (request) => !isVisionRequest(request) && !isOutlineRequest(request),
      )
      .toList(growable: false);

  /// Requests that carried a picture — the character-sheet pass.
  List<OllamaGenerateRequest> get visionRequests =>
      requests.where(isVisionRequest).toList(growable: false);

  /// Behaviour invoked for every call.
  final FakeOllamaResponder responder;

  /// Optional behaviour invoked for every unload call.
  final FakeOllamaUnloadResponder? unloadResponder;

  /// Requests seen by this client, in call order (for assertions).
  final List<OllamaGenerateRequest> requests = <OllamaGenerateRequest>[];

  /// Unload requests seen by this client, in call order (for assertions).
  final List<OllamaUnloadRequest> unloadRequests = <OllamaUnloadRequest>[];

  /// Generation and unload requests in their original call order.
  final List<Object> allRequests = <Object>[];

  @override
  Future<OllamaGenerateResponse> generate(
    OllamaGenerateRequest request, {
    required CancellationToken cancellation,
  }) {
    requests.add(request);
    allRequests.add(request);
    return responder(request, cancellation);
  }

  @override
  Future<void> unload(OllamaUnloadRequest request) {
    unloadRequests.add(request);
    allRequests.add(request);
    return unloadResponder?.call(request) ?? Future<void>.value();
  }
}

/// A fake [ComfyUiClient] scripted per test.
///
/// This is the only mocked boundary in the illustration tests: the queue, the
/// workflow builder, the file writes and the database updates are all the
/// real implementations. No ComfyUI process is ever started.
class FakeComfyUiClient implements ComfyUiClient {
  /// Creates a client.
  ///
  /// [reachable] decides what the health check answers. Submissions are
  /// numbered from zero in call order; any number in [failingSubmissions]
  /// comes back from history as a ComfyUI-side error, and [onSubmit] is
  /// awaited inside `submitWorkflow` so a test can hold a render open.
  FakeComfyUiClient({
    this.reachable = true,
    Uint8List? imageBytes,
    this.failingSubmissions = const <int>{},
    this.uploadFailure,
    this.onSubmit,
    this.missingNodeTypes = const <String>{},
  }) : imageBytes = imageBytes ?? onePixelPngBytes();

  /// What [isReachable] answers.
  final bool reachable;

  /// Node class types this fake ComfyUI does not know, which is how a test
  /// stands in for an install without the Impact Pack.
  final Set<String> missingNodeTypes;

  /// Bytes every [fetchImage] call returns.
  final Uint8List imageBytes;

  /// Zero-based submission numbers whose render reports an error.
  final Set<int> failingSubmissions;

  /// Thrown by [uploadReferenceImage] when set.
  final Object? uploadFailure;

  /// Awaited inside [submitWorkflow], before the prompt id is returned.
  final Future<void> Function(int submissionIndex)? onSubmit;

  /// Every workflow submitted, in call order.
  final List<Map<String, Object?>> workflows = <Map<String, Object?>>[];

  /// File names of every uploaded reference image, in call order.
  final List<String> uploadedFileNames = <String>[];

  /// How many times [interrupt] was called.
  int interruptCount = 0;

  /// Class types this fake was asked about, in call order.
  final List<String> probedNodeTypes = <String>[];

  @override
  Future<bool> isReachable(ComfyUiEndpoint endpoint) async => reachable;

  @override
  Future<bool> supportsNodeType(
    ComfyUiEndpoint endpoint,
    String classType,
  ) async {
    probedNodeTypes.add(classType);
    return !missingNodeTypes.contains(classType);
  }

  @override
  Future<String> uploadReferenceImage(
    ComfyUiEndpoint endpoint, {
    required String fileName,
    required String contentType,
    required Uint8List bytes,
  }) async {
    final Object? failure = uploadFailure;
    if (failure != null) {
      throw failure;
    }
    uploadedFileNames.add(fileName);
    return fileName;
  }

  @override
  Future<String> submitWorkflow(
    ComfyUiEndpoint endpoint, {
    required Map<String, Object?> workflow,
    required String clientId,
  }) async {
    final index = workflows.length;
    workflows.add(workflow);
    await onSubmit?.call(index);
    return 'prompt-$index';
  }

  @override
  Future<ComfyUiHistoryEntry> readHistory(
    ComfyUiEndpoint endpoint, {
    required String promptId,
  }) async {
    final index = int.parse(promptId.split('-').last);
    if (failingSubmissions.contains(index)) {
      return const ComfyUiHistoryEntry(
        known: true,
        completed: false,
        failed: true,
        images: <ComfyUiImageReference>[],
      );
    }
    return ComfyUiHistoryEntry(
      known: true,
      completed: true,
      failed: false,
      images: <ComfyUiImageReference>[
        ComfyUiImageReference(
          fileName: '$promptId.png',
          subfolder: '',
          type: 'output',
        ),
      ],
    );
  }

  @override
  Future<Uint8List> fetchImage(
    ComfyUiEndpoint endpoint, {
    required ComfyUiImageReference image,
  }) async => imageBytes;

  @override
  Future<void> interrupt(ComfyUiEndpoint endpoint) async => interruptCount++;
}

/// A real, minimal 1x1 PNG.
///
/// The bridge checks PNG magic bytes on everything it stores, so the fake
/// renderer has to hand back something that genuinely is a PNG.
Uint8List onePixelPngBytes() {
  return base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAC'
    'hwGA60e6kgAAAABJRU5ErkJggg==',
  );
}

/// A minimal JFIF-headed JPEG: start-of-image, APP0 segment, end-of-image.
Uint8List minimalJpegBytes() {
  return Uint8List.fromList(<int>[
    0xFF, 0xD8, // SOI
    0xFF, 0xE0, 0x00, 0x10, // APP0, length 16
    0x4A, 0x46, 0x49, 0x46, 0x00, // "JFIF\0"
    0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
    0xFF, 0xD9, // EOI
  ]);
}

/// Whether [request] is the outline pass rather than the page pass.
///
/// Read off the requested JSON schema, which is the only difference a model
/// would see between the two calls.
bool isOutlineRequest(OllamaGenerateRequest request) {
  final properties = request.format['properties'];
  return properties is Map<String, Object?> && properties.containsKey('beats');
}

/// Whether [request] is the character-sheet pass.
///
/// Recognized by the picture it carries, which is what makes it a vision call
/// in the first place — a real model tells the passes apart the same way.
bool isVisionRequest(OllamaGenerateRequest request) =>
    request.images.isNotEmpty;

/// A schema-valid character-sheet answer.
///
/// Three colours and nothing else, exactly as the prompt demands; the outfit
/// and the prop never come from the model.
String heroSheetPayload({
  String hair = 'short curly black hair',
  String skinTone = 'warm brown',
  String eyeColor = 'dark brown',
}) {
  return jsonEncode(<String, Object?>{
    'hair': hair,
    'skinTone': skinTone,
    'eyeColor': eyeColor,
  });
}

/// A schema-valid outline answer with [pageCount] beats.
///
/// [includeHeroAppearance] can be turned off to reproduce a model that plans
/// the pages but forgets what the hero looks like, and
/// [includeLessonMoment] to reproduce one that plans an adventure with no
/// place in it for the parent's lesson.
///
/// [turnPage] defaults to the middle of the book, which is the only range the
/// parser accepts.
String outlinePayload({
  required int pageCount,
  String title = 'Nour and the Sea Lanterns',
  String heroAppearance =
      'short curly black hair, mustard-yellow raincoat, red boots, '
      'carries a small brass lantern',
  String lessonMoment =
      'Nour is asked to share her one lit lantern with a smaller child '
      'who has none.',
  int? turnPage,
  String Function(int pageNumber)? summary,
  bool includeHeroAppearance = true,
  bool includeLessonMoment = true,
}) {
  return jsonEncode(<String, Object?>{
    'title': title,
    if (includeHeroAppearance) 'heroAppearance': heroAppearance,
    if (includeLessonMoment) 'lessonMoment': lessonMoment,
    'turnPage': turnPage ?? pageCount ~/ 2,
    'beats': List<Object?>.generate(
      pageCount,
      (index) => <String, Object?>{
        'pageNumber': index + 1,
        'summary':
            summary?.call(index + 1) ??
            'Beat ${index + 1}: Nour moves one step closer to the lanterns.',
      },
    ),
  });
}

/// Wraps a model answer in the non-streaming `/api/generate` envelope.
OllamaGenerateResponse ollamaEnvelope(String payload, {int statusCode = 200}) {
  return OllamaGenerateResponse(
    statusCode: statusCode,
    bodyBytes: Uint8List.fromList(
      utf8.encode(
        jsonEncode(<String, Object?>{
          'model': 'gemma3:4b',
          'response': payload,
          'done': true,
        }),
      ),
    ),
  );
}

/// One test server plus everything needed to drive it without sockets.
class TestServer {
  /// Creates a server over an initialized library rooted inside [root].
  TestServer({required this.root, required this.library, required this.server})
    : handler = server.buildHandler();

  /// Temporary directory backing the master library; deleted on cleanup.
  final Directory root;

  /// Initialized master library under [root].
  final MasterLibrary library;

  /// The wired application server.
  final AppServer server;

  /// Request pipeline; invoke directly with shelf [Request]s.
  final Handler handler;

  /// Stops any unfinished generation or illustration job and closes the
  /// database.
  ///
  /// Waits for the character-sheet work a photo upload deliberately leaves
  /// running behind its response first, so nothing is still touching the
  /// library when the temporary folder is deleted.
  Future<void> close() async {
    await server.awaitHeroSheetWork();
    await server.close();
  }

  /// Waits for every background character-sheet refresh to finish.
  ///
  /// A photo upload answers before its sheet is derived, on purpose. A test
  /// that wants to assert on the sheet says so here.
  Future<void> settleHeroSheets() => server.awaitHeroSheetWork();

  /// The stored character sheet of [profileId], or `null` when none exists.
  HeroCharacterSheet? heroSheet(String profileId) =>
      server.heroSheet(profileId);

  /// Number of rows currently stored in [table].
  int countRows(String table) {
    final rows = library.database.select(
      'SELECT COUNT(*) AS total FROM $table',
    );
    return rows.first['total']! as int;
  }

  /// Asserts that no story, page, illustration or profile was written.
  void expectEmptyLibrary() {
    for (final table in <String>[
      'profiles',
      'stories',
      'story_pages',
      'illustrations',
    ]) {
      expect(countRows(table), 0, reason: '$table must stay empty');
    }
  }
}

/// Builds a default configuration whose library lives inside [directory].
///
/// [illustration] lets a test render through a configured pipeline — LoRAs,
/// upscaling, face detailing — without writing a configuration file.
BridgeConfig testConfig(
  Directory directory, {
  IllustrationSettings illustration = IllustrationSettings.defaults,
}) {
  return BridgeConfig.defaults(
    workingDirectory: directory.path,
    illustration: illustration,
  );
}

/// Creates a fresh temp directory that is removed when the test ends.
Future<Directory> createTempRoot() async {
  final directory = await Directory.systemTemp.createTemp(
    'iam_hero_bridge_test',
  );
  addTearDown(() {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });
  return directory;
}

/// Creates a [TestServer] over a fresh temp library and registers cleanup.
Future<TestServer> createTestServer({
  ProbeHttpClient? probeHttpClient,
  OllamaStoryClient? ollamaClient,
  ComfyUiClient? comfyUiClient,
  DateTime Function()? clock,
  void Function(String message)? notifyCode,
  void Function(String message)? logEvent,
  IllustrationSettings illustration = IllustrationSettings.defaults,
}) async {
  final root = await createTempRoot();
  final library = MasterLibrary(
    rootPath: '${root.path}${Platform.pathSeparator}library',
  );
  await library.initialize();
  addTearDown(library.close);
  final server = AppServer(
    config: testConfig(root, illustration: illustration),
    library: library,
    probeHttpClient: probeHttpClient ?? FakeProbeHttpClient(),
    ollamaClient:
        ollamaClient ??
        FakeOllamaStoryClient.failing(
          const SocketException('No Ollama in this test.'),
        ),
    comfyUiClient: comfyUiClient ?? FakeComfyUiClient(reachable: false),
    clock: clock,
    notifyCode: notifyCode,
    logEvent: logEvent,
    // Nothing in the suite waits on a real render, so the poll loop must
    // never cost a test a wall-clock second.
    illustrationPollInterval: const Duration(milliseconds: 1),
  );
  return TestServer(root: root, library: library, server: server);
}

/// Sends [method] [path] through [handler] and returns status + JSON body.
Future<(int, Map<String, Object?>)> callJson(
  Handler handler,
  String method,
  String path, {
  Map<String, String>? headers,
  Object? body,
}) async {
  final request = Request(
    method,
    Uri.parse('http://bridge.test$path'),
    headers: headers,
    body: body,
  );
  final response = await handler(request);
  final raw = await response.readAsString();
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    fail('Expected a JSON response but got: $raw');
  }
  if (decoded is! Map<String, Object?>) {
    fail('Expected a JSON object response but got: $raw');
  }
  return (response.statusCode, decoded);
}

/// Sends [method] [path] through [handler] and returns the raw response.
///
/// Used where the answer is not JSON — the illustration download — and where
/// the request body is raw bytes, as a reference photo upload is.
Future<Response> callRaw(
  Handler handler,
  String method,
  String path, {
  Map<String, String>? headers,
  Object? body,
}) async {
  return handler(
    Request(
      method,
      Uri.parse('http://bridge.test$path'),
      headers: headers,
      body: body,
    ),
  );
}

/// Decodes a JSON object response body, failing when it is not one.
Future<Map<String, Object?>> readJsonBody(Response response) async {
  final raw = await response.readAsString();
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    fail('Expected a JSON response but got: $raw');
  }
  if (decoded is! Map<String, Object?>) {
    fail('Expected a JSON object response but got: $raw');
  }
  return decoded;
}

/// Reads the status of every illustration of [storyId], in page order.
List<String> illustrationStatuses(MasterLibrary library, String storyId) {
  final rows = library.database.select(
    'SELECT i.status AS status FROM illustrations i '
    'JOIN story_pages p ON p.id = i.story_page_id '
    'WHERE p.story_id = ? ORDER BY p.page_index ASC',
    <Object?>[storyId],
  );
  return rows.map((row) => row['status']! as String).toList(growable: false);
}

/// Reads the `updated_at_utc` of [storyId] as a UTC timestamp.
DateTime storyUpdatedAt(MasterLibrary library, String storyId) {
  final rows = library.database.select(
    'SELECT updated_at_utc FROM stories WHERE id = ?',
    <Object?>[storyId],
  );
  return DateTime.parse(rows.single['updated_at_utc']! as String).toUtc();
}

/// Extracts `error.code` from a typed error envelope, failing if absent.
String errorCode(Map<String, Object?> body) {
  final error = body['error'];
  if (error is! Map<String, Object?>) {
    fail('Expected a typed error envelope but got: $body');
  }
  return error['code'] as String;
}

/// Issues one pairing request against [server] and returns its id and the
/// code captured from the console callback.
Future<(String, String)> issuePairing(
  TestServer testServer,
  List<String> printedCodes,
) async {
  final (status, body) = await callJson(
    testServer.handler,
    'POST',
    '/pair/request',
  );
  expect(status, 201, reason: 'body was $body');
  expect(body.containsKey('code'), isFalse, reason: 'code must not leak');
  expect(printedCodes, isNotEmpty);
  final code = RegExp(
    r'^Pairing code: (\d{6}) ',
  ).firstMatch(printedCodes.last)!.group(1)!;
  return (body['pairingId'] as String, code);
}

/// Runs a full pairing ceremony and returns the device's bearer token.
Future<String> pairDevice(
  TestServer testServer,
  List<String> printedCodes, {
  String deviceName = 'Family tablet',
}) async {
  final (pairingId, code) = await issuePairing(testServer, printedCodes);
  final (status, body) = await callJson(
    testServer.handler,
    'POST',
    '/pair/confirm',
    body: jsonEncode(<String, Object?>{
      'pairingId': pairingId,
      'code': code,
      'deviceName': deviceName,
    }),
  );
  expect(status, 200, reason: 'body was $body');
  return body['deviceToken']! as String;
}

/// Authorization header carrying [token].
Map<String, String> authHeaders(String token) {
  return <String, String>{'authorization': 'Bearer $token'};
}

/// Creates and initializes a second, independent temporary library.
///
/// Used by the backup tests, which need a restore target that shares nothing
/// with the library the backup came from.
Future<MasterLibrary> createTempLibrary() async {
  final root = await createTempRoot();
  final library = MasterLibrary(
    rootPath: '${root.path}${Platform.pathSeparator}library',
  );
  await library.initialize();
  addTearDown(library.close);
  return library;
}

/// Writes one complete story straight into [library] and returns it.
///
/// Uses the production [StoryLibraryWriter], so the rows are exactly the ones
/// generation would have produced; only the model call is skipped.
GeneratedStory seedStory(
  MasterLibrary library, {
  String profileId = 'profile-1',
  String heroName = 'Nour',
  String title = 'A Lantern by the Sea',
  StoryLanguage language = StoryLanguage.english,
  int pageCount = 2,
  String prosePrefix = 'Distinctive page prose ',
  String scenePrefix = 'A harbour at dusk, page ',
  DateTime? writtenAtUtc,
}) {
  final writer = StoryLibraryWriter(library: library);
  return writer.writeStory(
    request: StoryGenerationRequest(
      profileId: profileId,
      heroName: heroName,
      ageYears: 6,
      gender: StoryGenderContext.girl,
      language: language,
      theme: 'A lantern festival by the sea',
      moral: 'Sharing a small light makes it bigger',
      pageCount: pageCount,
      illustrationStyle: StoryIllustrationStyle.pictureBook,
    ),
    draft: StoryDraft(
      title: title,
      pages: List<StoryDraftPage>.generate(
        pageCount,
        (index) => StoryDraftPage(
          pageNumber: index + 1,
          text: '$prosePrefix${index + 1}',
          illustrationScene: '$scenePrefix${index + 1}',
        ),
        growable: false,
      ),
    ),
    nowUtc: writtenAtUtc ?? DateTime.now().toUtc(),
  );
}

/// Writes [bytes] to [relativePath] inside [library] and returns the file.
Future<File> writeLibraryFile(
  MasterLibrary library,
  String relativePath,
  List<int> bytes,
) {
  return writeFileAtomic(
    joinPath(library.rootPath, toPlatformRelativePath(relativePath)),
    bytes,
  );
}

/// Reads every row of [table] from [library] as plain maps.
///
/// Sorted by encoded content so two libraries can be compared row by row
/// without depending on physical row order.
List<Map<String, Object?>> dumpTable(MasterLibrary library, String table) {
  final ResultSet rows = library.database.select('SELECT * FROM $table');
  final dumped = rows
      .map(
        (row) => <String, Object?>{
          for (final column in row.keys) column: row[column],
        },
      )
      .toList();
  dumped.sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
  return List<Map<String, Object?>>.unmodifiable(dumped);
}

/// Reads every library-relative file path under [roots], sorted.
Future<List<String>> listLibraryFiles(
  MasterLibrary library, {
  Set<String> roots = const <String>{'photos', 'illustrations'},
}) async {
  final prefix = joinPath(library.rootPath, '');
  final paths = <String>[];
  for (final root in roots) {
    final directory = Directory(joinPath(library.rootPath, root));
    if (!directory.existsSync()) {
      continue;
    }
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        paths.add(entity.path.substring(prefix.length).replaceAll(r'\', '/'));
      }
    }
  }
  paths.sort();
  return paths;
}
